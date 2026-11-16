import AppKit
import SwiftUI
import GlassistCore

struct PanelSettings: Codable, Equatable {
    var filterID = ""
    var title = ""
    var width = 350.0
    var height = 450.0
    var fontSize = 15.0
    var tint = 0.18
}
struct Preferences: Codable {
    var panels = [PanelSettings(), PanelSettings()]
    var refreshSeconds = 120.0
    var floating = false
    var locked = false
    var appearance = "system"
}
struct PanelContent {
    var filterID = ""
    var groups: [TaskGroup] = []
    var updated: Date?
    var error: String?
}

@MainActor final class AppStore: ObservableObject {
    @Published var preferences: Preferences {
        didSet {
            if let data = try? JSONEncoder().encode(preferences) { UserDefaults.standard.set(data, forKey: "preferences-v1") }
            onAppearanceChange?()
            if oldValue.panels.map(\.filterID) != preferences.panels.map(\.filterID) {
                for index in 0..<2 where oldValue.panels[index].filterID != preferences.panels[index].filterID {
                    panels[index] = PanelContent()
                }
                refresh()
            }
            if oldValue.refreshSeconds != preferences.refreshSeconds { startTimer() }
        }
    }
    @Published var filters: [SavedFilter] = []
    @Published var panels = [PanelContent(), PanelContent()]
    @Published var demo = true
    @Published var isRefreshing = false
    @Published var connecting = false
    @Published var accountError: String?
    @Published var completing = Set<String>()
    @Published var uncertainCompletions = Set<String>()
    @Published var context = AccountContext()
    var onAppearanceChange: (() -> Void)?
    var onShowSettings: (() -> Void)?
    private var client: TodoistClient?
    private var refreshWork: Task<Void, Never>?
    private var generation = 0
    private var accountGeneration = 0
    private var timer: Timer?
    private var demoContent: [PanelContent] = []

    init() {
        if let data = UserDefaults.standard.data(forKey: "preferences-v1"),
           let settings = try? JSONDecoder().decode(Preferences.self, from: data), settings.panels.count == 2 {
            preferences = settings
        } else { preferences = Preferences() }
        loadDemo()
        do {
            if let token = try Keychain.read() {
                demo = false; filters = []; panels = [PanelContent(), PanelContent()]
                client = TodoistClient(token: token)
            }
        } catch { accountError = error.localizedDescription }
        startTimer()
    }

    private func loadDemo() {
        filters = [SavedFilter(id: "demo-focus", name: "今日专注", query: "today | overdue"),
                   SavedFilter(id: "demo-life", name: "生活清单", query: "#Personal")]
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let today = f.string(from: Date())
        let yesterday = f.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        panels = [
            PanelContent(filterID: "demo-focus", groups: [TaskGroup(id: 0, query: "today | overdue", tasks: [
                TodoTask(id: "demo-1", content: "整理本周的想法", due: Due(date: yesterday), priority: 4),
                TodoTask(id: "demo-2", content: "留出一小时专注时间", due: Due(date: today), priority: 3),
                TodoTask(id: "demo-3", content: "准备明天的计划", due: Due(date: today))])]),
            PanelContent(filterID: "demo-life", groups: [TaskGroup(id: 0, query: "#Personal", tasks: [
                TodoTask(id: "demo-4", content: "出门散步二十分钟", due: Due(date: today, isRecurring: true)),
                TodoTask(id: "demo-5", content: "读完床头的书"),
                TodoTask(id: "demo-6", content: "给植物浇水")])])]
        demoContent = panels
    }

    func selection(_ index: Int) -> String { demo ? panels[index].filterID : preferences.panels[index].filterID }
    func select(_ id: String, panel index: Int) {
        if demo {
            let source = demoContent.first { $0.filterID == id }
            panels[index] = source ?? PanelContent(filterID: id)
        } else { preferences.panels[index].filterID = id }
    }
    func filter(_ index: Int) -> SavedFilter? { filters.first { $0.id == selection(index) } }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: max(60, preferences.refreshSeconds), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func connect(token: String) async -> Bool {
        guard !connecting, completing.isEmpty else { return false }
        connecting = true; accountError = nil
        defer { connecting = false }
        let candidate = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { accountError = "请在本机输入 Todoist API token。"; return false }
        let newClient = TodoistClient(token: candidate)
        do {
            let (newFilters, newContext) = try await newClient.savedFilters()
            try Keychain.save(candidate)
            invalidateRefresh(); accountGeneration += 1
            client = newClient; demo = false; context = newContext
            filters = newFilters; panels = [PanelContent(), PanelContent()]
            uncertainCompletions.removeAll()
            // Each new connection starts with no cross-account filter selections.
            var next = preferences
            next.panels[0].filterID = newFilters.first?.id ?? ""
            next.panels[1].filterID = newFilters.dropFirst().first?.id ?? newFilters.first?.id ?? ""
            preferences = next
            refresh()
            return true
        } catch { accountError = safeMessage(error); return false }
    }

    func disconnect() {
        guard completing.isEmpty, !connecting else { return }
        do { try Keychain.delete() }
        catch { accountError = error.localizedDescription; return }
        invalidateRefresh(); accountGeneration += 1
        client = nil; demo = true; accountError = nil; uncertainCompletions.removeAll()
        preferences.panels[0].filterID = ""; preferences.panels[1].filterID = ""
        loadDemo()
    }

    private func invalidateRefresh() {
        generation += 1; refreshWork?.cancel(); isRefreshing = false
    }

    func refresh() {
        guard !demo, let client, completing.isEmpty else { return }
        invalidateRefresh()
        let currentGeneration = generation
        isRefreshing = true
        refreshWork = Task {
            defer { if currentGeneration == generation { isRefreshing = false } }
            do {
                let (loadedFilters, loadedContext) = try await client.savedFilters()
                try Task.checkCancellation()
                guard currentGeneration == generation else { return }
                filters = loadedFilters; context = loadedContext; accountError = nil
                var byQuery: [String: [TaskGroup]] = [:]
                for index in 0..<2 {
                    let id = preferences.panels[index].filterID
                    guard let selected = loadedFilters.first(where: { $0.id == id }) else {
                        panels[index] = PanelContent(filterID: id, error: id.isEmpty ? nil : "这个过滤器已删除或不可用，请重新选择。")
                        continue
                    }
                    do {
                        let groups: [TaskGroup]
                        if let cached = byQuery[selected.query] { groups = cached }
                        else { groups = try await client.tasks(query: selected.query, language: loadedContext.language) }
                        try Task.checkCancellation()
                        guard currentGeneration == generation else { return }
                        byQuery[selected.query] = groups
                        panels[index] = PanelContent(filterID: id, groups: groups, updated: Date())
                    } catch {
                        if Task.isCancelled || currentGeneration != generation { return }
                        panels[index].error = safeMessage(error)
                    }
                }
            } catch {
                if Task.isCancelled || currentGeneration != generation { return }
                accountError = safeMessage(error)
            }
        }
    }

    func complete(_ task: TodoTask) async {
        guard !completing.contains(task.id), !uncertainCompletions.contains(task.id) else { return }
        if demo { removeTask(task.id); return }
        guard let client, !connecting else { return }
        invalidateRefresh()
        let account = accountGeneration
        completing.insert(task.id)
        defer { completing.remove(task.id); if completing.isEmpty { refresh() } }
        do {
            try await client.closeTask(id: task.id)
            guard account == accountGeneration else { return }
            removeTask(task.id)
        } catch {
            guard account == accountGeneration else { return }
            uncertainCompletions.insert(task.id)
            accountError = "完成结果未确认。请在 Todoist 中核对，避免循环任务重复推进。" + safeMessage(error)
        }
    }
    func acknowledgeUncertain() { uncertainCompletions.removeAll(); refresh() }
    private func removeTask(_ id: String) {
        for index in 0..<2 {
            for group in panels[index].groups.indices { panels[index].groups[group].tasks.removeAll { $0.id == id } }
        }
        if demo {
            for index in demoContent.indices {
                for group in demoContent[index].groups.indices { demoContent[index].groups[group].tasks.removeAll { $0.id == id } }
            }
        }
    }
    func openTask(_ task: TodoTask) {
        guard !demo else { return }
        var link = URLComponents(); link.scheme = "todoist"; link.host = "task"
        link.queryItems = [URLQueryItem(name: "id", value: task.id)]
        guard let url = link.url else { return }
        if !NSWorkspace.shared.open(url) {
            var web = URLComponents(string: "https://app.todoist.com/app/task/\(task.id)")!
            web.queryItems = nil
            if let url = web.url { NSWorkspace.shared.open(url) }
        }
    }
    private func safeMessage(_ error: Error) -> String {
        if let error = error as? APIError { return error.localizedDescription }
        if error is DecodingError { return "Todoist 数据格式发生变化，请更新 Glassist。" }
        if let error = error as? Keychain.Failure { return error.localizedDescription }
        return "网络连接失败，请稍后刷新。"
    }
}
