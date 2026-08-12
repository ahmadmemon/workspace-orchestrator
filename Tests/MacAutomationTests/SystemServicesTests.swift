import XCTest
import SceneCore
@testable import MacAutomation

final class SystemServicesTests: XCTestCase {
    func testNotificationContainsOnlyBoundedSceneAndStatusSummary() {
        let scene = Scene(name: "Secret\nProject", actions: [.runProcess(.init(id: "process", executable: "/usr/bin/printf"))])
        var run = SceneRunResult(scene: scene)
        run.status = .failed
        run.failedActionID = "process"
        run.actionRecords[0].errorMessage = "token=super-secret"
        run.actionRecords[0].outputSummary = "password=also-secret"

        let content = RunNotificationContent.make(for: run)

        XCTAssertEqual(content?.title, "SecretProject failed")
        XCTAssertEqual(content?.body, "Blocked while starting One-Shot Process.")
        XCTAssertFalse(content?.body.contains("super-secret") == true)
        XCTAssertFalse(content?.body.contains("also-secret") == true)
    }

    func testNotificationIsNotProducedForIntermediateState() {
        let scene = Scene(name: "Build")
        var run = SceneRunResult(scene: scene)
        run.status = .running
        XCTAssertNil(RunNotificationContent.make(for: run))
    }
}
