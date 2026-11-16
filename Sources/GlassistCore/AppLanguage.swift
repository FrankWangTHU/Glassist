import Foundation

public enum AppLanguage: String, CaseIterable, Codable, Sendable {
    case system, chinese, english
    public var isChinese: Bool {
        self == .chinese || (self == .system && (Locale.preferredLanguages.first ?? "en").hasPrefix("zh"))
    }
    public var locale: Locale { Locale(identifier: isChinese ? "zh_Hans_CN" : "en_US") }
    public var nativeName: String {
        switch self { case .system: return "跟随系统 / System"; case .chinese: return "简体中文"; case .english: return "English" }
    }
    private var resources: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #elseif DESIGN_PREVIEW
        return ProcessInfo.processInfo.environment["GLASSIST_PREVIEW_RESOURCES"].flatMap(Bundle.init(path:)) ?? .main
        #else
        return .main
        #endif
    }
    public func text(_ key: String) -> String {
        guard let path = resources.path(forResource: isChinese ? "zh-Hans" : "en", ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
    public func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
    }
    public func message(_ canonical: String) -> String {
        // Cached errors use stable Chinese source strings; format associated values in the selected language.
        if !isChinese {
            let digits = canonical.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
            if let first = digits.first, let number = Int(first) {
                if canonical.hasPrefix("Todoist 暂时不可用") { return format("Todoist 暂时不可用（%d）。", number) }
                if canonical.hasPrefix("请求过于频繁") { return format("请求过于频繁，约 %d 秒后重试。", number) }
                if canonical.hasPrefix("无法访问共享钥匙串") { return text("无法访问共享钥匙串，请检查签名或解锁 Mac。") }
            }
        }
        return text(canonical)
    }
}
