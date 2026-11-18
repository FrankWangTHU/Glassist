import AppIntents
import WidgetKit

// App Intent metadata is localized by the system in a separate process.
// Use an explicit table and English source values matching the bundle development region.
struct FilterEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: LocalizedStringResource("Todoist filter", table: "WidgetIntents"))
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
    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: LocalizedStringResource("Layout", table: "WidgetIntents"))
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [.comfortable: DisplayRepresentation(title: LocalizedStringResource("Roomy", table: "WidgetIntents")), .compact: DisplayRepresentation(title: LocalizedStringResource("Compact · more tasks", table: "WidgetIntents"))]
}
enum WidgetTint: String, AppEnum {
    case coral, ocean, sage, graphite
    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: LocalizedStringResource("Accent color", table: "WidgetIntents"))
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [.coral: DisplayRepresentation(title: LocalizedStringResource("Coral", table: "WidgetIntents")), .ocean: DisplayRepresentation(title: LocalizedStringResource("Ocean", table: "WidgetIntents")), .sage: DisplayRepresentation(title: LocalizedStringResource("Sage", table: "WidgetIntents")), .graphite: DisplayRepresentation(title: LocalizedStringResource("Graphite", table: "WidgetIntents"))]
}
enum WidgetLanguage: String, AppEnum {
    case app, chinese, english
    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: LocalizedStringResource("Language", table: "WidgetIntents"))
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [.app: DisplayRepresentation(title: LocalizedStringResource("Follow app", table: "WidgetIntents")), .chinese: DisplayRepresentation(title: LocalizedStringResource("Simplified Chinese", table: "WidgetIntents")), .english: DisplayRepresentation(title: LocalizedStringResource("English", table: "WidgetIntents"))]
    func resolve(_ appValue: String?) -> AppLanguage {
        switch self {
        case .app: return appValue.flatMap(AppLanguage.init(rawValue:)) ?? .chinese
        case .chinese: return .chinese
        case .english: return .english
        }
    }
}
struct SelectFilterIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("Choose a Todoist filter", table: "WidgetIntents")
    static var description = IntentDescription(LocalizedStringResource("Each widget shows one saved filter, independently.", table: "WidgetIntents"))
    @Parameter(title: LocalizedStringResource("Filter", table: "WidgetIntents")) var filter: FilterEntity?
    @Parameter(title: LocalizedStringResource("Show counts", table: "WidgetIntents"), default: true) var showCounts: Bool
    @Parameter(title: LocalizedStringResource("Layout", table: "WidgetIntents"), default: .comfortable) var density: WidgetDensity
    @Parameter(title: LocalizedStringResource("Accent color", table: "WidgetIntents"), default: .coral) var tint: WidgetTint
    @Parameter(title: LocalizedStringResource("Show dates", table: "WidgetIntents"), default: true) var showDates: Bool
    @Parameter(title: LocalizedStringResource("Show footer (large)", table: "WidgetIntents"), default: true) var showFooter: Bool
    @Parameter(title: LocalizedStringResource("Custom title", table: "WidgetIntents")) var customTitle: String?
    @Parameter(title: LocalizedStringResource("Language", table: "WidgetIntents"), default: .app) var interfaceLanguage: WidgetLanguage
}
struct CompleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("Complete Todoist task", table: "WidgetIntents")
    static var isDiscoverable = false
    @Parameter(title: LocalizedStringResource("Task", table: "WidgetIntents")) var taskID: String
    @Parameter(title: LocalizedStringResource("Account version", table: "WidgetIntents")) var generation: String
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
