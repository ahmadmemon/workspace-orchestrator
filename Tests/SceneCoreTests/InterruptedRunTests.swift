import Foundation
import XCTest
@testable import SceneCore

final class InterruptedRunTests: XCTestCase {
    func testActiveRunBecomesInterruptedWithoutStoppingResources() {
        let scene = Scene(name: "Recovery", actions: [.wait(.init(id: "wait", durationSeconds: 5))])
        var run = SceneRunResult(scene: scene)
        run.status = .running
        run.startedAt = Date(timeIntervalSince1970: 10)
        run.actionRecords[0].status = .running
        run.resources = [.init(actionID: "wait", kind: "managedProcess", identifier: "server", ownership: .created)]
        let interruptionDate = Date(timeIntervalSince1970: 20)

        let recovered = run.interruptedAfterRelaunch(at: interruptionDate)

        XCTAssertEqual(recovered.status, .interrupted)
        XCTAssertEqual(recovered.actionRecords[0].status, .interrupted)
        XCTAssertEqual(recovered.endedAt, interruptionDate)
        XCTAssertEqual(recovered.interruptionState, "relaunch-detected")
        XCTAssertEqual(recovered.resources, run.resources)
        XCTAssertFalse(recovered.resources[0].stopped)
    }

    func testTerminalRunIsNotChangedByRecovery() {
        let scene = Scene(name: "Complete")
        var run = SceneRunResult(scene: scene)
        run.status = .ready
        run.endedAt = Date(timeIntervalSince1970: 30)

        XCTAssertEqual(run.interruptedAfterRelaunch(at: Date(timeIntervalSince1970: 40)), run)
    }
}
