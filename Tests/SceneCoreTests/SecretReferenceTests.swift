import XCTest
@testable import SceneCore

final class SecretReferenceTests: XCTestCase {
    func testUsageListsSceneActionAndEnvironmentWithoutSecretValue() {
        let scene = Scene(id: "scene", name: "Development", actions: [
            .runProcess(.init(id: "process", executable: "/usr/bin/true", environment: ["TOKEN": .secretReference("api-token"), "MODE": .plain("debug")]))
        ])

        XCTAssertEqual(scene.secretReferenceUsages(id: "api-token"), [
            .init(sceneID: "scene", sceneName: "Development", actionID: "process", actionName: "One-Shot Process", environmentName: "TOKEN")
        ])
        XCTAssertTrue(scene.secretReferenceUsages(id: "missing").isEmpty)
    }

    func testRenameRewritesStartAndStopReferencesWithoutChangingOtherValues() {
        let scene = Scene(name: "Rename", actions: [
            .runProcess(.init(executable: "/usr/bin/true", environment: ["TOKEN": .secretReference("old"), "OTHER": .secretReference("untouched")]))
        ], deactivationActions: [
            .managedProcess(.init(executable: "/bin/sleep", environment: ["TOKEN": .secretReference("old")], singleInstanceKey: "server"))
        ])

        let renamed = scene.replacingSecretReference(from: "old", to: "new")

        XCTAssertEqual(renamed.secretReferenceUsages(id: "new").count, 2)
        XCTAssertTrue(renamed.secretReferenceUsages(id: "old").isEmpty)
        XCTAssertEqual(renamed.secretReferenceUsages(id: "untouched").count, 1)
    }
}
