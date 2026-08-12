import XCTest
@testable import SceneCore

final class SceneValidationTests: XCTestCase {
    func testValidScene() { XCTAssertNoThrow(try SceneValidator.validate(TestFixtures.validScene)) }

    func testUnsupportedSchemaVersion() {
        var scene = TestFixtures.validScene
        scene.schemaVersion = 99
        assertInvalid(scene, contains: "Unsupported schema")
    }

    func testEmptySceneID() {
        var scene = TestFixtures.validScene
        scene.id = "  "
        assertInvalid(scene, contains: "Scene ID")
    }

    func testEmptySceneName() {
        var scene = TestFixtures.validScene
        scene.name = "\n"
        assertInvalid(scene, contains: "Scene name")
    }

    func testEmptyActionID() {
        var scene = TestFixtures.validScene
        scene.actions = [.openURL(.init(id: "", url: "https://example.com"))]
        assertInvalid(scene, contains: "Action ID must not be empty")
    }

    func testDuplicateActionIDs() {
        var scene = TestFixtures.validScene
        scene.actions = [
            .openURL(.init(id: "same", url: "https://example.com")),
            .openApplication(.init(id: "same", bundleIdentifier: "com.apple.TextEdit"))
        ]
        assertInvalid(scene, contains: "unique")
    }

    func testInvalidURL() {
        var scene = TestFixtures.validScene
        scene.actions = [.openURL(.init(url: "javascript:alert(1)"))]
        assertInvalid(scene, contains: "http or https")
    }

    func testMissingExecutable() {
        var scene = TestFixtures.validScene
        scene.actions = [.runProcess(.init(executable: ""))]
        assertInvalid(scene, contains: "Executable is required")
    }

    func testRelativeExecutable() {
        var scene = TestFixtures.validScene
        scene.actions = [.runProcess(.init(executable: "usr/bin/printf"))]
        assertInvalid(scene, contains: "absolute path")
    }

    func testInvalidTimeout() {
        var scene = TestFixtures.validScene
        scene.actions = [.runProcess(.init(executable: "/usr/bin/printf", timeoutSeconds: 0))]
        assertInvalid(scene, contains: "greater than zero")
    }

    func testInvalidBundleIdentifier() {
        var scene = TestFixtures.validScene
        scene.actions = [.openApplication(.init(bundleIdentifier: "TextEdit"))]
        assertInvalid(scene, contains: "bundle identifier")
    }

    func testAdvancedConditionAndHealthBoundsAreValidated() {
        let configuration = ActionConfiguration(
            conditions: [.pathExists("relative"), .environmentEquals(name: "BAD-NAME", value: "value")],
            disabledConditionIndexes: [4],
            healthChecks: [.http(.init(url: "https://example.com", responseContains: String(repeating: "x", count: 4_097), maximumAttempts: 101))]
        )
        let scene = Scene(name: "Invalid advanced", actions: [.runProcess(.init(id: "process", executable: "/usr/bin/true", configuration: configuration))])
        let messages = SceneValidator.issues(in: scene).map(\.message)

        XCTAssertTrue(messages.contains { $0.contains("Condition path must be absolute") })
        XCTAssertTrue(messages.contains { $0.contains("environment name is invalid") })
        XCTAssertTrue(messages.contains { $0.contains("Disabled condition index") })
        XCTAssertTrue(messages.contains { $0.contains("limited to 4096") })
        XCTAssertTrue(messages.contains { $0.contains("must be bounded") })
    }

    func testProcessAndDockerHealthChecksRequireMatchingActionTypes() {
        let configuration = ActionConfiguration(healthChecks: [.process(.init(actionID: "plain")), .docker(.init(composeActionID: "plain", service: "web"))])
        let plain = SceneAction.runProcess(.init(id: "plain", executable: "/usr/bin/true", configuration: configuration))
        let messages = SceneValidator.issues(in: Scene(name: "References", actions: [plain])).map(\.message)

        XCTAssertTrue(messages.contains { $0.contains("managed-process action") })
        XCTAssertTrue(messages.contains { $0.contains("Docker Compose action") })
    }

    private func assertInvalid(_ scene: Scene, contains expected: String, file: StaticString = #filePath, line: UInt = #line) {
        let issues = SceneValidator.issues(in: scene)
        XCTAssertTrue(issues.contains(where: { $0.message.contains(expected) }), "Issues were: \(issues)", file: file, line: line)
    }
}
