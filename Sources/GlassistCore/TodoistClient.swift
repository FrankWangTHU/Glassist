import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum APIError: Error, LocalizedError {
    case unauthorized, forbidden, invalidFilter, invalidResponse, repeatedCursor, http(Int), rateLimited(TimeInterval)
    public var errorDescription: String? {
        switch self {
        case .unauthorized: return "连接已失效，请在设置中重新连接 Todoist。"
        case .forbidden: return "Todoist 未允许这项操作，请检查账号权限。"
        case .invalidFilter: return "过滤器无法解析，请在 Todoist 中检查分组、括号或查询条件。"
        case .invalidResponse: return "Todoist 返回了无法识别的数据。"
        case .repeatedCursor: return "任务分页异常，未显示不完整结果。请稍后重试。"
        case .http(let status): return "Todoist 暂时不可用（\(status)）。"
        case .rateLimited(let seconds): return "请求过于频繁，约 \(Int(seconds)) 秒后重试。"
        }
    }
}

public protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

private final class RedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        // Never forward the authorization header to a redirect target.
        completionHandler(nil)
    }
}

public final class LiveTransport: HTTPTransport, @unchecked Sendable {
    private let session: URLSession
    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 60
        config.urlCache = nil
        session = URLSession(configuration: config, delegate: RedirectGuard(), delegateQueue: nil)
    }
    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        return (data, response)
    }
}

public actor TodoistClient {
    private let token: String
    private let transport: any HTTPTransport
    private var syncToken = "*"
    private var filters: [String: SavedFilter] = [:]
    private var context = AccountContext()
    private var blockedUntil = Date.distantPast

    public init(token: String, transport: any HTTPTransport = LiveTransport()) {
        self.token = token; self.transport = transport
    }

    private struct SyncResponse: Decodable {
        let sync_token: String
        let full_sync: Bool?
        let filters: [SavedFilter]?
        let user: User?
        struct User: Decodable {
            let lang: String?
            let tz_info: Zone?
            struct Zone: Decodable { let timezone: String? }
        }
    }
    private struct Page: Decodable { let results: [TodoTask]; let next_cursor: String? }

    private func send(path: String, method: String = "GET", query: [URLQueryItem] = [], body: Data? = nil) async throws -> Data {
        try Task.checkCancellation()
        if blockedUntil > Date() { throw APIError.rateLimited(blockedUntil.timeIntervalSinceNow) }
        var components = URLComponents(string: "https://api.todoist.com/api/v1/" + path)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await transport.data(for: request)
        try Task.checkCancellation()
        switch response.statusCode {
        case 200..<300: return data
        case 401: throw APIError.unauthorized
        case 403: throw APIError.forbidden
        case 400 where path == "tasks/filter": throw APIError.invalidFilter
        case 429:
            let header = response.value(forHTTPHeaderField: "Retry-After") ?? "60"
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
            let parsed = Double(header) ?? formatter.date(from: header)?.timeIntervalSinceNow ?? 60
            // Invalid or overflowing server values must not reach Date or Int conversion.
            let delay = parsed.isFinite && parsed < Double(Int.max / 2) ? max(1, parsed) : 60
            blockedUntil = Date().addingTimeInterval(delay)
            throw APIError.rateLimited(delay)
        default: throw APIError.http(response.statusCode)
        }
    }

    private func readFilters() async throws -> Bool {
        var body = URLComponents()
        body.queryItems = [URLQueryItem(name: "sync_token", value: syncToken),
                           URLQueryItem(name: "resource_types", value: "[\"filters\",\"user\"]")]
        // Form encoding must escape plus signs; query encoding otherwise treats them literally.
        let data = try await send(path: "sync", method: "POST", body: Data(body.percentEncodedQuery!.replacingOccurrences(of: "+", with: "%2B").utf8))
        let result = try JSONDecoder().decode(SyncResponse.self, from: data)
        if result.full_sync == true { filters.removeAll() }
        for filter in result.filters ?? [] {
            if filter.isDeleted == true { filters.removeValue(forKey: filter.id) }
            else { filters[filter.id] = filter }
        }
        if let user = result.user {
            context = AccountContext(language: user.lang ?? context.language,
                                     timeZone: user.tz_info?.timezone.flatMap(TimeZone.init(identifier:)) ?? context.timeZone)
        }
        syncToken = result.sync_token
        return result.full_sync == true
    }

    public func savedFilters() async throws -> ([SavedFilter], AccountContext) {
        // A full sync may be a cached snapshot. Immediately catch up with one incremental sync.
        if try await readFilters() { _ = try await readFilters() }
        let sorted = filters.values.sorted {
            if let a = $0.orderKey, let b = $1.orderKey, a != b { return a < b }
            if $0.itemOrder != $1.itemOrder { return ($0.itemOrder ?? 0) < ($1.itemOrder ?? 0) }
            return $0.id < $1.id
        }
        return (sorted, context)
    }

    public func tasks(query: String, language: String) async throws -> [TaskGroup] {
        var groups: [TaskGroup] = []
        for (index, part) in try FilterQuery.groups(query).enumerated() {
            var tasks: [TodoTask] = [], cursor: String?, cursors = Set<String>(), ids = Set<String>()
            repeat {
                var parameters = [URLQueryItem(name: "query", value: part), URLQueryItem(name: "lang", value: language), URLQueryItem(name: "limit", value: "200")]
                if let cursor { parameters.append(URLQueryItem(name: "cursor", value: cursor)) }
                let data = try await send(path: "tasks/filter", query: parameters)
                let page = try JSONDecoder().decode(Page.self, from: data)
                tasks += page.results.filter { $0.checked != true && $0.isDeleted != true && ids.insert($0.id).inserted }
                cursor = page.next_cursor
                if let cursor, !cursors.insert(cursor).inserted { throw APIError.repeatedCursor }
            } while cursor != nil
            groups.append(TaskGroup(id: index, query: part, tasks: tasks))
        }
        return groups
    }

    public func closeTask(id: String) async throws {
        guard !id.isEmpty, id.allSatisfy({ $0.isLetter || $0.isNumber }) else { throw APIError.invalidResponse }
        // Never automatically retry completion: a recurring task may advance twice.
        _ = try await send(path: "tasks/\(id)/close", method: "POST")
    }
}
