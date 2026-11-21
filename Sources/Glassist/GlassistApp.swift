import SwiftUI
import AppKit
#if SWIFT_PACKAGE
import GlassistCore
#endif

@main struct GlassistApp: App {
    @StateObject private var store = AppStore()
    var body: some Scene {
        Window("Glassist", id: "settings") {
            SettingsView(store: store)
                .onOpenURL { ApplicationRouter.handle($0, store: store) }
        }
        .defaultSize(width: 560, height: 640)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

@MainActor enum ApplicationRouter {
    static func handle(_ url: URL, store: AppStore) {
        guard let route = WidgetRoute(url: url) else { return }
        if route == .settings {
            store.reloadLocal()
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first(where: { $0.canBecomeKey })?.makeKeyAndOrderFront(nil)
        } else { open(route, store: store) }
    }
    static func open(_ route: WidgetRoute, store: AppStore) {
        guard let url = route.todoistURL else { return }
        guard NSWorkspace.shared.urlForApplication(toOpen: url) != nil, NSWorkspace.shared.open(url) else {
            store.error = "未能打开 Todoist，请确认已安装 Mac 版 Todoist。"
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        NSApp.hide(nil)
    }
}
