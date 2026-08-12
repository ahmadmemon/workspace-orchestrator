import Foundation
import XCTest
@testable import SceneCore

final class V2SecurityAndMigrationTests: XCTestCase {
    func testV1SceneDecodesAsV2WithSequentialConcurrency() throws {
        let json = #"[{"schemaVersion":1,"id":"old","name":"Old","actions":[{"id":"p","type":"runProcess","executable":"/usr/bin/printf","arguments":["ok"]}],"createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:00:00Z"}]"#
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let scene = try XCTUnwrap(decoder.decode([Scene].self, from: Data(json.utf8)).first)
        XCTAssertEqual(scene.schemaVersion, 2); XCTAssertEqual(scene.maximumConcurrency, 1); XCTAssertEqual(scene.trustState, .local)
    }

    func testStoreBacksUpV1BeforeMigration() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let original = #"[{"schemaVersion":1,"id":"old","name":"Old","actions":[],"createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:00:00Z"}]"#
        try Data(original.utf8).write(to: directory.appendingPathComponent("scenes.json"))
        let scenes = try await JSONSceneStore(directoryURL: directory).loadScenes()
        XCTAssertEqual(scenes.first?.schemaVersion, 2)
        let backups = try FileManager.default.contentsOfDirectory(at: directory.appendingPathComponent("migration-backups"), includingPropertiesForKeys: nil)
        XCTAssertEqual(backups.count, 1); XCTAssertEqual(try Data(contentsOf: backups[0]), Data(original.utf8))
    }

    func testRestrictedExecutablesFailValidation() {
        for executable in SceneValidator.restrictedExecutables {
            let scene = Scene(name: "Restricted", actions: [.runProcess(.init(executable: executable))])
            XCTAssertTrue(SceneValidator.issues(in: scene).contains { $0.message.contains("restricted") }, executable)
        }
    }

    func testDependencyCycleFailsValidationWithoutCrashingOnDuplicateIDs() {
        let first = SceneAction.wait(.init(id: "a", durationSeconds: 1, configuration: .init(dependencies: ["b"])))
        let second = SceneAction.wait(.init(id: "b", durationSeconds: 1, configuration: .init(dependencies: ["a"])))
        XCTAssertTrue(SceneValidator.issues(in: Scene(name: "Cycle", actions: [first, second])).contains { $0.message.contains("cycle") })
        XCTAssertTrue(SceneValidator.issues(in: Scene(name: "Duplicate", actions: [first, first])).contains { $0.message.contains("unique") })
    }

    func testRetryPolicyProducesBoundedDeterministicDelay() {
        let policy = RetryPolicy(strategy: .exponential, maximumAttempts: 5, initialDelaySeconds: 2, maximumDelaySeconds: 5, jitterFraction: 0.5)
        XCTAssertEqual(policy.delay(beforeAttempt: 2, deterministicUnit: 0.5), 2)
        XCTAssertEqual(policy.delay(beforeAttempt: 5, deterministicUnit: 1), 5)
    }

    func testApprovalFingerprintChangesWithMaterialConfiguration() throws {
        let first = SceneAction.runProcess(.init(executable: "/usr/bin/printf", arguments: ["one"]))
        let second = SceneAction.runProcess(.init(executable: "/usr/bin/printf", arguments: ["two"]))
        XCTAssertNotEqual(try ApprovalFingerprint.make(for: first), try ApprovalFingerprint.make(for: second))
        XCTAssertEqual(try ApprovalFingerprint.make(for: first).count, 64)
    }

    func testSecretReferenceSerializesWithoutSecretValue() throws {
        let scene = Scene(name: "Secret", actions: [.runProcess(.init(executable: "/usr/bin/printf", environment: ["TOKEN": .secretReference("keychain-id")]))])
        let text = String(decoding: try JSONEncoder().encode(scene), as: UTF8.self)
        XCTAssertTrue(text.contains("keychain-id")); XCTAssertFalse(text.contains("actual-secret"))
    }

    func testRedactorMasksCommonAndExplicitSecretsAndBoundsOutput() {
        let result = Redactor.redact("Authorization: Bearer abc token=xyz explicit-value", secrets: ["explicit-value"], configuration: .init(maximumBytes: 48))
        XCTAssertFalse(result.contains("abc")); XCTAssertFalse(result.contains("xyz")); XCTAssertFalse(result.contains("explicit-value"))
    }

    func testImportIsUntrustedAndListsRiskyActions() throws {
        let scene = Scene(name: "Import", actions: [.runProcess(.init(executable: "/usr/bin/printf")), .windowLayout(.init(placements: [.init(bundleIdentifier: "com.apple.TextEdit", frame: .init(x: 0, y: 0, width: 1, height: 1))]))])
        let data = try SceneArchiveService.export([scene], appVersion: "test")
        let preview = try SceneArchiveService.previewImport(data)
        XCTAssertEqual(preview.scenes.first?.trustState, .importedUntrusted); XCTAssertEqual(preview.executables, ["/usr/bin/printf"]); XCTAssertEqual(preview.requiredPermissions, ["Accessibility"])
    }
}
