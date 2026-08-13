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
        XCTAssertEqual(details?.environmentDescriptions, ["MODE (plain value)", "TOKEN (Keychain reference)"])
        XCTAssertFalse(details?.arguments.contains("keychain-id") == true)
        XCTAssertFalse(details?.environmentDescriptions.contains(where: { $0.contains("keychain-id") }) == true)
    }

    func testEnvironmentConfigurationAndSecretReferenceChangesInvalidateApproval() async throws {
        let store = makeStore()
        let original = SceneAction.runProcess(.init(id: "process", executable: "/usr/bin/printf", environment: ["MODE": .plain("debug"), "TOKEN": .secretReference("keychain-a")]))
        try await store.approve(original, scope: .exactAction)

        let changedPlainValue = SceneAction.runProcess(.init(id: "process", executable: "/usr/bin/printf", environment: ["MODE": .plain("release"), "TOKEN": .secretReference("keychain-a")]))
        let changedValueKind = SceneAction.runProcess(.init(id: "process", executable: "/usr/bin/printf", environment: ["MODE": .inherited, "TOKEN": .secretReference("keychain-a")]))
        let changedSecretReference = SceneAction.runProcess(.init(id: "process", executable: "/usr/bin/printf", environment: ["MODE": .plain("debug"), "TOKEN": .secretReference("keychain-b")]))

        let plainApproved = try await store.isApproved(changedPlainValue)
        let kindApproved = try await store.isApproved(changedValueKind)
        let referenceApproved = try await store.isApproved(changedSecretReference)
        XCTAssertFalse(plainApproved)
        XCTAssertFalse(kindApproved)
        XCTAssertFalse(referenceApproved)
    }

    func testWorkingDirectoryTimeoutRetryAndManagedStopChangesInvalidateApproval() throws {
        let originalConfiguration = ActionConfiguration(timeoutSeconds: 10, retryPolicy: .init(strategy: .fixed, maximumAttempts: 2))
        let original = SceneAction.managedProcess(.init(id: "server", executable: "/usr/bin/yes", arguments: ["ok"], workingDirectory: "/tmp", singleInstanceKey: "server", gracefulStopSeconds: 5, configuration: originalConfiguration))
        let originalFingerprint = try ApprovalFingerprint.make(for: original)

        let directory = SceneAction.managedProcess(.init(id: "server", executable: "/usr/bin/yes", arguments: ["ok"], workingDirectory: "/var/tmp", singleInstanceKey: "server", gracefulStopSeconds: 5, configuration: originalConfiguration))
        var timeoutConfiguration = originalConfiguration; timeoutConfiguration.timeoutSeconds = 20
        let timeout = SceneAction.managedProcess(.init(id: "server", executable: "/usr/bin/yes", arguments: ["ok"], workingDirectory: "/tmp", singleInstanceKey: "server", gracefulStopSeconds: 5, configuration: timeoutConfiguration))
        var retryConfiguration = originalConfiguration; retryConfiguration.retryPolicy.maximumAttempts = 3
        let retry = SceneAction.managedProcess(.init(id: "server", executable: "/usr/bin/yes", arguments: ["ok"], workingDirectory: "/tmp", singleInstanceKey: "server", gracefulStopSeconds: 5, configuration: retryConfiguration))
        let stop = SceneAction.managedProcess(.init(id: "server", executable: "/usr/bin/yes", arguments: ["ok"], workingDirectory: "/tmp", singleInstanceKey: "server", gracefulStopSeconds: 9, configuration: originalConfiguration))
        let forcedStop = SceneAction.managedProcess(.init(id: "server", executable: "/usr/bin/yes", arguments: ["ok"], workingDirectory: "/tmp", singleInstanceKey: "server", gracefulStopSeconds: 5, forcedStopSeconds: 8, configuration: originalConfiguration))

        XCTAssertNotEqual(try ApprovalFingerprint.make(for: directory), originalFingerprint)
        XCTAssertNotEqual(try ApprovalFingerprint.make(for: timeout), originalFingerprint)
        XCTAssertNotEqual(try ApprovalFingerprint.make(for: retry), originalFingerprint)
        XCTAssertNotEqual(try ApprovalFingerprint.make(for: stop), originalFingerprint)
        XCTAssertNotEqual(try ApprovalFingerprint.make(for: forcedStop), originalFingerprint)
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
