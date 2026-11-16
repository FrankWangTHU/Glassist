import SwiftUI
import WidgetKit

extension WidgetTint {
    var color: Color {
        switch self {
        case .coral: return Color(red: 0.87, green: 0.25, blue: 0.22)
        case .ocean: return Color(red: 0.24, green: 0.45, blue: 0.70)
        case .sage: return Color(red: 0.27, green: 0.51, blue: 0.40)
        case .graphite: return .primary
        }
    }
}

extension TaskEntry {
    var destination: WidgetRoute {
        if let id = snapshot?.filter.id ?? configuration.filter?.id, !preview { return .filter(id) }
        return .home
    }
}

struct WidgetSurface: View {
    let tint: WidgetTint
    var body: some View {
        Rectangle().fill(.background)
            .overlay(LinearGradient(colors: [tint.color.opacity(0.055), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}

struct TaskWidgetView: View {
    let entry: TaskEntry
    var previewFamily: WidgetFamily? = nil
    @Environment(\.widgetFamily) private var systemFamily
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var family: WidgetFamily { previewFamily ?? systemFamily }
    private func t(_ key: String) -> String { entry.language.text(key) }
    private var small: Bool { family == .systemSmall }
    private var large: Bool { family == .systemLarge }
    private var compact: Bool { entry.configuration.density == .compact }
    private var zone: TimeZone { TimeZone(identifier: entry.snapshot?.timezone ?? "") ?? .current }
    private var tasks: [TodoTask] { entry.snapshot?.tasks ?? [] }
    private var accent: Color { renderingMode == .fullColor ? entry.configuration.tint.color : .primary }
    private var title: String {
        let custom = entry.configuration.customTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return custom.isEmpty ? (entry.snapshot?.filter.name ?? entry.configuration.filter?.name ?? "Glassist") : custom
    }
    private var showFooter: Bool { large && entry.configuration.showFooter }
    private var rowHeight: CGFloat { large ? (compact ? 27 : 34) : (compact ? 21 : 25) }
    private var headerHeight: CGFloat { small ? 24 : 27 }
    private var motion: Animation? { reduceMotion ? nil : .smooth(duration: 0.28) }
    private func capacity(_ height: CGFloat) -> Int {
        let stats: CGFloat = entry.configuration.showCounts || (small && entry.feedback != nil) ? 24 : 0
        let footer: CGFloat = showFooter ? 24 : 0
        let warning: CGFloat = entry.message != nil && large ? 26 : 0
        return max(1, min(large ? 10 : 4, Int((height - headerHeight - stats - footer - warning - 8) / rowHeight)))
    }

    var body: some View {
        GeometryReader { geometry in
            let maximum = capacity(geometry.size.height)
            VStack(alignment: .leading, spacing: 0) {
                header.frame(height: headerHeight)
                if small, let feedback = entry.feedback {
                    feedbackLabel(feedback).font(.system(size: 10, weight: .medium)).lineLimit(1)
                        .padding(.top, 7).frame(height: 24)
                } else if entry.configuration.showCounts {
                    statistics.padding(.top, 7).frame(height: 24)
                }
                if entry.snapshot == nil {
                    connectionPrompt.frame(maxHeight: .infinity)
                } else if tasks.isEmpty {
                    emptyState.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(tasks.prefix(maximum))) { task in
                            taskRow(task)
                                .frame(height: rowHeight)
                                .overlay(alignment: .bottom) {
                                    if large, task.id != tasks.prefix(maximum).last?.id {
                                        Rectangle().fill(.primary.opacity(0.065)).frame(height: 0.5).padding(.leading, 32)
                                    }
                                }
                                .transition(reduceMotion ? .opacity : .asymmetric(insertion: .opacity, removal: .opacity.combined(with: .move(edge: .leading))))
                        }
                    }.padding(.top, 8)
                        .animation(motion, value: tasks.map(\.id))
                    Spacer(minLength: 0)
                }
                if let message = entry.message, large, entry.snapshot != nil {
                    Label(entry.language.message(message), systemImage: "exclamationmark.circle")
                        .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading).frame(height: 26)
                }
                if showFooter { footer(maximum: maximum).padding(.top, 8).frame(height: 24) }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 7) {
            WidgetLink(destination: entry.destination.url) {
                HStack(spacing: 7) {
                    Text(title).font(.system(size: small ? 15 : 17, weight: .bold, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.85)
                    if entry.snapshot != nil {
                        Text("\(tasks.count)").font(.system(size: 11, weight: .semibold, design: .rounded))
                            .contentTransition(.numericText()).invalidatableContent()
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(accent.opacity(0.08), in: Capsule())
                    }
                }.foregroundStyle(accent).widgetAccentable()
            }.accessibilityLabel(t("在 Todoist 中打开") + title)
            Spacer(minLength: 0)
            WidgetLink(destination: WidgetRoute.addTask.url) {
                Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accent).frame(width: 26, height: 26)
                    .background(accent.opacity(0.09), in: Circle())
            }.widgetAccentable().accessibilityLabel(t("在 Todoist 中新建任务"))
        }
    }

    private var statistics: some View {
        HStack(spacing: small ? 9 : 14) {
            let overdue = tasks.filter { TaskDates.bucket($0.due, now: entry.date, timeZone: zone) == .overdue }.count
            let today = tasks.filter { TaskDates.bucket($0.due, now: entry.date, timeZone: zone) == .today }.count
            HStack(spacing: 4) {
                if !small { Circle().fill(overdue > 0 ? accent : .secondary).frame(width: 4, height: 4) }
                Text(t("过期")); Text("\(overdue)").fontWeight(.semibold).contentTransition(.numericText())
            }
            HStack(spacing: 4) {
                Text(t("今日")); Text("\(today)").fontWeight(.semibold).contentTransition(.numericText())
            }
            Spacer(minLength: 0)
            if !large, !small, let feedback = entry.feedback { feedbackLabel(feedback).lineLimit(1) }
        }.font(.system(size: small ? 10 : 11)).foregroundStyle(.secondary).invalidatableContent()
    }

    private func taskRow(_ task: TodoTask) -> some View {
        HStack(spacing: small ? 6 : 9) {
            let locked = entry.locked.contains(task.id)
            let color = priorityColor(task)
            if !entry.preview, task.due?.isRecurring != true, let snapshot = entry.snapshot,
               !locked, entry.date.timeIntervalSince(snapshot.updated) < 86400 {
                Toggle(isOn: false, intent: CompleteTaskIntent(id: task.id, generation: snapshot.generation)) {
                    Text(t("完成：") + task.content)
                }
                .toggleStyle(CompletionToggleStyle(color: color, reduceMotion: reduceMotion, language: entry.language))
            } else if entry.preview {
                CompletionMark(isOn: false, color: color).frame(width: 24, height: 24)
            } else {
                WidgetLink(destination: WidgetRoute.task(task.id).url) {
                    Image(systemName: locked ? "exclamationmark.circle" : (task.due?.isRecurring == true ? "arrow.triangle.2.circlepath" : "circle"))
                        .font(.system(size: 17, weight: .regular)).foregroundStyle(.secondary).frame(width: 24, height: 24)
                }.accessibilityLabel(t(locked ? "在 Todoist 中核对完成结果" : "在 Todoist 中完成此任务"))
            }
            WidgetLink(destination: entry.preview ? WidgetRoute.home.url : WidgetRoute.task(task.id).url) {
                HStack(spacing: 8) {
                    Text(task.content).font(.system(size: large ? (compact ? 13 : 14) : (compact ? 11 : 12), weight: .medium))
                        .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                    if !small, entry.configuration.showDates, task.due != nil {
                        Text(TaskDates.label(task.due, now: entry.date, timeZone: zone, language: entry.language))
                            .font(.system(size: compact ? 9 : 10, weight: .medium))
                            .foregroundStyle(TaskDates.bucket(task.due, now: entry.date, timeZone: zone) == .overdue ? accent : .secondary)
                            .lineLimit(1).frame(maxWidth: large ? 98 : 75, alignment: .trailing)
                    }
                }.foregroundStyle(.primary).contentShape(Rectangle())
            }
        }
    }

    private func priorityColor(_ task: TodoTask) -> Color {
        guard renderingMode == .fullColor else { return .primary }
        switch task.priority ?? 1 {
        case 4: return entry.configuration.tint.color
        case 3: return .orange
        case 2: return .blue
        default: return .secondary
        }
    }
    private func feedbackLabel(_ feedback: CompletionFeedback) -> some View {
        Label(t(feedback.succeeded ? "已完成一项" : "请核对同步结果"), systemImage: feedback.succeeded ? "checkmark.circle.fill" : "exclamationmark.circle")
            .foregroundStyle(feedback.succeeded && renderingMode == .fullColor ? Color.green : .secondary)
            .transition(.opacity).animation(motion, value: feedback.succeeded)
    }
    private func footer(maximum: Int) -> some View {
        HStack(spacing: 5) {
            if let feedback = entry.feedback { feedbackLabel(feedback) }
            else if let snapshot = entry.snapshot {
                Image(systemName: "arrow.clockwise").font(.system(size: 8))
                Text(entry.preview ? t("刚刚更新") : snapshot.updated.formatted(.dateTime.hour().minute().locale(entry.language.locale)))
            }
            Spacer(minLength: 4)
            if tasks.count > maximum {
                WidgetLink(entry.language.format("还有 %d 项", tasks.count - maximum), destination: entry.destination.url)
            }
            WidgetLink(destination: WidgetRoute.settings.url) {
                Image(systemName: "slider.horizontal.3").frame(width: 22, height: 18)
            }.accessibilityLabel(t("打开 Glassist 设置"))
        }.font(.system(size: 10)).foregroundStyle(.secondary)
    }
    private var connectionPrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.language.message(entry.message ?? "连接你的 Todoist"))
                .font(.system(size: small ? 11 : 12)).foregroundStyle(.secondary).lineLimit(3)
            WidgetLink(t("打开设置 →"), destination: WidgetRoute.settings.url)
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(accent)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var emptyState: some View {
        VStack(spacing: 7) {
            Image(systemName: "checkmark.circle").font(.system(size: large ? 30 : 22, weight: .light)).foregroundStyle(accent)
            Text(t("留一点空白给自己")).font(.system(size: small ? 11 : 13, weight: .medium))
            if large { Text(t("当前过滤器没有待办事项")).font(.system(size: 11)).foregroundStyle(.secondary) }
        }
    }
}

struct CompletionMark: View {
    var isOn: Bool
    var color: Color
    var body: some View {
        ZStack {
            Circle().fill(color.opacity(isOn ? 1 : 0.035))
            Circle().strokeBorder(color.opacity(isOn ? 1 : 0.75), lineWidth: 1.3)
            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white).opacity(isOn ? 1 : 0).scaleEffect(isOn ? 1 : 0.65)
        }.frame(width: 18, height: 18)
    }
}

struct CompletionToggleStyle: ToggleStyle {
    let color: Color
    let reduceMotion: Bool
    var language: AppLanguage = .chinese
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            CompletionMark(isOn: configuration.isOn, color: color)
                .scaleEffect(configuration.isOn ? 0.94 : 1)
                .frame(width: 24, height: 24).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: configuration.isOn)
            .accessibilityLabel(language.text("完成任务"))
            .accessibilityValue(language.text(configuration.isOn ? "正在完成" : "未完成"))
    }
}

#if DESIGN_PREVIEW
// ImageRenderer cannot rasterize native Link controls. Preview their unchanged SwiftUI labels.
private struct WidgetLink<Label: View>: View {
    var label: Label
    init(destination: URL, @ViewBuilder label: () -> Label) { self.label = label() }
    var body: some View { label }
}
private extension WidgetLink where Label == Text {
    init(_ title: String, destination: URL) { self.label = Text(title) }
}
#else
private typealias WidgetLink<Label: View> = Link<Label>
#endif
