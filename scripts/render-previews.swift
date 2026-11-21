import SwiftUI
import WidgetKit
import AppKit

// This renders the actual widget view with fictional fixtures; it never opens the shared account store.
@main struct RenderPreviews {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let output = CommandLine.arguments.dropFirst().first ?? "/tmp/Glassist-preview.png"
        let view = PreviewSheet(language: CommandLine.arguments.contains("--english") ? .english : .chinese).environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: view)
        let jpeg = URL(fileURLWithPath: output).pathExtension.lowercased() == "jpg"
        renderer.scale = jpeg ? 1.5 : 2
        guard let image = renderer.nsImage, let data = image.tiffRepresentation,
              let rendered = NSBitmapImageRep(data: data)?.representation(using: jpeg ? .jpeg : .png,
                    properties: jpeg ? [.compressionFactor: 0.8] : [:]) else {
            throw NSError(domain: "Preview", code: 1)
        }
        try rendered.write(to: URL(fileURLWithPath: output))
        print(output)
    }
}

private struct PreviewSheet: View {
    var language: AppLanguage = .chinese
    func copy(_ zh: String, _ en: String) -> String { language.isChinese ? zh : en }
    func entry(tint: WidgetTint = .coral, compact: Bool = false, success: Bool = false) -> TaskEntry {
        let config = SelectFilterIntent()
        config.tint = tint; config.density = compact ? .compact : .comfortable
        config.showCounts = true; config.showDates = true; config.showFooter = true
        let date = Date()
        let format = DateFormatter(); format.dateFormat = "yyyy-MM-dd"
        let today = format.string(from: date)
        let yesterday = format.string(from: Calendar.current.date(byAdding: .day, value: -1, to: date)!)
        let tomorrow = format.string(from: Calendar.current.date(byAdding: .day, value: 1, to: date)!)
        let filter = SavedFilter(id: "preview", name: language.text("今日专注"), query: "today")
        let tasks = [TodoTask(id: "1", content: copy("把想法变成一个小作品", "Bring a small idea to life"), due: Due(date: yesterday), priority: 4),
                     TodoTask(id: "2", content: copy("留出一段专注时间", "Make time for deep work"), due: Due(date: today), priority: 3),
                     TodoTask(id: "3", content: copy("读完书桌上的那本书", "Finish the book on my desk"), due: Due(date: today)),
                     TodoTask(id: "4", content: copy("整理本周的灵感", "Collect this week’s ideas"), due: Due(date: today)),
                     TodoTask(id: "5", content: copy("给朋友回个消息", "Catch up with a friend"), due: Due(date: tomorrow)),
                     TodoTask(id: "6", content: copy("出去走走，看看夕阳", "Take a sunset walk"), due: Due(date: tomorrow)),
                     TodoTask(id: "7", content: copy("计划下一次周末旅行", "Plan a weekend away")),
                     TodoTask(id: "8", content: copy("为下周留一点空白", "Leave some room for next week"))]
        let snapshot = WidgetSnapshot(filter: filter, groups: [TaskGroup(id: 0, query: "today", tasks: success ? Array(tasks.dropFirst()) : tasks)],
                                      updated: date, timezone: TimeZone.current.identifier, generation: UUID())
        let feedback = success ? CompletionFeedback(date: date, filterIDs: ["preview"], succeeded: true, message: "已完成") : nil
        return TaskEntry(date: date, configuration: config, snapshot: snapshot, feedback: feedback, preview: true, language: language)
    }
    func widget(_ family: WidgetFamily, width: CGFloat, height: CGFloat, tint: WidgetTint = .coral, compact: Bool = false, success: Bool = false) -> some View {
        TaskWidgetView(entry: entry(tint: tint, compact: compact, success: success), previewFamily: family)
            .padding(16).frame(width: width, height: height)
            .background(WidgetSurface(tint: tint)).clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.7)))
            .shadow(color: .black.opacity(0.06), radius: 14, y: 7)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Glassist").font(.system(size: 33, weight: .bold, design: .rounded))
                    Text(copy("轻点查看 · 随手记录 · 完成一件小事", "Open. Capture. Get a little done.")).font(.system(size: 14)).foregroundStyle(.secondary)
                }
                Spacer()
                    Text(copy("0.4 / 界面预览", "0.4 / Design preview")).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 26) {
                VStack(alignment: .leading, spacing: 13) {
                    widget(.systemLarge, width: 338, height: 354)
                    Text(copy("舒适 · 珊瑚红", "Roomy · Coral")).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 16) {
                    widget(.systemMedium, width: 338, height: 158, tint: .ocean, compact: true)
                    HStack(spacing: 22) {
                        widget(.systemSmall, width: 158, height: 158, tint: .sage)
                        VStack(alignment: .leading, spacing: 12) {
                            Text(copy("按你的节奏", "Your own pace")).font(.system(size: 16, weight: .semibold))
                            Text(copy("四种强调色\n两种信息密度\n每个实例独立配置", "Four accent colors\nTwo layout densities\nYour own filters")).font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 8) {
                                ForEach([WidgetTint.coral, .ocean, .sage, .graphite], id: \.self) { tint in
                                    Circle().fill(tint.color).frame(width: 16, height: 16)
                                }
                            }
                        }
                    }
                    Text(copy("紧凑与小尺寸 · 界面使用示例任务", "Compact & small · Fictional sample tasks")).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 13) {
                CompletionMark(isOn: true, color: WidgetTint.sage.color)
                Text(copy("勾选即时反馈，成功后列表轻盈收拢。", "A satisfying check. A little more breathing room.")).font(.system(size: 13))
                Spacer()
                Text(copy("系统透明样式会使用 macOS 的玻璃背景", "Clear mode uses the system glass background")).font(.system(size: 10)).foregroundStyle(.secondary)
            }.padding(16).background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
        }.padding(34).frame(width: 800)
            .background(LinearGradient(colors: [Color(red: 0.94, green: 0.94, blue: 0.92), Color(red: 0.89, green: 0.92, blue: 0.93)], startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}
