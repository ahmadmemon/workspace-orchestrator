import Foundation
import XCTest
@testable import SceneCore

final class WorkspaceDefaultsTests: XCTestCase {
    func testExecutionDefaultsCreateSceneAndApplyToNewActionOnly() {
        let retry = RetryPolicy(strategy: .fixed, maximumAttempts: 3, initialDelaySeconds: 2, maximumDelaySeconds: 10)
        let defaults = WorkspaceExecutionDefaults(maximumConcurrency: 5, timeoutSeconds: 45, retryPolicy: retry, failurePolicy: .continueDegraded, managedProcessGraceSeconds: 12, managedProcessForcedStopSeconds: 4, outputRetention: .bounded, healthCheckIntervalSeconds: 3, healthCheckMaximumAttempts: 8, ownershipPolicy: .includeAdopted)

        let scene = defaults.newScene(named: "Defaults")
        XCTAssertEqual(scene.maximumConcurrency, 5)
        XCTAssertEqual(scene.defaultFailurePolicy, .continueDegraded)

        let original = SceneAction.openURL(.init(url: "https://example.com"))
        let configured = defaults.applying(to: original)
        XCTAssertEqual(configured.configuration.timeoutSeconds, 45)
        XCTAssertEqual(configured.configuration.retryPolicy, retry)
        XCTAssertEqual(configured.configuration.failurePolicy, .continueDegraded)
        XCTAssertEqual(configured.configuration.outputRetention, .bounded)
        XCTAssertEqual(configured.configuration.idempotencyPolicy, .oncePerRun)
        XCTAssertNil(original.configuration.timeoutSeconds)
    }

    func testManagedProcessGraceAndPreferenceBounds() {
        let low = WorkspaceExecutionDefaults(maximumConcurrency: -1, timeoutSeconds: -2, managedProcessGraceSeconds: 1_000, managedProcessForcedStopSeconds: 100, healthCheckIntervalSeconds: 0, healthCheckMaximumAttempts: 1_000)
        XCTAssertEqual(low.maximumConcurrency, 1)
        XCTAssertNil(low.timeoutSeconds)
        XCTAssertEqual(low.managedProcessGraceSeconds, 300)
        XCTAssertEqual(low.managedProcessForcedStopSeconds, 60)
        XCTAssertEqual(low.healthCheckIntervalSeconds, 0.1)
        XCTAssertEqual(low.healthCheckMaximumAttempts, 100)

        let action = SceneAction.managedProcess(.init(executable: "/bin/sleep", singleInstanceKey: "server"))
        let configured = low.applying(to: action)
        guard case .managedProcess(let managed) = configured else { return XCTFail("Expected managed process") }
        XCTAssertEqual(managed.gracefulStopSeconds, 300)
        XCTAssertEqual(managed.forcedStopSeconds, 60)
    }

    func testOlderExecutionDefaultsDecodeWithSafeNewDefaults() throws {
        let json = #"{"maximumConcurrency":4,"retryPolicy":{"strategy":"none","maximumAttempts":1,"initialDelaySeconds":1,"maximumDelaySeconds":30,"maximumTotalDurationSeconds":120,"jitterFraction":0,"retryableCategories":[]},"failurePolicy":"stopScene","managedProcessGraceSeconds":5}"#
        let decoded = try JSONDecoder().decode(WorkspaceExecutionDefaults.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.managedProcessForcedStopSeconds, 2)
        XCTAssertEqual(decoded.outputRetention, .summary)
        XCTAssertEqual(decoded.healthCheckIntervalSeconds, 1)
        XCTAssertEqual(decoded.healthCheckMaximumAttempts, 10)
        XCTAssertEqual(decoded.ownershipPolicy, .createdOnly)
    }
}
