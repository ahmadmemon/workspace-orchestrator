import Foundation
import XCTest
import SceneCore
@testable import MacAutomation

final class SceneExecutorTests: XCTestCase {
    func testSequentialSuccessfulSceneCallsAdaptersInOrder() async {
        let events = EventRecorder()
        let app = MockApplicationOpener(events: events)
        let url = MockURLOpener(events: events)
        let process = MockProcessRunner(events: events)
        let executor = SceneExecutor(applicationOpener: app, urlOpener: url, processRunner: process, approvalAuthorizer: AllowAllApprovals())

        let result = await executor.execute(scene: TestScene.valid)

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.actionRecords.map(\.status), [.succeeded, .succeeded, .succeeded])
        let recordedEvents = await events.values
        let recordedBundleIdentifiers = await app.bundleIdentifiers
        let recordedURLs = await url.urls.map(\.absoluteString)
        XCTAssertEqual(recordedEvents, ["app:com.apple.TextEdit", "url:https://example.com", "process:/usr/bin/printf"])
        XCTAssertEqual(recordedBundleIdentifiers, ["com.apple.TextEdit"])
        XCTAssertEqual(recordedURLs, ["https://example.com"])
    }

    func testFailedActionStopsSubsequentExecutionAndPreservesDetails() async {
        let events = EventRecorder()
        let executor = SceneExecutor(
            applicationOpener: MockApplicationOpener(events: events, error: TestError.failed),
            urlOpener: MockURLOpener(events: events),
            processRunner: MockProcessRunner(events: events),
            approvalAuthorizer: AllowAllApprovals()
        )

        let result = await executor.execute(scene: TestScene.valid)

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.failedActionID, "app")
        XCTAssertEqual(result.actionRecords.map(\.status), [.failed, .skipped, .skipped])
        XCTAssertTrue(result.errorMessage?.contains("mock failure") == true)
        let recordedEvents = await events.values
        XCTAssertEqual(recordedEvents, ["app:com.apple.TextEdit"])
    }

    func testNonZeroProcessFailsScene() async {
        let executor = SceneExecutor(
            applicationOpener: MockApplicationOpener(events: EventRecorder()),
            urlOpener: MockURLOpener(events: EventRecorder()),
            processRunner: MockProcessRunner(events: EventRecorder(), exitCode: 7),
            approvalAuthorizer: AllowAllApprovals()
        )
        var scene = TestScene.valid
        scene.actions = [.runProcess(.init(id: "process", executable: "/usr/bin/false"))]
        let result = await executor.execute(scene: scene)
        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.actionRecords.first?.processResult?.exitCode, 7)
        XCTAssertTrue(result.errorMessage?.contains("status 7") == true)
    }

    func testCancellation() async throws {
        let executor = SceneExecutor(
            applicationOpener: MockApplicationOpener(events: EventRecorder()),
            urlOpener: MockURLOpener(events: EventRecorder()),
            processRunner: CancellingProcessRunner(),
            approvalAuthorizer: AllowAllApprovals()
        )
        let scene = Scene(
            id: TestScene.valid.id,
            name: TestScene.valid.name,
            actions: [.runProcess(.init(id: "process", executable: "/bin/sleep"))]
        )
        let task = Task { await executor.execute(scene: scene) }
        try await Task.sleep(for: .milliseconds(30))
        task.cancel()
        let result = await task.value
        XCTAssertEqual(result.status, .cancelled)
        XCTAssertEqual(result.actionRecords.first?.status, .cancelled)
    }

    func testUnapprovedProcessIsRejectedBeforeLaunch() async {
        let events = EventRecorder()
        let executor = SceneExecutor(
            applicationOpener: MockApplicationOpener(events: events),
            urlOpener: MockURLOpener(events: events),
            processRunner: MockProcessRunner(events: events)
        )
        let scene = Scene(name: "Approval", actions: [.runProcess(.init(id: "process", executable: "/usr/bin/printf", arguments: ["safe"]))])

        let result = await executor.execute(scene: scene)

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.errorCategory, .securityApproval)
        XCTAssertTrue(result.errorMessage?.contains("not been approved") == true)
        let recordedEvents = await events.values
        XCTAssertTrue(recordedEvents.isEmpty)
    }
}

private enum TestError: LocalizedError { case failed; var errorDescription: String? { "mock failure" } }

private actor EventRecorder {
    private(set) var values: [String] = []
    func record(_ value: String) { values.append(value) }
}

private actor MockApplicationOpener: ApplicationOpening {
    private(set) var bundleIdentifiers: [String] = []
    let events: EventRecorder
    let error: Error?
    init(events: EventRecorder, error: Error? = nil) { self.events = events; self.error = error }
    func openApplication(bundleIdentifier: String) async throws {
        bundleIdentifiers.append(bundleIdentifier)
        await events.record("app:\(bundleIdentifier)")
        if let error { throw error }
    }
}

private actor MockURLOpener: URLOpening {
    private(set) var urls: [URL] = []
    let events: EventRecorder
    init(events: EventRecorder) { self.events = events }
    func openURL(_ url: URL) async throws {
        urls.append(url)
        await events.record("url:\(url.absoluteString)")
    }
}

private actor MockProcessRunner: ProcessRunning {
    let events: EventRecorder
    let exitCode: Int32
    init(events: EventRecorder, exitCode: Int32 = 0) { self.events = events; self.exitCode = exitCode }
    func run(_ request: ProcessRequest) async throws -> ProcessExecutionResult {
        await events.record("process:\(request.executable)")
        return .init(stdout: "", stderr: "", exitCode: exitCode, startedAt: Date(), endedAt: Date(), timedOut: false, cancelled: false)
    }
}

private struct CancellingProcessRunner: ProcessRunning {
    func run(_ request: ProcessRequest) async throws -> ProcessExecutionResult {
        do { try await Task.sleep(for: .seconds(5)) } catch { }
        return .init(stdout: "", stderr: "", exitCode: 15, startedAt: Date(), endedAt: Date(), timedOut: false, cancelled: true)
    }
}

private struct AllowAllApprovals: ProcessApprovalAuthorizing {
    func isApproved(_ action: SceneAction) async throws -> Bool { true }
    func approve(_ action: SceneAction, scope: ProcessApprovalScope) async throws {}
    func consumeApproval(for action: SceneAction) async throws -> Bool { true }
    func revoke(actionID: String) async throws {}
}

private enum TestScene {
    static let valid = Scene(
        id: "scene",
        name: "Scene",
        actions: [
            .openApplication(.init(id: "app", bundleIdentifier: "com.apple.TextEdit")),
            .openURL(.init(id: "url", url: "https://example.com")),
            .runProcess(.init(id: "process", executable: "/usr/bin/printf", arguments: ["done"]))
        ],
        maximumConcurrency: 1
    )
}
