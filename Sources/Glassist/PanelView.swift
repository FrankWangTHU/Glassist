import SwiftUI
import AppKit
import GlassistCore

struct GlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct PanelView: View {
    @ObservedObject var store: AppStore
    let index: Int
    @Environment(\.colorScheme) private var colorScheme
    private var settings: PanelSettings { store.preferences.panels[index] }
    private var content: PanelContent { store.panels[index] }
    private var accent: Color { index == 0 ? Color(red: 0.90, green: 0.32, blue: 0.24) : Color(red: 0.25, green: 0.49, blue: 0.53) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(index == 0 ? "左侧面板" : "右侧面板", systemImage: "square.split.2x1")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                if store.demo { Text("演示").font(.system(size: 10)).foregroundStyle(.secondary) }
                Button { store.onShowSettings?() } label: { Image(systemName: "slider.horizontal.3") }
                    .buttonStyle(.plain).help("编辑面板与连接设置").accessibilityLabel("编辑面板与连接设置")
            }.padding(.bottom, 13)
            HStack(alignment: .firstTextBaseline) {
                Text(settings.title.isEmpty ? (store.filter(index)?.name ?? "选择过滤器") : settings.title)
                    .font(.system(size: 24, weight: .semibold, design: .rounded)).lineLimit(2)
                Spacer(minLength: 6)
                Text("\(TaskDates.uniqueTasks(content.groups).count)")
                    .font(.system(size: 23, weight: .light, design: .rounded)).foregroundStyle(accent)
            }.padding(.bottom, 8)
            Picker("过滤器", selection: Binding(get: { store.selection(index) }, set: { store.select($0, panel: index) })) {
                Text("请选择…").tag("")
                ForEach(store.filters) { Text($0.name).tag($0.id) }
            }.labelsHidden().pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                let tasks = TaskDates.uniqueTasks(content.groups)
                HStack(spacing: 16) {
                    statistic("过期", tasks.filter { TaskDates.bucket($0.due, now: timeline.date, timeZone: store.context.timeZone) == .overdue }.count, color: .red)
                    statistic("今日", tasks.filter { TaskDates.bucket($0.due, now: timeline.date, timeZone: store.context.timeZone) == .today }.count, color: accent)
                    Spacer()
                    Text("当前过滤器").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }.padding(.vertical, 15)
            Divider().opacity(0.6)
            if let error = content.error ?? store.accountError {
                Text(error).font(.system(size: 11)).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true).padding(.vertical, 8)
            }
            if !store.uncertainCompletions.isEmpty {
                Text("有任务的完成结果尚未确认，请先在 Todoist 中核对。")
                    .font(.system(size: 11)).foregroundStyle(.orange)
                Button("已在 Todoist 核对，解除完成锁定") { store.acknowledgeUncertain() }
                    .font(.system(size: 11)).padding(.vertical, 4)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if content.groups.isEmpty && !store.isRefreshing {
                        VStack(spacing: 10) {
                            Image(systemName: "line.3.horizontal.decrease.circle").font(.system(size: 28, weight: .ultraLight))
                            Text(store.filters.isEmpty ? "连接 Todoist，选择已有过滤器" : "选择一个过滤器开始")
                                .font(.system(size: 13))
                            Button("打开设置") { store.onShowSettings?() }
                        }.foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 40)
                    } else if TaskDates.uniqueTasks(content.groups).isEmpty && content.error == nil {
                        Label("当前没有待办任务", systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 40)
                    }
                    ForEach(content.groups) { group in
                        if content.groups.count > 1 {
                            Text(group.query).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                                .padding(.top, 15).padding(.bottom, 3).textSelection(.enabled)
                        }
                        ForEach(group.tasks) { task in taskRow(task) }
                    }
                }.padding(.bottom, 8)
            }.scrollIndicators(.hidden)
            Divider().opacity(0.6)
            HStack(spacing: 6) {
                Circle().fill(store.demo ? Color.orange : (content.error == nil && store.accountError == nil ? Color.green : Color.orange)).frame(width: 5, height: 5)
                if store.demo { Text("示例任务 · 连接后显示你的清单") }
                else if store.isRefreshing { Text("正在同步…") }
                else if let updated = content.updated { Text("更新于 \(updated.formatted(date: .omitted, time: .shortened))") }
                else { Text("等待同步") }
                Spacer()
                Button { store.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain).disabled(store.isRefreshing || store.demo)
                    .help("刷新任务").accessibilityLabel("刷新任务")
            }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.top, 12)
        }
        .padding(22)
        .background {
            ZStack {
                GlassBackground()
                (colorScheme == .dark ? Color.black : Color.white).opacity(settings.tint)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.15 : 0.55), lineWidth: 1))
    }

    private func statistic(_ label: String, _ count: Int, color: Color) -> some View {
        HStack(spacing: 5) {
            Text(label).foregroundStyle(.secondary)
            Text("\(count)").foregroundStyle(count > 0 ? color : .secondary).monospacedDigit()
        }.font(.system(size: 12, weight: .medium))
    }

    private func taskRow(_ task: TodoTask) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Button { Task { await store.complete(task) } } label: {
                ZStack {
                    Circle().strokeBorder((task.priority ?? 1) == 4 ? Color.red : Color.secondary.opacity(0.6), lineWidth: 1.25)
                    if store.completing.contains(task.id) { ProgressView().controlSize(.mini) }
                }.frame(width: 20, height: 20).padding(.vertical, 2)
            }.buttonStyle(.plain).disabled(store.completing.contains(task.id) || store.uncertainCompletions.contains(task.id))
                .accessibilityLabel("完成任务：\(task.content)")
                .help(task.due?.isRecurring == true ? "完成本次，推进到下一次" : "完成任务（子任务也会完成）")
            Button { store.openTask(task) } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.content).font(.system(size: settings.fontSize)).multilineTextAlignment(.leading)
                        .foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                    Text(TaskDates.label(task.due, timeZone: store.context.timeZone))
                        .font(.system(size: 11)).foregroundStyle(TaskDates.bucket(task.due, timeZone: store.context.timeZone) == .overdue ? Color.red : .secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).help(store.demo ? "演示任务" : "在 Todoist 中打开")
        }.padding(.vertical, 14)
        .overlay(alignment: .bottom) { Divider().opacity(0.35).padding(.leading, 31) }
    }
}
