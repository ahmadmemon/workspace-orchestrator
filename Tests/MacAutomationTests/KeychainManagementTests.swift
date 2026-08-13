import Foundation
import XCTest
@testable import MacAutomation

final class KeychainManagementTests: XCTestCase {
    func testMockBackedRenameMovesValueWithoutReturningItToTheCaller() async throws {
        let store = MockKeychainStore(values: ["old-label": Data("private-value".utf8)])

        try await store.rename(from: "old-label", to: "new-label")

        let ids = try await store.listIDs()
        let value = try await store.read(id: "new-label")
        XCTAssertEqual(ids, ["new-label"])
        XCTAssertEqual(value, Data("private-value".utf8))
        await XCTAssertThrowsErrorAsync { _ = try await store.read(id: "old-label") }
    }

    func testRenameRollsBackNewLabelWhenOldLabelCannotBeDeleted() async throws {
        let store = MockKeychainStore(values: ["old": Data("value".utf8)], failingDeleteID: "old")

        await XCTAssertThrowsErrorAsync { try await store.rename(from: "old", to: "new") }

        let ids = try await store.listIDs()
        XCTAssertEqual(ids, ["old"])
    }
}

private actor MockKeychainStore: KeychainStoring {
    var values: [String: Data]
    let failingDeleteID: String?
    init(values: [String: Data] = [:], failingDeleteID: String? = nil) { self.values = values; self.failingDeleteID = failingDeleteID }
    func create(id: String, value: Data) async throws { guard values[id] == nil else { throw KeychainStoreError.duplicate }; values[id] = value }
    func update(id: String, value: Data) async throws { guard values[id] != nil else { throw KeychainStoreError.notFound }; values[id] = value }
    func read(id: String) async throws -> Data { guard let value = values[id] else { throw KeychainStoreError.notFound }; return value }
    func delete(id: String) async throws { if id == failingDeleteID { throw KeychainStoreError.unexpectedStatus(-1) }; values[id] = nil }
    func listIDs() async throws -> [String] { values.keys.sorted() }
}

private func XCTAssertThrowsErrorAsync(_ expression: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
    do { try await expression(); XCTFail("Expected an error", file: file, line: line) }
    catch { }
}
