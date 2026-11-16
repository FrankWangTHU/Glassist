import SwiftUI
import WidgetKit

struct TaskEntry: TimelineEntry {
    var date: Date
    var configuration: SelectFilterIntent
    var snapshot: WidgetSnapshot?
    var message: String?
    var locked: Set<String> = []
    var preview = false
}
struct TaskProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TaskEntry { sample() }
    func snapshot(for configuration: SelectFilterIntent, in context: Context) async -> TaskEntry {
        if context.isPreview { return sample() }
        return await entry(configuration)
    }
    func timeline(for configuration: SelectFilterIntent, in context: Context) async -> Timeline<TaskEntry> {
        let value = await entry(configuration)
        return Timeline(entries: [value], policy: .after(Date().addingTimeInterval(15 * 60)))
    }
    private func entry(_ configuration: SelectFilterIntent) async -> TaskEntry {
        guard let filter = configuration.filter else {
            return TaskEntry(date: Date(), configuration: configuration, message: "右键编辑小组件，选择过滤器")
        }
        do {
            let snapshot = try await WidgetService.load(filterID: filter.id)
            let state = try WidgetStorage().read()
            guard state.connected, state.generation == snapshot.generation else { throw WidgetStorageError.changedAccount }
            return TaskEntry(date: Date(), configuration: configuration, snapshot: snapshot,
                             message: state.completionLocks.values.contains("uncertain") ? "有完成结果待核对" : snapshot.error,
                             locked: Set(state.completionLocks.keys))
        } catch {
            return TaskEntry(date: Date(), configuration: configuration, message: WidgetService.message(error))
        }
    }
    private func sample() -> TaskEntry {
        let filter = SavedFilter(id: "preview", name: "今日专注", query: "today")
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.string(from: Date())
        let tasks = [TodoTask(id: "preview1", content: "整理本周的想法", due: Due(date: date)),
                     TodoTask(id: "preview2", content: "留出专注时间", due: Due(date: date)),
                     TodoTask(id: "preview3", content: "准备明天的计划", due: Due(date: date))]
        return TaskEntry(date: Date(), configuration: SelectFilterIntent(),
                         snapshot: WidgetSnapshot(filter: filter, groups: [TaskGroup(id: 0, query: "today", tasks: tasks)], updated: Date(),
                                                  timezone: TimeZone.current.identifier, generation: UUID()), preview: true)
    }
}
struct TaskWidgetView: View {
    let entry: TaskEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    private var maximumRows: Int { family == .systemSmall ? 3 : family == .systemMedium ? 3 : 8 }
    private var zone: TimeZone { TimeZone(identifier: entry.snapshot?.timezone ?? "") ?? .current }
    private var tasks: [TodoTask] { entry.snapshot?.tasks ?? [] }
    private var accent: Color { renderingMode == .fullColor ? .red : .primary }
    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(entry.snapshot?.filter.name ?? entry.configuration.filter?.name ?? "Glassist")
                    .font(family == .systemSmall ? .headline : .title3.bold())
                    .lineLimit(1).foregroundStyle(accent).widgetAccentable()
                Text("\(tasks.count)").font(.subheadline).foregroundStyle(accent).widgetAccentable()
                Spacer(minLength: 0)
            }
            if entry.configuration.showCounts || entry.preview {
                HStack(spacing: 12) {
                    Text("过期 \(tasks.filter { TaskDates.bucket($0.due, now: entry.date, timeZone: zone) == .overdue }.count)")
                    Text("今日 \(tasks.filter { TaskDates.bucket($0.due, now: entry.date, timeZone: zone) == .today }.count)")
                }.font(.caption2).foregroundStyle(.secondary)
            }
            if let message = entry.message {
                Text(message).font(.caption2).foregroundStyle(.secondary).lineLimit(family == .systemSmall ? 2 : 3)
            }
            if entry.snapshot == nil {
                Spacer(minLength: 0)
                Link("打开 Glassist 设置", destination: URL(string: "glassist://setup")!).font(.caption)
            } else if tasks.isEmpty {
                Spacer(minLength: 0)
                Label("当前没有待办", systemImage: "checkmark.circle").font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(Array(tasks.prefix(maximumRows))) { task in
                    HStack(spacing: 9) {
                        if !entry.preview, task.due?.isRecurring != true, let snapshot = entry.snapshot,
                           !entry.locked.contains(task.id), entry.date.timeIntervalSince(snapshot.updated) < 86400 {
                            Button(intent: CompleteTaskIntent(id: task.id, generation: snapshot.generation)) {
                                Image(systemName: "circle").font(.body).foregroundStyle(.secondary)
                            }.buttonStyle(.plain).accessibilityLabel("完成：\(task.content)")
                        } else {
                            Image(systemName: "circle").font(.body).foregroundStyle(.secondary)
                        }
                        Link(destination: taskURL(task)) {
                            HStack {
                                Text(task.content).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                                if family != .systemSmall, task.due != nil {
                                    Text(TaskDates.label(task.due, now: entry.date, timeZone: zone))
                                        .font(.caption).foregroundStyle(TaskDates.bucket(task.due, now: entry.date, timeZone: zone) == .overdue ? accent : .secondary)
                                        .lineLimit(1)
                                }
                            }.font(family == .systemSmall ? .caption : .body)
                        }.foregroundStyle(.primary)
                    }
                    if family == .systemLarge { Divider() }
                }
            }
            Spacer(minLength: 0)
            if family != .systemSmall, let snapshot = entry.snapshot {
                HStack {
                    Text(entry.preview ? "示例" : "更新于 \(snapshot.updated.formatted(date: .omitted, time: .shortened))")
                    Spacer()
                    if tasks.count > maximumRows { Text("还有 \(tasks.count - maximumRows) 项") }
                }.font(.caption2).foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "glassist://setup"))
    }
    private func taskURL(_ task: TodoTask) -> URL {
        if entry.preview { return URL(string: "glassist://setup")! }
        var url = URLComponents(); url.scheme = "todoist"; url.host = "task"
        url.queryItems = [URLQueryItem(name: "id", value: task.id)]
        return url.url!
    }
}
@main struct GlassistWidget: Widget {
    let kind = "GlassistTasks"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectFilterIntent.self, provider: TaskProvider()) { entry in
            TaskWidgetView(entry: entry)
        }
        .configurationDisplayName("Todoist 过滤器")
        .description("选择已有过滤器，与日历和天气一起显示。每个实例独立设置。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
