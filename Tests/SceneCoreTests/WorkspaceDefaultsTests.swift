import XCTest
@testable import SceneCore

final class WorkspaceDefaultsTests: XCTestCase {
    func testExecutionDefaultsCreateSceneAndApplyToNewActionOnly() {
        let retry = RetryPolicy(strategy: .fixed, maximumAttempts: 3, initialDelaySeconds: 2, maximumDelaySeconds: 10)
        let defaults = WorkspaceExecutionDefaults(maximumConcurrency: 5, timeoutSeconds: 45, retryPolicy: retry, failurePolicy: .continueDegraded, managedProcessGraceSeconds: 12)

        let scene = defaults.newScene(named: "Defaults")
        XCTAssertEqual(scene.maximumConcurrency, 5)
        XCTAssertEqual(scene.defaultFailurePolicy, .continueDegraded)

        let original = SceneAction.openURL(.init(url: "https://example.com"))
        let configured = defaults.applying(to: original)
        XCTAssertEqual(configured.configuration.timeoutSeconds, 45)
        XCTAssertEqual(configured.configuration.retryPolicy, retry)
        XCTAssertEqual(configured.configuration.failurePolicy, .continueDegraded)
        XCTAssertEqual(configured.configuration.idempotencyPolicy, .oncePerRun)
        XCTAssertNil(original.configuration.timeoutSeconds)
    }

    func testManagedProcessGraceAndPreferenceBounds() {
        let low = WorkspaceExecutionDefaults(maximumConcurrency: -1, timeoutSeconds: -2, managedProcessGraceSeconds: 1_000)
        XCTAssertEqual(low.maximumConcurrency, 1)
        XCTAssertNil(low.timeoutSeconds)
        XCTAssertEqual(low.managedProcessGraceSeconds, 300)

        let action = SceneAction.managedProcess(.init(executable: "/bin/sleep", singleInstanceKey: "server"))
        let configured = low.applying(to: action)
        guard case .managedProcess(let managed) = configured else { return XCTFail("Expected managed process") }
        XCTAssertEqual(managed.gracefulStopSeconds, 300)
    }
}
