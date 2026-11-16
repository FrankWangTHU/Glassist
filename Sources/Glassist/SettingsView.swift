import SwiftUI
import AppKit
#if SWIFT_PACKAGE
import GlassistCore
#endif

struct SettingsView: View {
    @ObservedObject var store: AppStore
    @State private var token = ""
    @State private var changingAccount = false
    private let accent = Color(red: 0.87, green: 0.25, blue: 0.22)
    private func t(_ key: String) -> String { store.language.text(key) }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 25, weight: .medium)).foregroundStyle(accent)
                    .frame(width: 54, height: 54).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 5) {
                    Text("Glassist").font(.system(size: 27, weight: .bold, design: .rounded))
                    Text(t("少一点切换，多一点专注")).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("0.3").font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary).padding(7).background(.thinMaterial, in: Capsule())
            }.padding(.horizontal, 26).padding(.top, 34).padding(.bottom, 22)
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    accountCard
                    card {
                        HStack {
                            Label(t("界面语言"), systemImage: "globe").font(.headline)
                            Spacer()
                            Picker(t("界面语言"), selection: Binding(get: { store.language }, set: { store.setLanguage($0) })) {
                                ForEach(AppLanguage.allCases, id: \.self) { value in Text(value.nativeName).tag(value) }
                            }.labelsHidden().frame(width: 190)
                        }
                        Text(t("小组件默认跟随此设置，也可以单独选择语言。"))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    card {
                        Label(t("随手记录，轻点完成"), systemImage: "cursorarrow.click.2").font(.headline)
                        HStack(spacing: 10) {
                            actionTile("打开 Todoist", subtitle: "回到任务列表", symbol: "arrow.up.right", route: .home)
                            actionTile("新建任务", subtitle: "想到就记下来", symbol: "plus", route: .addTask)
                        }
                        Text(t("小组件标题打开对应过滤器；点任务文字查看详情，点圆圈完成。循环任务会在 Todoist 中打开。"))
                            .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    card {
                        Label(t("让每一块都适合你"), systemImage: "slider.horizontal.3").font(.headline)
                        Text(t("右键小组件 → 编辑 Glassist"))
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(accent)
                        HStack(spacing: 7) {
                            feature("独立过滤器"); feature("舒适 / 紧凑"); feature("四种强调色"); feature("标题与日期")
                        }
                        Text(t("在右上角日期 → 编辑小组件中添加。小、中、大三种尺寸，可以添加多个实例。"))
                            .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Divider().opacity(0.45)
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(t("融入系统玻璃外观")).font(.system(size: 12, weight: .medium))
                                Text(t("透明与着色跟随系统的图标和小组件样式。"))
                                    .font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(t("系统外观")) {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Appearance-Settings.extension")!)
                            }.controlSize(.small)
                        }
                    }
                }.padding(.horizontal, 26).padding(.bottom, 16)
            }
            HStack {
                Text(t("自动同步 · 更新时机由 macOS 安排")).font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Button(t("关闭")) { NSApp.keyWindow?.close() }.controlSize(.small)
                Button(t("退出")) { NSApp.terminate(nil) }.controlSize(.small).keyboardShortcut("q")
            }.padding(.horizontal, 26).padding(.vertical, 14)
        }.frame(width: 610, height: 700)
            .background(WindowMaterial().ignoresSafeArea())
            .tint(accent)
            .environment(\.locale, store.language.locale)
    }

    private var accountCard: some View {
        card {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(t("Todoist 账号")).font(.headline)
                    Label(store.connected ? store.language.format("已连接 · %d 个过滤器", store.filters.count) : t("连接后，读取你的自定义过滤器"),
                          systemImage: store.connected ? "checkmark.circle.fill" : "link")
                        .font(.system(size: 12)).foregroundStyle(store.connected ? .green : .secondary)
                }
                Spacer()
                if store.connected {
                    Button { Task { await store.refresh() } } label: {
                        Label(t(store.busy ? "正在刷新" : "刷新"), systemImage: "arrow.clockwise")
                    }.disabled(store.busy).controlSize(.small)
                }
            }
            if !store.connected || changingAccount {
                SecureField(t("在这里粘贴 Todoist API Token"), text: $token).textFieldStyle(.roundedBorder)
                    .onSubmit { connect() }
                HStack {
                    Button(t(store.busy ? "正在连接…" : "连接 Todoist")) { connect() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!store.signingReady || store.busy || token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Link(t("获取 Token ↗"), destination: URL(string: "https://app.todoist.com/app/settings/integrations/developer")!)
                        .font(.system(size: 12))
                    Spacer()
                }
                Text(t("仅在本机钥匙串保存。请勿在聊天或截图中分享 Token。"))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            if !store.signingReady {
                Text(t("此版本尚未配置共享签名，请使用本机安装版本。"))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if let error = store.error {
                Label(store.language.message(error), systemImage: "exclamationmark.circle").font(.system(size: 11)).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if store.connected {
                HStack {
                    Button(t(changingAccount ? "收起" : "更换账号")) { changingAccount.toggle(); token = "" }
                    Spacer()
                    Button(t("断开连接"), role: .destructive) { store.disconnect() }.disabled(store.busy)
                }.buttonStyle(.link).font(.system(size: 10))
            }
        }
    }
    private func connect() {
        guard store.signingReady, !store.busy, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let value = token; token = ""
        Task { await store.connect(value); if store.connected { changingAccount = false } }
    }
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 13, content: content)
            .frame(maxWidth: .infinity, alignment: .leading).padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.24), lineWidth: 0.7))
    }
    private func feature(_ name: String) -> some View {
        Text(t(name)).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            .padding(.horizontal, 9).padding(.vertical, 6).background(.thinMaterial, in: Capsule())
    }
    private func actionTile(_ title: String, subtitle: String, symbol: String, route: WidgetRoute) -> some View {
        Button { ApplicationRouter.open(route, store: store) } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(accent)
                    .frame(width: 31, height: 31).background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text(t(title)).font(.system(size: 12, weight: .semibold))
                    Text(t(subtitle)).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }.padding(11).frame(maxWidth: .infinity).contentShape(Rectangle())
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }
}

private struct WindowMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = GlassBackground()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
    private class GlassBackground: NSVisualEffectView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.isOpaque = false
            window?.backgroundColor = .clear
        }
    }
}
