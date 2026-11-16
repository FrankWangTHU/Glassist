import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var store: AppStore
    @State private var token = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "square.grid.2x2").font(.largeTitle).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Glassist").font(.title.bold())
                    Text("你的过滤器，融入系统小组件").foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(.horizontal, 20).padding(.top, 20)
            Form {
                Section("添加到通知中心或桌面") {
                    Text("1. 点击屏幕右上角日期，展开通知中心。\n2. 点击底部“编辑小组件”，搜索 Glassist。\n3. 选择小、中或大尺寸并添加。\n4. 右键小组件 → 编辑 Glassist，选择已有过滤器。")
                        .fixedSize(horizontal: false, vertical: true)
                    Text("可以添加两个或更多实例，分别选择过滤器。玻璃、圆角与着色由 macOS 控制。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !store.signingReady {
                    Section("此构建尚未配置开发签名") {
                        Text("代码已包含系统小组件。连接账号前，需要在 Xcode 为主应用与扩展配置相同的签名团队、App Groups 和 Keychain Sharing，然后安装签名版本。")
                            .font(.callout)
                        Link("查看本机安装说明", destination: URL(string: "https://github.com/FrankWangTHU/Glassist/blob/main/docs/INSTALL.md")!)
                    }
                }
                Section("Todoist 账号") {
                    Label(store.connected ? "已连接" : "尚未连接", systemImage: store.connected ? "checkmark.circle.fill" : "link")
                    SecureField("在本机粘贴 API token", text: $token)
                    HStack {
                        Button(store.busy ? "正在连接…" : "连接并读取过滤器") {
                            let value = token; token = ""
                            Task { await store.connect(value) }
                        }.disabled(!store.signingReady || store.busy || token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Link("获取 Token", destination: URL(string: "https://app.todoist.com/app/settings/integrations/developer")!)
                    }
                    Text("Token 仅保存在本机共享钥匙串，由 Glassist 与其小组件使用。")
                        .font(.caption).foregroundStyle(.secondary)
                    if let error = store.error { Text(error).foregroundStyle(.red).font(.caption) }
                    if store.connected {
                        HStack {
                            Button("刷新过滤器和小组件") { Task { await store.refresh() } }.disabled(store.busy)
                            Button("断开连接", role: .destructive) { store.disconnect() }.disabled(store.busy)
                        }
                        Text("已读取 \(store.filters.count) 个个人过滤器").font(.caption)
                    }
                }
                Section("更新与交互") {
                    Text("刷新时间由 macOS 调度；退出设置应用后，小组件仍可自行获取任务。普通任务可直接完成；循环任务点击后在 Todoist 中处理。离线显示上次同步时间。")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("关闭此窗口不会留下悬浮面板。移除小组件请在系统小组件上右键操作。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.formStyle(.grouped)
            HStack {
                Spacer()
                Button("关闭设置") { NSApp.keyWindow?.close() }
                Button("退出 Glassist") { NSApp.terminate(nil) }.keyboardShortcut("q")
            }.padding([.horizontal, .bottom], 20)
        }.frame(width: 560, height: 680)
    }
}
