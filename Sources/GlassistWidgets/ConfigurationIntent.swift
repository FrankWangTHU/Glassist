import AppIntents
import WidgetKit

struct FilterEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Todoist 过滤器"
    static var defaultQuery = FilterEntityQuery()
    let id: String
    let name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}
struct FilterEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [FilterEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }
    func suggestedEntities() async throws -> [FilterEntity] {
        let state = try WidgetStorage().read()
        return state.filters.map { FilterEntity(id: $0.id, name: $0.name) }
    }
    func defaultResult() async -> FilterEntity? { try? await suggestedEntities().first }
}
struct SelectFilterIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "选择 Todoist 过滤器"
    static var description = IntentDescription("每个小组件独立显示一个已保存的过滤器。")
    @Parameter(title: "过滤器") var filter: FilterEntity?
    @Parameter(title: "显示统计", default: true) var showCounts: Bool
}
struct CompleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "完成 Todoist 任务"
    static var isDiscoverable = false
    @Parameter(title: "任务") var taskID: String
    @Parameter(title: "账号版本") var generation: String
    init() {}
    init(id: String, generation: UUID) { self.taskID = id; self.generation = generation.uuidString }
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: generation) else { return .result() }
        // Errors are stored for the next timeline rather than hidden by a failed intent.
        try? await WidgetService.complete(id: taskID, generation: id)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
