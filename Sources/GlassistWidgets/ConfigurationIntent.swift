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
enum WidgetDensity: String, AppEnum {
    case comfortable, compact
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "布局"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [.comfortable: "舒适", .compact: "紧凑 · 更多任务"]
}
enum WidgetTint: String, AppEnum {
    case coral, ocean, sage, graphite
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "强调色"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [.coral: "珊瑚红", .ocean: "雾蓝", .sage: "鼠尾草绿", .graphite: "石墨"]
}
enum WidgetLanguage: String, AppEnum {
    case app, chinese, english
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "界面语言"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [.app: "跟随应用", .chinese: "简体中文", .english: "English"]
    func resolve(_ appValue: String?) -> AppLanguage {
        switch self {
        case .app: return appValue.flatMap(AppLanguage.init(rawValue:)) ?? .chinese
        case .chinese: return .chinese
        case .english: return .english
        }
    }
}
struct SelectFilterIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "选择 Todoist 过滤器"
    static var description = IntentDescription("每个小组件独立显示一个已保存的过滤器。")
    @Parameter(title: "过滤器") var filter: FilterEntity?
    @Parameter(title: "显示统计", default: true) var showCounts: Bool
    @Parameter(title: "布局", default: .comfortable) var density: WidgetDensity
    @Parameter(title: "强调色", default: .coral) var tint: WidgetTint
    @Parameter(title: "显示日期", default: true) var showDates: Bool
    @Parameter(title: "显示底栏（大尺寸）", default: true) var showFooter: Bool
    @Parameter(title: "自定义标题") var customTitle: String?
    @Parameter(title: "界面语言", default: .app) var interfaceLanguage: WidgetLanguage
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
        do { try await WidgetService.complete(id: taskID, generation: id) }
        catch WidgetStorageError.completionLocked { /* Duplicate/uncertain requests must not be resubmitted. */ }
        catch {
            try? WidgetStorage().recordCompletionFailure(id: taskID, generation: id, uncertain: false,
                                                         message: WidgetService.message(error))
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
