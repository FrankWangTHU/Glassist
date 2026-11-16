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
}
