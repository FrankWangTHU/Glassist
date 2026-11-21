import SwiftUI
import WidgetKit

struct TaskEntry: TimelineEntry {
    var date: Date
    var configuration: SelectFilterIntent
    var snapshot: WidgetSnapshot?
    var message: String?
    var locked: Set<String> = []
    var feedback: CompletionFeedback?
    var preview = false
    var language: AppLanguage = .system
}
struct TaskProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TaskEntry { sample() }
    func snapshot(for configuration: SelectFilterIntent, in context: Context) async -> TaskEntry {
        if context.isPreview { return sample(configuration) }
        return await entry(configuration)
    }
    func timeline(for configuration: SelectFilterIntent, in context: Context) async -> Timeline<TaskEntry> {
        let value = await entry(configuration)
        var entries = [value]
        if let feedback = value.feedback {
            var settled = value
            settled.date = max(Date().addingTimeInterval(1), feedback.date.addingTimeInterval(6))
            settled.feedback = nil
            entries.append(settled)
        }
        return Timeline(entries: entries, policy: .after(Date().addingTimeInterval(15 * 60)))
    }
    private func entry(_ configuration: SelectFilterIntent) async -> TaskEntry {
        let language = configuration.interfaceLanguage.resolve((try? WidgetStorage().read())?.interfaceLanguage)
        guard let filter = configuration.filter else {
            return TaskEntry(date: Date(), configuration: configuration, message: "右键编辑小组件，选择过滤器", language: language)
        }
        do {
            let before = try WidgetStorage().read()
            guard before.connected else { throw WidgetStorageError.disconnected }
            // After an interaction, show the confirmed local result immediately; avoid an extra API round trip.
            let snapshot: WidgetSnapshot
            if before.feedback?.isRecent(for: filter.id) == true,
               let cached = before.snapshots[filter.id], cached.generation == before.generation {
                snapshot = cached
            } else { snapshot = try await WidgetService.load(filterID: filter.id) }
            let state = try WidgetStorage().read()
            guard state.connected, state.generation == snapshot.generation else { throw WidgetStorageError.changedAccount }
            return TaskEntry(date: Date(), configuration: configuration, snapshot: snapshot,
                             message: state.completionLocks.values.contains("uncertain") ? "有完成结果待核对" : snapshot.error,
                             locked: Set(state.completionLocks.keys),
                             feedback: state.feedback?.isRecent(for: filter.id) == true ? state.feedback : nil, language: language)
        } catch {
            return TaskEntry(date: Date(), configuration: configuration, message: WidgetService.message(error), language: language)
        }
    }
    private func sample(_ configuration: SelectFilterIntent = SelectFilterIntent()) -> TaskEntry {
        let language = configuration.interfaceLanguage.resolve((try? WidgetStorage().read())?.interfaceLanguage)
        let filter = SavedFilter(id: "preview", name: language.text("今日专注"), query: "today")
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.string(from: Date())
        let tasks = [TodoTask(id: "preview1", content: language.text("整理本周的想法"), due: Due(date: date)),
                     TodoTask(id: "preview2", content: language.text("留出专注时间"), due: Due(date: date)),
                     TodoTask(id: "preview3", content: language.text("准备明天的计划"), due: Due(date: date))]
        return TaskEntry(date: Date(), configuration: configuration,
                         snapshot: WidgetSnapshot(filter: filter, groups: [TaskGroup(id: 0, query: "today", tasks: tasks)], updated: Date(),
                                                  timezone: TimeZone.current.identifier, generation: UUID()), preview: true, language: language)
    }
}
/* The visual surface is kept separate so the same code can render design previews. */
#if !DESIGN_PREVIEW
@main struct GlassistWidget: Widget {
    let kind = "GlassistTasks"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectFilterIntent.self, provider: TaskProvider()) { entry in
            TaskWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetSurface(tint: entry.configuration.tint) }
                .widgetURL(entry.snapshot == nil ? WidgetRoute.settings.url : entry.destination.url)
        }
        .configurationDisplayName("Glassist · Todoist 过滤器")
        .description("轻点查看，勾选完成，随手记录。过滤器、颜色和布局均可独立调整。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .containerBackgroundRemovable(true)
    }
}
#endif
