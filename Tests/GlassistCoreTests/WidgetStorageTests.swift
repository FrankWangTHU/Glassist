import XCTest
@testable import GlassistCore

final class WidgetStorageTests: XCTestCase {
    var directory: URL!
    var storage: WidgetStorage!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        storage = try WidgetStorage(directory: directory)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }
    func sample(generation: UUID) -> WidgetSnapshot {
        WidgetSnapshot(filter: SavedFilter(id: "filter", name: "Today", query: "today"),
                       groups: [TaskGroup(id: 0, query: "today", tasks: [TodoTask(id: "task1", content: "Example")])],
                       updated: Date(), timezone: "Asia/Shanghai", generation: generation)
    }
    func testOldAccountResponseCannotRestorePrivateDataAfterDisconnect() throws {
        let generation = try storage.transaction { state in state.connected = true; return state.generation }
        try storage.save(sample(generation: generation))
        try storage.transaction { $0 = WidgetDatabase() }
        XCTAssertThrowsError(try storage.save(sample(generation: generation)))
        XCTAssertTrue(try storage.read().snapshots.isEmpty)
    }
    func testConfirmedCompletionSurvivesStaleNetworkResponse() throws {
        let generation = try storage.transaction { state in
            state.connected = true; state.completionLocks["task1"] = "done"; return state.generation
        }
        try storage.save(sample(generation: generation))
        XCTAssertEqual(try storage.read().snapshots["filter"]?.tasks.count, 0)
    }
    func testConcurrentTransactionsDoNotLoseUpdates() throws {
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "storage-test", attributes: .concurrent)
        let url = directory!
        for i in 0..<20 {
            group.enter()
            queue.async {
                defer { group.leave() }
                do { try WidgetStorage(directory: url).transaction { $0.completionLocks[String(i)] = "done" } }
                catch { XCTFail("Transaction failed") }
            }
        }
        group.wait()
        XCTAssertEqual(try storage.read().completionLocks.count, 20)
    }
    func testCacheRoundtripPreservesGroupedFiltersAndTimestamp() throws {
        let generation = try storage.transaction { state in state.connected = true; return state.generation }
        let original = sample(generation: generation)
        try storage.save(original)
        let loaded = try XCTUnwrap(storage.read().snapshots["filter"])
        XCTAssertEqual(loaded.groups, original.groups)
        XCTAssertEqual(loaded.updated, original.updated)
        XCTAssertEqual(loaded.timezone, "Asia/Shanghai")
    }
    func testCompletionRemovesTaskFromEveryFilterAndScopesFeedback() throws {
        let generation = try storage.transaction { state in state.connected = true; return state.generation }
        let first = sample(generation: generation)
        var second = first; second.filter = SavedFilter(id: "second", name: "Other", query: "all")
        try storage.save(first); try storage.save(second)
        let now = Date()
        try storage.confirmCompletion(id: "task1", generation: generation, now: now)
        let result = try storage.read()
        XCTAssertTrue(result.snapshots.values.allSatisfy { $0.tasks.isEmpty })
        XCTAssertEqual(result.completionLocks["task1"], "done")
        XCTAssertEqual(Set(result.feedback?.filterIDs ?? []), ["filter", "second"])
        XCTAssertEqual(result.feedback?.isRecent(for: "filter", now: now.addingTimeInterval(2)), true)
        XCTAssertEqual(result.feedback?.isRecent(for: "unrelated", now: now), false)
        XCTAssertEqual(result.feedback?.isRecent(for: "filter", now: now.addingTimeInterval(7)), false)
        try storage.save(first)
        XCTAssertTrue(try storage.read().snapshots["filter"]!.tasks.isEmpty)
    }
    func testFailedCompletionKeepsTaskAndCannotOverwriteConfirmedSuccess() throws {
        let generation = try storage.transaction { state in state.connected = true; return state.generation }
        try storage.save(sample(generation: generation))
        try storage.recordCompletionFailure(id: "task1", generation: generation, uncertain: true, message: "Check Todoist")
        XCTAssertEqual(try storage.read().snapshots["filter"]?.tasks.count, 1)
        XCTAssertEqual(try storage.read().completionLocks["task1"], "uncertain")
        XCTAssertEqual(try storage.read().feedback?.succeeded, false)
        try storage.confirmCompletion(id: "task1", generation: generation)
        try storage.recordCompletionFailure(id: "task1", generation: generation, uncertain: true, message: "Duplicate")
        XCTAssertEqual(try storage.read().feedback?.succeeded, true)
    }
    func testLateCompletionCannotChangeNewAccount() throws {
        let old = try storage.transaction { state in state.connected = true; return state.generation }
        try storage.save(sample(generation: old))
        try storage.transaction { $0 = WidgetDatabase(); $0.connected = true }
        XCTAssertThrowsError(try storage.confirmCompletion(id: "task1", generation: old))
        XCTAssertThrowsError(try storage.recordCompletionFailure(id: "task1", generation: old, uncertain: true, message: "Old"))
        XCTAssertNil(try storage.read().feedback)
        XCTAssertTrue(try storage.read().completionLocks.isEmpty)
    }
    func testPreviousDatabaseDecodesWithoutFeedback() throws {
        let data = try JSONEncoder().encode(WidgetDatabase())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "feedback")
        let previous = try JSONSerialization.data(withJSONObject: object)
        XCTAssertNil(try JSONDecoder().decode(WidgetDatabase.self, from: previous).feedback)
    }

    func testReadingLegacyCacheDropsUnusedPrivateTaskDescription() throws {
        let generation = try storage.transaction { state in state.connected = true; return state.generation }
        try storage.save(sample(generation: generation))
        let file = directory.appendingPathComponent("state.json")
        let previous = String(decoding: try Data(contentsOf: file), as: UTF8.self)
            .replacingOccurrences(of: "\"content\":\"Example\"", with: "\"description\":\"private-note-fixture\",\"content\":\"Example\"")
        XCTAssertTrue(previous.contains("private-note-fixture"))
        try Data(previous.utf8).write(to: file)
        let loaded = try storage.read()
        XCTAssertEqual(loaded.snapshots["filter"]?.tasks.first?.content, "Example")
        let rewritten = String(decoding: try Data(contentsOf: file), as: UTF8.self)
        XCTAssertFalse(rewritten.contains("private-note-fixture"))
        XCTAssertFalse(rewritten.contains("\"description\""))
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        XCTAssertEqual(attributes[.posixPermissions] as? Int, 0o600)
    }
}
