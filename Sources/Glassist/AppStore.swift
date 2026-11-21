import SwiftUI
import WidgetKit
#if SWIFT_PACKAGE
import GlassistCore
#endif

@MainActor final class AppStore: ObservableObject {
    @Published var filters: [SavedFilter] = []
    @Published var connected = false
    @Published var busy = false
    @Published var error: String?
    @Published var signingReady = false
    @Published var updated: Date?
    @Published var language: AppLanguage = .system
    init() { reloadLocal(); WidgetCenter.shared.reloadAllTimelines() }
    func reloadLocal() {
        signingReady = (try? WidgetStorage()) != nil
        language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "interfaceLanguage") ?? "") ?? .system
        if let db = try? WidgetStorage().read() {
            filters = db.filters; connected = db.connected
            language = db.interfaceLanguage.flatMap(AppLanguage.init(rawValue:)) ?? language
        }
    }
    func setLanguage(_ value: AppLanguage) {
        do {
            try WidgetStorage().transaction { $0.interfaceLanguage = value.rawValue }
            UserDefaults.standard.set(value.rawValue, forKey: "interfaceLanguage")
            language = value; error = nil
            WidgetCenter.shared.reloadAllTimelines()
        } catch { self.error = WidgetService.message(error) }
    }
    func connect(_ token: String) async {
        guard !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            try await WidgetService.connect(token.trimmingCharacters(in: .whitespacesAndNewlines))
            reloadLocal(); updated = Date(); WidgetCenter.shared.reloadAllTimelines()
        } catch { self.error = WidgetService.message(error) }
    }
    func refresh() async {
        guard !busy, connected else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            filters = try await WidgetService.catalog()
            WidgetCenter.shared.reloadAllTimelines(); updated = Date()
        } catch { self.error = WidgetService.message(error) }
    }
    func disconnect() {
        guard !busy else { return }
        do { try WidgetService.disconnect(); reloadLocal(); WidgetCenter.shared.reloadAllTimelines() }
        catch { self.error = WidgetService.message(error) }
    }
}
