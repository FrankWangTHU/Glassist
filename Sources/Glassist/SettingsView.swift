import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var store: AppStore
    @State private var token = ""
    @State private var editingPanel = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Glassist").font(.system(size: 28, weight: .semibold, design: .rounded))
                Text("让待办安静地留在桌面上").foregroundStyle(.secondary)
            }
            TabView {
                appearance.tabItem { Label("面板", systemImage: "square.split.2x1") }
                connection.tabItem { Label("Todoist", systemImage: "link") }
            }
        }.padding(24).frame(width: 530, height: 550)
    }
    private var appearance: some View {
        Form {
            Section {
                Picker("编辑面板", selection: $editingPanel) {
                    Text("左侧").tag(0); Text("右侧").tag(1)
                }.pickerStyle(.segmented)
                Picker("已有过滤器", selection: Binding(get: { store.selection(editingPanel) }, set: { store.select($0, panel: editingPanel) })) {
                    Text("请选择…").tag("")
                    ForEach(store.filters) { Text($0.name).tag($0.id) }
                }
                TextField("自定义标题", text: $store.preferences.panels[editingPanel].title, prompt: Text("留空使用过滤器名称"))
                Slider(value: $store.preferences.panels[editingPanel].width, in: 300...520, step: 10) {
                    Text("宽度 \(Int(store.preferences.panels[editingPanel].width))")
                }
                Slider(value: $store.preferences.panels[editingPanel].height, in: 360...760, step: 10) {
                    Text("高度 \(Int(store.preferences.panels[editingPanel].height))")
                }
                Slider(value: $store.preferences.panels[editingPanel].fontSize, in: 12...22, step: 1) {
                    Text("字号 \(Int(store.preferences.panels[editingPanel].fontSize))")
                }
                Slider(value: $store.preferences.panels[editingPanel].tint, in: 0...0.8) { Text("玻璃底色浓度") }
            }
            Section {
                Picker("外观", selection: $store.preferences.appearance) {
                    Text("跟随系统").tag("system"); Text("浅色").tag("light"); Text("深色").tag("dark")
                }
                Picker("自动刷新", selection: $store.preferences.refreshSeconds) {
                    Text("1 分钟").tag(60.0); Text("2 分钟").tag(120.0); Text("5 分钟").tag(300.0)
                }
                Toggle("置顶显示", isOn: $store.preferences.floating)
                Toggle("锁定面板位置", isOn: $store.preferences.locked)
                Text("关闭置顶时，面板位于普通窗口下方。拖动面板顶部空白处调整位置；菜单栏可恢复默认位置。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }
    private var connection: some View {
        Form {
            Section("账号连接") {
                Label(store.demo ? "尚未连接 · 正在显示演示任务" : "已连接 Todoist", systemImage: store.demo ? "circle.dashed" : "checkmark.circle.fill")
                SecureField("API token", text: $token)
                Text("只在此窗口输入。验证后存入这台 Mac 的钥匙串，不写入项目、聊天或配置文件。")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(store.connecting ? "正在验证…" : "连接并读取过滤器") {
                        let entered = token
                        token = ""
                        Task { _ = await store.connect(token: entered) }
                    }.disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.connecting || !store.completing.isEmpty)
                    Link("打开 Todoist 集成设置", destination: URL(string: "https://app.todoist.com/app/settings/integrations/developer")!)
                }
                if let error = store.accountError { Text(error).foregroundStyle(.red).font(.caption) }
                if !store.demo {
                    Button("断开连接并移除本机凭据", role: .destructive) { token = ""; store.disconnect() }
                        .disabled(store.connecting || !store.completing.isEmpty)
                }
            }
            Section("过滤器与同步") {
                Text("直接选择你在 Todoist 中保存的个人过滤器。要编辑查询规则，请在 Todoist 中修改，Glassist 会在下次同步时读取。")
                Button("在 Todoist 中编辑过滤器") { NSWorkspace.shared.open(URL(string: "todoist://filters-labels")!) }
                Text("过期与今日统计仅针对当前面板，以 Todoist 账号时区的日期计算。同一任务出现在多个分组时，统计只计一次。任务数据仅保留在内存中，离线时显示本次运行的上次结果。")
                    .font(.caption).foregroundStyle(.secondary)
                Text("第一版支持个人过滤器；团队工作区过滤器和开机启动留待后续版本。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }
}
