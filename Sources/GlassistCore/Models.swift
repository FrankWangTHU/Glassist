import Foundation

public struct SavedFilter: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public var name: String
    public var query: String
    public var itemOrder: Int?
    public var orderKey: String?
    public var isDeleted: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, query
        case itemOrder = "item_order", orderKey = "order_key", isDeleted = "is_deleted"
    }
    public init(id: String, name: String, query: String) {
        self.id = id; self.name = name; self.query = query
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        query = try c.decodeIfPresent(String.self, forKey: .query) ?? ""
        itemOrder = try c.decodeIfPresent(Int.self, forKey: .itemOrder)
        orderKey = try c.decodeIfPresent(String.self, forKey: .orderKey)
        isDeleted = try c.decodeIfPresent(Bool.self, forKey: .isDeleted)
    }
}

public struct TodoTask: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public var content: String
    public var priority: Int?
    public var due: Due?
    public var checked: Bool?
    public var isDeleted: Bool?
    enum CodingKeys: String, CodingKey {
        // Ignore descriptions and other fields that widgets do not display.
        // Decoding and rewriting a legacy cache also removes these fields.
        case id, content, priority, due, checked
        case isDeleted = "is_deleted"
    }
    public init(id: String, content: String, due: Due? = nil, priority: Int = 1) {
        self.id = id; self.content = content; self.due = due; self.priority = priority
    }
}

public struct Due: Codable, Sendable, Equatable {
    public var date: String
    public var timezone: String?
    public var isRecurring: Bool?
    enum CodingKeys: String, CodingKey {
        case date, timezone
        case isRecurring = "is_recurring"
    }
    public init(date: String, timezone: String? = nil, isRecurring: Bool = false) {
        self.date = date; self.timezone = timezone; self.isRecurring = isRecurring
    }
}

public struct TaskGroup: Codable, Identifiable, Sendable, Equatable {
    public let id: Int
    public let query: String
    public var tasks: [TodoTask]
    public init(id: Int, query: String, tasks: [TodoTask]) {
        self.id = id; self.query = query; self.tasks = tasks
    }
}

public struct AccountContext: Sendable {
    public let language: String
    public let timeZone: TimeZone
    public init(language: String = "en", timeZone: TimeZone = .current) {
        self.language = language; self.timeZone = timeZone
    }
}

public enum DueBucket { case overdue, today, later, none }

public enum TaskDates {
    public static func parsed(_ due: Due, timeZone: TimeZone) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let value = iso.date(from: due.date) { return value }
        iso.formatOptions = [.withInternetDateTime]
        if let value = iso.date(from: due.date) { return value }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.isLenient = false
        for format in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
            formatter.dateFormat = format
            if let value = formatter.date(from: due.date) { return value }
        }
        return nil
    }

    // Counts describe calendar days in the Todoist account's timezone, not time-of-day lateness.
    public static func bucket(_ due: Due?, now: Date = Date(), timeZone: TimeZone = .current) -> DueBucket {
        guard let due, let date = parsed(due, timeZone: timeZone) else { return .none }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let day = calendar.startOfDay(for: date), today = calendar.startOfDay(for: now)
        if day < today { return .overdue }
        if day == today { return .today }
        return .later
    }

    public static func label(_ due: Due?, now: Date = Date(), timeZone: TimeZone = .current, language: AppLanguage = .chinese) -> String {
        guard let due, let date = parsed(due, timeZone: timeZone) else { return language.text("无日期") }
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.timeZone = timeZone
        let today = bucket(due, now: now, timeZone: timeZone) == .today
        formatter.dateFormat = today ? "HH:mm" : (due.date.contains("T") ? (language.isChinese ? "M月d日 HH:mm" : "MMM d HH:mm") : (language.isChinese ? "M月d日" : "MMM d"))
        let label = today ? (due.date.contains("T") ? language.text("今天") + " " + formatter.string(from: date) : language.text("今天")) : formatter.string(from: date)
        return label + (due.isRecurring == true ? " ↻" : "")
    }

    public static func uniqueTasks(_ groups: [TaskGroup]) -> [TodoTask] {
        var seen = Set<String>()
        return groups.flatMap(\.tasks).filter { seen.insert($0.id).inserted }
    }
}
