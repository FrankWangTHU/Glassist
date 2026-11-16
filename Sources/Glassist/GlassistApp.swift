import AppKit
import SwiftUI

final class DesktopPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: AppStore!
    private var panels: [DesktopPanel] = []
    private var settings: NSWindow?
    private var status: NSStatusItem?
    private var hidden = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = AppStore()
        store.onAppearanceChange = { [weak self] in self?.applyAppearance() }
        store.onShowSettings = { [weak self] in self?.showSettings() }
        configureMenu()
        createPanels()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(wake), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        store.refresh()
        if store.demo { showSettings() }
    }

    private func configureMenu() {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status?.button?.image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "Glassist")
        let menu = NSMenu()
        for (title, action, key) in [
            ("显示 / 隐藏面板", #selector(togglePanels), ""),
            ("编辑面板与账号…", #selector(showSettings), ","),
            ("立即同步", #selector(refresh), "r"),
            ("恢复默认位置", #selector(resetPositions), ""),
            ("退出 Glassist", #selector(quit), "q")
        ] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = self; menu.addItem(item)
        }
        status?.menu = menu
    }

    private func createPanels() {
        for index in 0..<2 {
            let panel = DesktopPanel(contentRect: NSRect(x: 0, y: 0, width: 350, height: 450),
                                     styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.title = index == 0 ? "Glassist 左侧" : "Glassist 右侧"
            panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
            panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            panel.contentView = NSHostingView(rootView: PanelView(store: store, index: index))
            panel.setFrameAutosaveName("Glassist-Panel-\(index)")
            panels.append(panel)
            if !panel.setFrameUsingName("Glassist-Panel-\(index)") { position(panel, index: index) }
        }
        applyAppearance()
        rescueOffscreenPanels()
        panels.forEach { $0.orderFrontRegardless() }
    }

    private func applyAppearance() {
        for (index, panel) in panels.enumerated() {
            let preference = store.preferences.panels[index]
            let top = panel.frame.maxY
            panel.setContentSize(NSSize(width: preference.width, height: preference.height))
            panel.setFrameOrigin(NSPoint(x: panel.frame.minX, y: top - panel.frame.height))
            panel.level = store.preferences.floating ? .floating : NSWindow.Level(rawValue: CGWindowLevelForKey(.desktopIconWindow) + 1)
            panel.isMovableByWindowBackground = !store.preferences.locked
            panel.appearance = store.preferences.appearance == "system" ? nil : NSAppearance(named: store.preferences.appearance == "dark" ? .darkAqua : .aqua)
        }
    }

    private func position(_ panel: NSPanel, index: Int) {
        guard let screen = NSScreen.main else { return }
        let area = screen.visibleFrame
        let x = index == 0 ? area.minX + 30 : area.maxX - panel.frame.width - 30
        panel.setFrameOrigin(NSPoint(x: x, y: area.maxY - panel.frame.height - 40))
    }
    private func rescueOffscreenPanels() {
        for (index, panel) in panels.enumerated() {
            if !NSScreen.screens.contains(where: { $0.visibleFrame.intersection(panel.frame).width > 100 && $0.visibleFrame.intersection(panel.frame).height > 80 }) {
                position(panel, index: index)
            }
        }
    }
    @objc private func resetPositions() { for (index, panel) in panels.enumerated() { position(panel, index: index) } }
    @objc private func screenChanged() { rescueOffscreenPanels() }
    @objc private func refresh() { store.refresh() }
    @objc private func wake() { rescueOffscreenPanels(); store.refresh() }
    @objc private func togglePanels() {
        hidden.toggle()
        panels.forEach { if hidden { $0.orderOut(nil) } else { $0.orderFrontRegardless() } }
    }
    @objc private func showSettings() {
        if settings == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 578, height: 598),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Glassist 设置"
            window.contentView = NSHostingView(rootView: SettingsView(store: store))
            window.isReleasedWhenClosed = false; window.center()
            settings = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settings?.makeKeyAndOrderFront(nil)
    }
    @objc private func quit() { NSApp.terminate(nil) }
}

@main struct GlassistMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
