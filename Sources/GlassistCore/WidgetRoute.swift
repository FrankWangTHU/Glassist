import Foundation

/// WidgetKit opens the containing app. Only these explicit routes may be forwarded to Todoist.
public enum WidgetRoute: Equatable, Sendable {
    case settings, home, addTask, task(String), filter(String)

    public var url: URL {
        var parts = URLComponents()
        parts.scheme = "glassist"
        switch self {
        case .settings: parts.host = "setup"
        case .home: parts.host = "home"
        case .addTask: parts.host = "add"
        case .task(let id): parts.host = "task"; parts.queryItems = [URLQueryItem(name: "id", value: id)]
        case .filter(let id): parts.host = "filter"; parts.queryItems = [URLQueryItem(name: "id", value: id)]
        }
        return parts.url!
    }

    public init?(url: URL) {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              ["glassist", "todoist"].contains(parts.scheme?.lowercased() ?? ""),
              parts.user == nil, parts.password == nil, parts.port == nil,
              parts.path.isEmpty, parts.fragment == nil else { return nil }
        let items = parts.queryItems ?? []
        let host = parts.host?.lowercased() ?? ""
        switch host {
        case "setup":
            guard parts.scheme == "glassist", items.isEmpty else { return nil }; self = .settings
        case "", "home":
            guard items.isEmpty else { return nil }; self = .home
        case "add", "openquickadd":
            guard items.isEmpty else { return nil }; self = .addTask
        case "task", "filter":
            guard items.count == 1, items[0].name == "id", let id = items[0].value,
                  !id.isEmpty, id.count < 200,
                  id.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" }) else { return nil }
            self = host == "task" ? .task(id) : .filter(id)
        default: return nil
        }
    }

    public var todoistURL: URL? {
        guard self != .settings else { return nil }
        var parts = URLComponents(); parts.scheme = "todoist"
        switch self {
        case .settings: return nil
        case .home: parts.host = "today"
        // Desktop Quick Add differs from the mobile addtask URL and never submits automatically.
        case .addTask: parts.host = "openquickadd"
        case .task(let id): parts.host = "task"; parts.queryItems = [URLQueryItem(name: "id", value: id)]
        case .filter(let id): parts.host = "filter"; parts.queryItems = [URLQueryItem(name: "id", value: id)]
        }
        return parts.url
    }
}
