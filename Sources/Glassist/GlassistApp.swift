import SwiftUI
import AppKit

@main struct GlassistApp: App {
    @StateObject private var store = AppStore()
    var body: some Scene {
        Window("Glassist 设置", id: "settings") {
            SettingsView(store: store)
                .onOpenURL { _ in NSApp.activate(ignoringOtherApps: true) }
        }
        .defaultSize(width: 560, height: 640)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
