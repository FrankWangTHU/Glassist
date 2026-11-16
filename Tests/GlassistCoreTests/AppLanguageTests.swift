import XCTest
@testable import GlassistCore

final class AppLanguageTests: XCTestCase {
    func testUIStringsAndCountsSwitchLanguages() {
        XCTAssertEqual(AppLanguage.chinese.text("过期"), "过期")
        XCTAssertEqual(AppLanguage.english.text("过期"), "Overdue")
        XCTAssertEqual(AppLanguage.english.format("还有 %d 项", 4), "4 more")
        XCTAssertEqual(AppLanguage.chinese.format("还有 %d 项", 4), "还有 4 项")
    }
    func testDateLabelsUseSelectedLanguageAndAccountTimeZone() {
        let zone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-11-17T10:00:00Z")!
        XCTAssertEqual(TaskDates.label(Due(date: "2026-11-17"), now: now, timeZone: zone, language: .english), "Today")
        XCTAssertEqual(TaskDates.label(Due(date: "2026-11-16"), now: now, timeZone: zone, language: .english), "Nov 16")
        XCTAssertEqual(TaskDates.label(Due(date: "2026-11-16"), now: now, timeZone: zone, language: .chinese), "11月16日")
    }
    func testCachedErrorParametersAreTranslated() {
        XCTAssertEqual(AppLanguage.english.message("Todoist 暂时不可用（503）。"), "Todoist is temporarily unavailable (503).")
        XCTAssertEqual(AppLanguage.english.message("请求过于频繁，约 60 秒后重试。"), "Too many requests. Try again in about 60 seconds.")
        XCTAssertEqual(AppLanguage.english.message("完成结果待核对，请在 Todoist 中查看。"), "Check the completion result in Todoist.")
    }
}
