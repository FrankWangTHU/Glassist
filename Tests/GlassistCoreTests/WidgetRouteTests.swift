import XCTest
@testable import GlassistCore

final class WidgetRouteTests: XCTestCase {
    func testEveryWidgetDestinationRoundTrips() {
        for route: WidgetRoute in [.settings, .home, .addTask, .task("6Xabc42"), .filter("filter-123")] {
            XCTAssertEqual(WidgetRoute(url: route.url), route)
        }
    }
    func testQuickAddUsesDesktopURLWithoutSubmittingATask() {
        XCTAssertEqual(WidgetRoute.addTask.todoistURL?.absoluteString, "todoist://openquickadd")
        XCTAssertNil(WidgetRoute.settings.todoistURL)
        XCTAssertEqual(WidgetRoute.filter("abc123").todoistURL?.absoluteString, "todoist://filter?id=abc123")
    }
    func testExistingTaskLinksRemainSupported() {
        XCTAssertEqual(WidgetRoute(url: URL(string: "todoist://task?id=6Xabc42")!), .task("6Xabc42"))
    }
    func testRoutesRejectArbitraryForwardingAndMalformedIDs() {
        for input in ["https://example.com", "glassist://add?url=file:///private",
                      "glassist://home?anything=1", "glassist://task?id=1&id=2",
                      "glassist://task?id=a%26content%3Dother", "glassist://task?id=",
                      "glassist://task/path?id=1", "glassist://user:password@task?id=1"] {
            XCTAssertNil(WidgetRoute(url: URL(string: input)!), input)
        }
    }
}
