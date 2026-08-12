import XCTest
@testable import OrchestrationEngine
@testable import SceneCore

final class OrchestrationEngineTests: XCTestCase {
    func testIndependentActionsRunInParallelWithinBound() async {
        let executor = RecordingExecutor()
        let engine = OrchestrationEngine(actionExecutor: executor)
        let scene = Scene(name: "Parallel", actions: [process("a"), process("b"), process("c")], maximumConcurrency: 2)
        let result = await engine.execute(scene: scene)
        XCTAssertEqual(result.status, .ready)
        let maximumConcurrent = await executor.maximumConcurrent
        XCTAssertEqual(maximumConcurrent, 2)
    }

    func testDependenciesRunAfterPrerequisite() async {
        let executor = RecordingExecutor()
        let engine = OrchestrationEngine(actionExecutor: executor)
        let scene = Scene(name: "Dependencies", actions: [process("a"), process("b", dependencies: ["a"])])
        let result = await engine.execute(scene: scene)
        XCTAssertEqual(result.status, .ready)
        let starts = await executor.starts
        XCTAssertEqual(starts, ["a", "b"])
    }

    func testOptionalFailureDoesNotDegrade() async {
        let executor = RecordingExecutor(failing: ["optional"])
        let config = ActionConfiguration(failurePolicy: .continueOptional)
        let scene = Scene(name: "Optional", actions: [.runProcess(.init(id: "optional", executable: "/usr/bin/false", configuration: config)), process("required")])
        let result = await OrchestrationEngine(actionExecutor: executor).execute(scene: scene)
        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.actionRecords.first?.status, .failed)
    }

    func testRequiredFailureSkipsRemaining() async {
        let executor = RecordingExecutor(failing: ["a"])
        let scene = Scene(name: "Stop", actions: [process("a"), process("b", dependencies: ["a"])])
        let result = await OrchestrationEngine(actionExecutor: executor).execute(scene: scene)
        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.actionRecords.map(\.status), [.failed, .skipped])
    }

    func testCancellationDuringWait() async throws {
        let scene = Scene(name: "Cancel", actions: [.wait(.init(id: "wait", durationSeconds: 10))])
        let task = Task { await OrchestrationEngine(actionExecutor: RecordingExecutor()).execute(scene: scene) }
        try await Task.sleep(for: .milliseconds(20)); task.cancel()
        let result = await task.value
        XCTAssertEqual(result.status, .cancelled)
    }

    private func process(_ id: String, dependencies: [String] = []) -> SceneAction {
        .runProcess(.init(id: id, executable: "/usr/bin/true", configuration: .init(dependencies: dependencies)))
    }
}

private actor RecordingExecutor: ActionExecuting {
    private let failing: Set<String>; private(set) var starts: [String] = []; private(set) var maximumConcurrent = 0; private var concurrent = 0
    init(failing: Set<String> = []) { self.failing = failing }
    func execute(_ action: SceneAction) async throws -> ActionExecutionOutcome {
        starts.append(action.id); concurrent += 1; maximumConcurrent = max(maximumConcurrent, concurrent)
        try? await Task.sleep(for: .milliseconds(30)); concurrent -= 1
        if failing.contains(action.id) { throw OrchestrationFailure(category: .processExit, message: "mock failure", retryableCategory: .processExit) }
        return .init()
    }
}
