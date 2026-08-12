import Foundation
import XCTest
@testable import SceneCore

final class ProcessApprovalStoreTests: XCTestCase {
    func testClearAllRevokesPersistedExactApprovals() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = JSONProcessApprovalStore(fileURL: directory.appendingPathComponent("approvals.json"))
        let action = SceneAction.runProcess(.init(id: "clear-me", executable: "/usr/bin/true"))
        try await store.approve(action, scope: .exactAction)
        let approvedBeforeClear = try await store.isApproved(action)
        XCTAssertTrue(approvedBeforeClear)
        try await store.clearAll()
        let approvedAfterClear = try await store.isApproved(action)
        XCTAssertFalse(approvedAfterClear)
    }
    func testApproveOnceIsConsumedExactlyOnce() async throws {
        let store = makeStore()
        let action = SceneAction.runProcess(.init(id: "process", executable: "/usr/bin/printf", arguments: ["hello"]))

        try await store.approve(action, scope: .once)

        let approved = try await store.isApproved(action)
        let firstUse = try await store.consumeApproval(for: action)
        let secondUse = try await store.consumeApproval(for: action)
        XCTAssertTrue(approved)
        XCTAssertTrue(firstUse)
        XCTAssertFalse(secondUse)
    }

    func testExactApprovalPersistsAcrossStoreInstances() async throws {
        let url = temporaryDirectory().appendingPathComponent("approvals.json")
        let action = SceneAction.managedProcess(.init(id: "server", executable: "/usr/bin/yes", arguments: ["ready"], singleInstanceKey: "server"))
        let first = JSONProcessApprovalStore(fileURL: url)
        try await first.approve(action, scope: .exactAction)

        let reopened = JSONProcessApprovalStore(fileURL: url)

        let persisted = try await reopened.consumeApproval(for: action)
        XCTAssertTrue(persisted)
    }

    func testMaterialChangeInvalidatesExactApproval() async throws {
        let store = makeStore()
        let approved = SceneAction.runProcess(.init(id: "process", executable: "/usr/bin/printf", arguments: ["safe"]))
        let changed = SceneAction.runProcess(.init(id: "process", executable: "/usr/bin/printf", arguments: ["changed"]))
        try await store.approve(approved, scope: .exactAction)

        let originalApproved = try await store.isApproved(approved)
        let changedApproved = try await store.isApproved(changed)
        XCTAssertTrue(originalApproved)
        XCTAssertFalse(changedApproved)
    }

    func testApprovalDetailsExposeNamesButNotSecretValues() {
        let action = SceneAction.runProcess(.init(
            executable: "/usr/bin/printf",
            environment: ["TOKEN": .secretReference("keychain-id"), "MODE": .plain("debug")]
        ))

        let details = action.processApprovalDetails

        XCTAssertEqual(details?.environmentNames, ["MODE", "TOKEN"])
        XCTAssertFalse(details?.arguments.contains("keychain-id") == true)
    }

    private func makeStore() -> JSONProcessApprovalStore {
        JSONProcessApprovalStore(fileURL: temporaryDirectory().appendingPathComponent("approvals.json"))
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
