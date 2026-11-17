import XCTest
@testable import GlassistCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private actor StubTransport: HTTPTransport {
    struct Reply: Sendable {
        var status = 200
        var body: String
        var headers: [String: String] = [:]
    }
    var replies: [Reply]
    var requests: [URLRequest] = []
    init(_ replies: [Reply]) { self.replies = replies }
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard !replies.isEmpty else { throw URLError(.badServerResponse) }
        let reply = replies.removeFirst()
        return (Data(reply.body.utf8), HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: reply.headers)!)
    }
}

final class GlassistCoreTests: XCTestCase {
    func testGroupedFiltersPreserveEscapedCommasAndQuotedNames() throws {
        XCTAssertEqual(try FilterQuery.groups(#"(today | overdue) & #Work, #Road\,map, search: "hello, world""#),
                       ["(today | overdue) & #Work", #"#Road\,map"#, #"search: "hello, world""#])
        XCTAssertEqual(try FilterQuery.groups("#John's list, today").count, 2)
        for invalid in ["", "today,", "(today", "today)", #"search: "unclosed"#] {
            XCTAssertThrowsError(try FilterQuery.groups(invalid))
        }
    }

    func testPaginationAndPerGroupOrder() async throws {
        let transport = StubTransport([
            .init(body: #"{"results":[{"id":"a","content":"A"}],"next_cursor":"page+2"}"#),
            .init(body: #"{"results":[{"id":"a","content":"A"},{"id":"b","content":"B"}],"next_cursor":null}"#),
            .init(body: #"{"results":[{"id":"b","content":"B"},{"id":"c","content":"C","checked":true}],"next_cursor":null}"#)
        ])
        let client = TodoistClient(token: "test-only", transport: transport)
        let groups = try await client.tasks(query: "today, overdue", language: "zh")
        XCTAssertEqual(groups.map { $0.tasks.map(\.id) }, [["a", "b"], ["b"]])
        XCTAssertEqual(TaskDates.uniqueTasks(groups).count, 2)
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 3)
        let params = URLComponents(url: requests[1].url!, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertEqual(params.first { $0.name == "cursor" }?.value, "page+2")
        XCTAssertEqual(params.first { $0.name == "lang" }?.value, "zh")
    }

    func testRepeatedCursorFailsRatherThanShowingTruncatedTasks() async throws {
        let reply = StubTransport.Reply(body: #"{"results":[],"next_cursor":"same"}"#)
        let client = TodoistClient(token: "test-only", transport: StubTransport([reply, reply]))
        do { _ = try await client.tasks(query: "today", language: "en"); XCTFail("Expected pagination failure") }
        catch APIError.repeatedCursor {} catch { XCTFail("Unexpected error \(error)") }
    }

    func testFullSyncThenDeltaRenamesAndDeletesFilters() async throws {
        let transport = StubTransport([
            .init(body: #"{"sync_token":"a+b","full_sync":true,"filters":[{"id":"1","name":"Old","query":"today"},{"id":"2","name":"Delete","query":"overdue"}],"user":{"lang":"zh","tz_info":{"timezone":"Asia/Shanghai"}}}"#),
            .init(body: #"{"sync_token":"next","full_sync":false,"filters":[{"id":"1","name":"New","query":"tomorrow"},{"id":"2","is_deleted":true}]}"#)
        ])
        let client = TodoistClient(token: "test-only", transport: transport)
        let (filters, account) = try await client.savedFilters()
        XCTAssertEqual(filters.map(\.name), ["New"])
        XCTAssertEqual(filters[0].query, "tomorrow")
        XCTAssertEqual(account.timeZone.identifier, "Asia/Shanghai")
        let requests = await transport.requests
        XCTAssertTrue(String(data: requests[1].httpBody!, encoding: .utf8)!.contains("a%2Bb"))
    }

    func testRateLimitHonorsCooldownAndDoesNotRetryCompletion() async throws {
        let transport = StubTransport([.init(status: 429, body: "{}", headers: ["Retry-After": "120"])])
        let client = TodoistClient(token: "test-only", transport: transport)
        for _ in 0..<2 {
            do { try await client.closeTask(id: "abc123"); XCTFail("Expected rate limit") }
            catch APIError.rateLimited(let delay) { XCTAssertGreaterThan(delay, 100) }
        }
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1)
    }

    func testCloseAcceptsDocumentedNullResponseAndUsesPOST() async throws {
        let transport = StubTransport([.init(body: "null")])
        try await TodoistClient(token: "test-only", transport: transport).closeTask(id: "abc123")
        let requests = await transport.requests
        XCTAssertEqual(requests[0].httpMethod, "POST")
        XCTAssertEqual(requests[0].url!.path, "/api/v1/tasks/abc123/close")
    }

    func testMalformedRetryHeadersCannotCrashErrorDisplay() async throws {
        for header in ["NaN", "Infinity", "1e100", "invalid", "-10"] {
            let transport = StubTransport([.init(status: 429, body: "{}", headers: ["Retry-After": header])])
            let client = TodoistClient(token: "test-only", transport: transport)
            do { try await client.closeTask(id: "abc123"); XCTFail("Expected rate limit") }
            catch APIError.rateLimited(let delay) {
                XCTAssertTrue(delay.isFinite)
                XCTAssertGreaterThanOrEqual(delay, 1)
                XCTAssertLessThanOrEqual(delay, 60)
                XCTAssertFalse(APIError.rateLimited(delay).localizedDescription.isEmpty)
            }
            let requests = await transport.requests
            XCTAssertEqual(requests.count, 1)
        }
    }

    func testCompletionRejectsPathInjectionBeforeNetworkRequest() async throws {
        let transport = StubTransport([])
        let client = TodoistClient(token: "test-only", transport: transport)
        for id in ["", "../projects", "a/close", "%2F", "a?token=x", "a#fragment"] {
            do { try await client.closeTask(id: id); XCTFail("Expected invalid task ID") }
            catch APIError.invalidResponse {}
        }
        let requests = await transport.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testUnauthorizedIsExplicit() async throws {
        let client = TodoistClient(token: "test-only", transport: StubTransport([.init(status: 401, body: "{}")]))
        do { _ = try await client.savedFilters(); XCTFail("Expected auth failure") }
        catch APIError.unauthorized {} catch { XCTFail("Unexpected error \(error)") }
    }

    func testAllDayFloatingAndFixedDatesInAccountTimezone() {
        let zone = TimeZone(identifier: "Asia/Shanghai")!
        let now = ISO8601DateFormatter().date(from: "2026-11-16T14:00:00Z")!
        XCTAssertEqual(TaskDates.bucket(Due(date: "2026-11-15"), now: now, timeZone: zone), .overdue)
        XCTAssertEqual(TaskDates.bucket(Due(date: "2026-11-16"), now: now, timeZone: zone), .today)
        XCTAssertEqual(TaskDates.bucket(Due(date: "2026-11-16T09:00:00.000000"), now: now, timeZone: zone), .today)
        XCTAssertEqual(TaskDates.bucket(Due(date: "2026-11-15T18:00:00Z", timezone: "UTC"), now: now, timeZone: zone), .today)
        XCTAssertEqual(TaskDates.bucket(Due(date: "2026-11-16T18:00:00Z", timezone: "UTC"), now: now, timeZone: zone), .later)
        XCTAssertEqual(TaskDates.bucket(nil, now: now, timeZone: zone), .none)
    }

    func testFailedSecondPageDoesNotReturnPartialSuccess() async throws {
        let transport = StubTransport([
            .init(body: #"{"results":[{"id":"a","content":"A"}],"next_cursor":"second"}"#),
            .init(status: 503, body: "{}")
        ])
        let client = TodoistClient(token: "test-only", transport: transport)
        do { _ = try await client.tasks(query: "today", language: "en"); XCTFail("Expected page failure") }
        catch APIError.http(let code) { XCTAssertEqual(code, 503) }
    }
}
