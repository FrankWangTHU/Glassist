import Foundation
import Security
import Darwin

public enum WidgetStorageError: LocalizedError {
    case signing, disconnected, changedAccount, storage, keychain(OSStatus), completionLocked
    public var errorDescription: String? {
        switch self {
        case .signing: return "需要为主应用和小组件配置相同的开发签名与共享权限。"
        case .disconnected: return "请打开 Glassist 连接 Todoist。"
        case .changedAccount: return "账号已切换，请刷新小组件。"
        case .storage: return "无法读写小组件共享数据。"
        case .keychain(let code): return "无法访问共享钥匙串（\(code)），请检查签名或解锁 Mac。"
        case .completionLocked: return "这项任务的完成结果待核对，请在 Todoist 中查看。"
        }
    }
}

public enum WidgetCredential {
    public static var accessGroup: String? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "GlassistKeychainGroup") as? String,
              let prefix = group.split(separator: ".").first, prefix.count == 10,
              prefix.allSatisfy({ $0.isLetter || $0.isNumber }), !group.contains("$") else { return nil }
        return group
    }
    private static func query() throws -> [String: Any] {
        guard let group = accessGroup else { throw WidgetStorageError.signing }
        return [kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "com.frankwang.Glassist.widget",
                kSecAttrAccount as String: "todoist",
                kSecAttrAccessGroup as String: group,
                kSecUseDataProtectionKeychain as String: true]
    }
    public static func read() throws -> String {
        var q = try query(); q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        if status == errSecItemNotFound { throw WidgetStorageError.disconnected }
        guard status == errSecSuccess, let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else { throw WidgetStorageError.keychain(status) }
        return token
    }
    public static func save(_ token: String) throws {
        var q = try query()
        let data = Data(token.utf8)
        let status = SecItemUpdate(q as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            q[kSecValueData as String] = data
            q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let added = SecItemAdd(q as CFDictionary, nil)
            guard added == errSecSuccess else { throw WidgetStorageError.keychain(added) }
        } else if status != errSecSuccess { throw WidgetStorageError.keychain(status) }
    }
    public static func delete() throws {
        let status = SecItemDelete(try query() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw WidgetStorageError.keychain(status) }
    }
}

public struct WidgetSnapshot: Codable, Sendable {
    public var filter: SavedFilter
    public var groups: [TaskGroup]
    public var updated: Date
    public var timezone: String
    public var generation: UUID
    public var error: String?
    public var tasks: [TodoTask] { TaskDates.uniqueTasks(groups) }
    public init(filter: SavedFilter, groups: [TaskGroup], updated: Date, timezone: String, generation: UUID, error: String? = nil) {
        self.filter = filter; self.groups = groups; self.updated = updated; self.timezone = timezone
        self.generation = generation; self.error = error
    }
}

public struct WidgetDatabase: Codable {
    public var generation = UUID()
    public var connected = false
    public var filters: [SavedFilter] = []
    public var language = "en"
    public var timezone = TimeZone.current.identifier
    public var snapshots: [String: WidgetSnapshot] = [:]
    public var completionLocks: [String: String] = [:]
    public var retryAfter: Date?
    public init() {}
}

public struct WidgetStorage {
    private let directory: URL
    public init(directory: URL? = nil) throws {
        if let directory { self.directory = directory }
        else {
            guard WidgetCredential.accessGroup != nil,
                  let group = Bundle.main.object(forInfoDictionaryKey: "GlassistAppGroup") as? String,
                  !group.contains("$"),
                  let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
            else { throw WidgetStorageError.signing }
            self.directory = container.appendingPathComponent("Glassist", isDirectory: true)
        }
        try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
    }
    // A process-shared file lock protects account changes and completion claims. No network work under the lock.
    public func transaction<T>(_ operation: (inout WidgetDatabase) throws -> T) throws -> T {
        let fd = open(directory.appendingPathComponent("state.lock").path, O_CREAT | O_RDWR, 0o600)
        guard fd >= 0 else { throw WidgetStorageError.storage }
        defer { close(fd) }
        guard flock(fd, LOCK_EX) == 0 else { throw WidgetStorageError.storage }
        defer { flock(fd, LOCK_UN) }
        let url = directory.appendingPathComponent("state.json")
        var state: WidgetDatabase
        if FileManager.default.fileExists(atPath: url.path) { state = try JSONDecoder().decode(WidgetDatabase.self, from: Data(contentsOf: url)) }
        else { state = WidgetDatabase() }
        let result = try operation(&state)
        try JSONEncoder().encode(state).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return result
    }
    public func read() throws -> WidgetDatabase { try transaction { $0 } }
    public func save(_ snapshot: WidgetSnapshot) throws {
        try transaction { state in
            guard state.connected, state.generation == snapshot.generation else { throw WidgetStorageError.changedAccount }
            var clean = snapshot
            for index in clean.groups.indices {
                clean.groups[index].tasks.removeAll { state.completionLocks[$0.id] == "done" }
            }
            state.snapshots[snapshot.filter.id] = clean
        }
    }
    public func reserveCompletion(id: String, generation: UUID) throws -> String {
        try transaction { state in
            guard state.connected, state.generation == generation else { throw WidgetStorageError.changedAccount }
            guard state.completionLocks[id] == nil else { throw WidgetStorageError.completionLocked }
            guard let task = state.snapshots.values.filter { Date().timeIntervalSince($0.updated) < 86400 }.flatMap(\.tasks).first(where: { $0.id == id }), task.due?.isRecurring != true else {
                throw WidgetStorageError.completionLocked
            }
            let token = try WidgetCredential.read()
            state.completionLocks[id] = "pending"
            return token
        }
    }
}

public enum WidgetService {
    public static func connect(_ token: String) async throws {
        let storage = try WidgetStorage()
        let client = TodoistClient(token: token)
        let (filters, context) = try await client.savedFilters()
        // Invalidate the old account before replacing its credential. A Keychain or disk failure remains disconnected.
        try storage.transaction { $0 = WidgetDatabase() }
        try storage.transaction { state in
            try WidgetCredential.save(token)
            state.connected = true
            state.filters = filters; state.language = context.language; state.timezone = context.timeZone.identifier
        }
    }
    public static func disconnect() throws {
        let storage = try WidgetStorage()
        try storage.transaction { state in
            try WidgetCredential.delete()
            state = WidgetDatabase()
        }
    }
    public static func catalog() async throws -> [SavedFilter] {
        let storage = try WidgetStorage()
        let (state, token) = try storage.transaction { state -> (WidgetDatabase, String) in
            guard state.connected else { throw WidgetStorageError.disconnected }
            return (state, try WidgetCredential.read())
        }
        let (filters, account) = try await TodoistClient(token: token).savedFilters()
        try storage.transaction { current in
            guard current.generation == state.generation else { throw WidgetStorageError.changedAccount }
            current.filters = filters; current.language = account.language; current.timezone = account.timeZone.identifier
            let ids = Set(filters.map(\.id))
            current.snapshots = current.snapshots.filter { ids.contains($0.key) }
        }
        return filters
    }
    public static func load(filterID: String) async throws -> WidgetSnapshot {
        let storage = try WidgetStorage()
        let (state, token) = try storage.transaction { state -> (WidgetDatabase, String) in
            guard state.connected else { throw WidgetStorageError.disconnected }
            return (state, try WidgetCredential.read())
        }
        do {
            if let next = state.retryAfter, next > Date() { throw APIError.rateLimited(next.timeIntervalSinceNow) }
            let client = TodoistClient(token: token)
            let (filters, context) = try await client.savedFilters()
            guard let filter = filters.first(where: { $0.id == filterID }) else {
                // Deleted filters never fall back to another filter's contents or stale tasks.
                try storage.transaction { current in
                    guard current.generation == state.generation else { throw WidgetStorageError.changedAccount }
                    current.filters = filters; current.snapshots.removeValue(forKey: filterID)
                }
                throw APIError.invalidFilter
            }
            let groups = try await client.tasks(query: filter.query, language: context.language)
            let snapshot = WidgetSnapshot(filter: filter, groups: groups, updated: Date(), timezone: context.timeZone.identifier, generation: state.generation)
            try storage.save(snapshot)
            return try storage.read().snapshots[filterID] ?? snapshot
        } catch {
            let cached = try storage.transaction { current -> WidgetSnapshot? in
                guard current.connected, current.generation == state.generation else { throw WidgetStorageError.changedAccount }
                if case APIError.rateLimited(let seconds) = error { current.retryAfter = Date().addingTimeInterval(seconds) }
                return current.snapshots[filterID]
            }
            if var cached { cached.error = message(error); return cached }
            throw error
        }
    }
    public static func complete(id: String, generation: UUID) async throws {
        let storage = try WidgetStorage()
        let token = try storage.reserveCompletion(id: id, generation: generation)
        do {
            try await TodoistClient(token: token).closeTask(id: id)
            try storage.transaction { state in
                guard state.generation == generation else { throw WidgetStorageError.changedAccount }
                state.completionLocks[id] = "done"
                for key in Array(state.snapshots.keys) {
                    guard var snapshot = state.snapshots[key] else { continue }
                    for i in snapshot.groups.indices { snapshot.groups[i].tasks.removeAll { $0.id == id } }
                    state.snapshots[key] = snapshot
                }
            }
        } catch {
            try? storage.transaction { state in
                guard state.generation == generation else { return }
                state.completionLocks[id] = "uncertain"
                for key in Array(state.snapshots.keys) {
                    state.snapshots[key]?.error = "完成结果待核对，请在 Todoist 中查看。"
                }
            }
            throw error
        }
    }
    public static func message(_ error: Error) -> String {
        if let e = error as? WidgetStorageError { return e.localizedDescription }
        if let e = error as? APIError { return e.localizedDescription }
        return "暂时无法同步，显示上次结果。"
    }
}
