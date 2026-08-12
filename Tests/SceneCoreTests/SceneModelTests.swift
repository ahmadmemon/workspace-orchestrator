import Foundation
import XCTest
@testable import SceneCore

final class SceneModelTests: XCTestCase {
    private let encoder: JSONEncoder = {
        let value = JSONEncoder()
        value.dateEncodingStrategy = .iso8601
        return value
    }()

    private let decoder: JSONDecoder = {
        let value = JSONDecoder()
        value.dateDecodingStrategy = .iso8601
        return value
    }()

    func testSceneEncodingIncludesAllActionTypes() throws {
        let data = try encoder.encode(TestFixtures.validScene)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(text.contains("openApplication"))
        XCTAssertTrue(text.contains("openURL"))
        XCTAssertTrue(text.contains("runProcess"))
    }

    func testSceneDecoding() throws {
        let data = try encoder.encode(TestFixtures.validScene)
        XCTAssertEqual(try decoder.decode(Scene.self, from: data), TestFixtures.validScene)
    }

    func testRoundTripSerialization() throws {
        let first = try encoder.encode(TestFixtures.validScene)
        let decoded = try decoder.decode(Scene.self, from: first)
        let second = try encoder.encode(decoded)
        XCTAssertEqual(try decoder.decode(Scene.self, from: second), TestFixtures.validScene)
    }

    func testUnknownActionTypeIsRejected() {
        let json = """
        {"schemaVersion":1,"id":"scene","name":"Bad","actions":[{"id":"a","type":"futureAction"}],"createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:00:00Z"}
        """
        XCTAssertThrowsError(try decoder.decode(Scene.self, from: Data(json.utf8)))
    }

    func testAdvancedBuilderConfigurationRoundTripsWithoutArgumentLoss() throws {
        let configuration = ActionConfiguration(
            conditions: [.pathExists("/tmp"), .environmentEquals(name: "MODE", value: "ready")],
            conditionEvaluationMode: .any,
            disabledConditionIndexes: [1],
            healthChecks: [
                .http(.init(id: "http", url: "https://example.com/health", method: .head, expectedStatus: 200...204, responseContains: "ready", timeoutSeconds: 4, intervalSeconds: 2, maximumAttempts: 3, required: true)),
                .tcp(.init(id: "tcp", host: "localhost", port: 8080, timeoutSeconds: 2, intervalSeconds: 1, maximumAttempts: 4, required: false)),
                .file(.init(id: "file", path: "/tmp", mustBeDirectory: true, modifiedWithinSeconds: 60, timeoutSeconds: 2, intervalSeconds: 0.5, maximumAttempts: 2, required: true)),
                .process(.init(id: "process-check", actionID: "managed", timeoutSeconds: 2, intervalSeconds: 1, maximumAttempts: 3, required: true)),
                .application(.init(id: "application", bundleIdentifier: "com.apple.TextEdit", timeoutSeconds: 2, intervalSeconds: 1, maximumAttempts: 3, required: false)),
                .docker(.init(id: "docker", composeActionID: "compose", service: "web", requireHealthy: true, timeoutSeconds: 5, intervalSeconds: 2, maximumAttempts: 6, required: true))
            ]
        )
        let arguments = ["", "   ", "two\nlines", "--literal=$VALUE"]
        let scene = Scene(
            name: "Advanced",
            actions: [
                .runProcess(.init(id: "process", executable: "/usr/bin/printf", arguments: arguments, configuration: configuration)),
                .managedProcess(.init(id: "managed", executable: "/bin/sleep", arguments: ["60"], singleInstanceKey: "advanced-test")),
                .dockerCompose(.init(id: "compose", projectDirectory: "/tmp", services: ["web"]))
            ],
            createdAt: TestFixtures.date,
            updatedAt: TestFixtures.date
        )

        let decoded = try decoder.decode(Scene.self, from: encoder.encode(scene))
        let archivePreview = try SceneArchiveService.previewImport(SceneArchiveService.export([scene], appVersion: "1.0"))

        XCTAssertEqual(decoded, scene)
        XCTAssertEqual(archivePreview.scenes[0].actions, scene.actions)
        XCTAssertEqual(archivePreview.scenes[0].trustState, .importedUntrusted)
        guard case .runProcess(let process) = decoded.actions[0] else { return XCTFail("Expected process") }
        XCTAssertEqual(process.arguments, arguments)
    }

    func testAdvancedConfigurationSurvivesArchiveExportAndImport() throws {
        let configuration = ActionConfiguration(conditions: [.pathExists("/tmp")], conditionEvaluationMode: .all, healthChecks: [.file(.init(id: "file", path: "/tmp", required: false))])
        let scene = Scene(name: "Archive", actions: [.runProcess(.init(id: "process", executable: "/usr/bin/printf", arguments: ["", "a\nb"], configuration: configuration))])

        let preview = try SceneArchiveService.previewImport(SceneArchiveService.export([scene], appVersion: "1.0"))

        XCTAssertEqual(preview.scenes[0].actions, scene.actions)
        XCTAssertEqual(preview.scenes[0].trustState, .importedUntrusted)
    }

    func testMissingAdvancedConfigurationKeysDecodeWithSafeDefaults() throws {
        let json = #"{"conditions":[{"type":"pathExists","path":"/tmp"}],"enabled":true,"dependencies":[],"retryPolicy":{"strategy":"none","maximumAttempts":1,"initialDelaySeconds":1,"maximumDelaySeconds":30,"maximumTotalDurationSeconds":120,"jitterFraction":0,"retryableCategories":[]},"failurePolicy":"stopScene","idempotencyPolicy":"alwaysRun","healthChecks":[],"outputRetention":"summary"}"#

        let configuration = try decoder.decode(ActionConfiguration.self, from: Data(json.utf8))

        XCTAssertEqual(configuration.conditionEvaluationMode, .all)
        XCTAssertTrue(configuration.disabledConditionIndexes.isEmpty)
    }

    func testManagedProcessWithoutForcedStopFieldUsesSafeDefault() throws {
        let json = #"{"type":"managedProcess","id":"managed","executable":"/bin/sleep","arguments":["1"],"environment":{},"singleInstanceKey":"managed","restartPolicy":"never","gracefulStopSeconds":5,"configuration":{"enabled":true,"dependencies":[],"retryPolicy":{"strategy":"none","maximumAttempts":1,"initialDelaySeconds":1,"maximumDelaySeconds":30,"maximumTotalDurationSeconds":120,"jitterFraction":0,"retryableCategories":[]},"failurePolicy":"stopScene","idempotencyPolicy":"singleInstance","conditions":[],"healthChecks":[],"outputRetention":"summary"}}"#
        let action = try decoder.decode(SceneAction.self, from: Data(json.utf8))
        guard case .managedProcess(let managed) = action else { return XCTFail("Expected managed process") }
        XCTAssertEqual(managed.forcedStopSeconds, 2)
    }
}

enum TestFixtures {
    static let date = Date(timeIntervalSince1970: 1_700_000_000)
    static let validScene = Scene(
        id: "scene-1",
        name: "Test Scene",
        description: "A scene",
        actions: [
            .openApplication(.init(id: "app", bundleIdentifier: "com.apple.TextEdit")),
            .openURL(.init(id: "url", url: "https://example.com")),
            .runProcess(.init(id: "process", executable: "/usr/bin/printf", arguments: ["hello"]))
        ],
        createdAt: date,
        updatedAt: date
    )
}
