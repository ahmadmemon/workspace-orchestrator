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

    func testRetryUsesInjectedSleeperAndRecordsAttempts() async {
        let executor = FlakyExecutor(failuresBeforeSuccess: 2)
        let sleeper = RecordingSleeper()
        let retry = RetryPolicy(strategy: .exponential, maximumAttempts: 3, initialDelaySeconds: 1, maximumDelaySeconds: 10, maximumTotalDurationSeconds: 30, jitterFraction: 0)
        let action = SceneAction.runProcess(.init(id: "retry", executable: "/usr/bin/true", configuration: .init(retryPolicy: retry)))
        let result = await OrchestrationEngine(actionExecutor: executor, sleeper: sleeper).execute(scene: .init(name: "Retry", actions: [action]))
        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.actionRecords[0].attempts.count, 3)
        let delays = await sleeper.values
        XCTAssertEqual(delays, [1, 2])
    }

    func testCancellationInterruptsRetryDelay() async throws {
        let retry = RetryPolicy(strategy: .fixed, maximumAttempts: 3, initialDelaySeconds: 10, maximumDelaySeconds: 10, maximumTotalDurationSeconds: 60)
        let action = SceneAction.runProcess(.init(id: "retry", executable: "/usr/bin/true", configuration: .init(retryPolicy: retry)))
        let task = Task { await OrchestrationEngine(actionExecutor: AlwaysFailingExecutor()).execute(scene: .init(name: "Retry cancellation", actions: [action])) }
        try await Task.sleep(for: .milliseconds(20)); task.cancel()
        let result = await task.value
        XCTAssertEqual(result.status, .cancelled)
    }

    func testContinueDegradedProducesReadyWithWarnings() async {
        let executor = RecordingExecutor(failing: ["warning"])
        let action = SceneAction.runProcess(.init(id: "warning", executable: "/usr/bin/false", configuration: .init(failurePolicy: .continueDegraded)))
        let result = await OrchestrationEngine(actionExecutor: executor).execute(scene: .init(name: "Degraded", actions: [action]))
        XCTAssertEqual(result.status, .readyWithWarnings)
    }

    func testHealthFailureBlocksReadiness() async {
        let check = HealthCheck.file(.init(path: "/not-used"))
        let action = SceneAction.runProcess(.init(id: "health", executable: "/usr/bin/true", configuration: .init(healthChecks: [check])))
        let result = await OrchestrationEngine(actionExecutor: RecordingExecutor(), healthChecker: FailingHealthChecker()).execute(scene: .init(name: "Health", actions: [action]))
        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.actionRecords[0].errorCategory, .healthCheck)
    }

    func testDeactivationUsesOnlyStopPlan() async {
        let executor = RecordingExecutor()
        let scene = Scene(name: "Stop", actions: [process("start")], deactivationActions: [process("stop")])
        let result = await OrchestrationEngine(actionExecutor: executor).execute(scene: scene, deactivating: true)
        let starts = await executor.starts
        XCTAssertEqual(result.status, .stopped)
        XCTAssertEqual(starts, ["stop"])
        XCTAssertEqual(result.actionRecords.map(\.id), ["stop"])
    }

    func testFalseConditionSkipsActionWithoutSideEffect() async {
        let executor = RecordingExecutor()
        let configuration = ActionConfiguration(conditions: [.pathExists("/not-used")])
        let action = SceneAction.runProcess(.init(id: "conditional", executable: "/usr/bin/true", configuration: configuration))
        let engine = OrchestrationEngine(actionExecutor: executor, conditionEvaluator: FixedConditionEvaluator(value: false))
        let result = await engine.execute(scene: .init(name: "Conditions", actions: [action]))
        let starts = await executor.starts
        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.actionRecords[0].status, .skipped)
        XCTAssertTrue(starts.isEmpty)
    }

    func testAnyConditionModeAndDisabledConditionsUseOnlyEnabledRules() async {
        let executor = RecordingExecutor()
        let configuration = ActionConfiguration(conditions: [.pathExists("/false"), .pathExists("/true")], conditionEvaluationMode: .any, disabledConditionIndexes: [0])
        let action = SceneAction.runProcess(.init(id: "conditional", executable: "/usr/bin/true", configuration: configuration))

        let result = await OrchestrationEngine(actionExecutor: executor, conditionEvaluator: ConditionByPathEvaluator()).execute(scene: .init(name: "Any condition", actions: [action]))

        let starts = await executor.starts
        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(starts, ["conditional"])
    }

    func testOptionalHealthFailureProducesVisibleWarningWithoutFailingAction() async {
        let check = HealthCheck.file(.init(path: "/not-used", maximumAttempts: 1, required: false))
        let action = SceneAction.runProcess(.init(id: "health", executable: "/usr/bin/true", configuration: .init(healthChecks: [check])))

        let result = await OrchestrationEngine(actionExecutor: RecordingExecutor(), healthChecker: FailingHealthChecker()).execute(scene: .init(name: "Optional health", actions: [action]))

        XCTAssertEqual(result.status, .readyWithWarnings)
        XCTAssertEqual(result.actionRecords[0].status, .succeededWithWarning)
        XCTAssertEqual(result.actionRecords[0].healthChecks.first?.status, .failed)
    }

    func testLargeGraphHonorsConcurrencyBound() async {
        let executor = RecordingExecutor()
        let actions = (0..<60).map { process("node-\($0)") }
        let result = await OrchestrationEngine(actionExecutor: executor).execute(scene: .init(name: "Large", actions: actions, maximumConcurrency: 7))
        let maximum = await executor.maximumConcurrent
        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.completedActionCount, 60)
        XCTAssertEqual(maximum, 7)
    }

    private func process(_ id: String, dependencies: [String] = []) -> SceneAction {
        .runProcess(.init(id: id, executable: "/usr/bin/true", configuration: .init(dependencies: dependencies)))
    }
}

private actor FlakyExecutor: ActionExecuting {
    private let failuresBeforeSuccess: Int; private var attempts = 0
    init(failuresBeforeSuccess: Int) { self.failuresBeforeSuccess = failuresBeforeSuccess }
    func execute(_ action: SceneAction) async throws -> ActionExecutionOutcome { attempts += 1; if attempts <= failuresBeforeSuccess { throw OrchestrationFailure(category: .processExit, message: "retry", retryableCategory: .processExit) }; return .init() }
}
private struct AlwaysFailingExecutor: ActionExecuting { func execute(_ action: SceneAction) async throws -> ActionExecutionOutcome { throw OrchestrationFailure(category: .processExit, message: "retry", retryableCategory: .processExit) } }
private actor RecordingSleeper: OrchestrationSleeping { private(set) var values: [Double] = []; func sleep(seconds: TimeInterval) async throws { values.append(seconds) } }
private struct FailingHealthChecker: HealthCheckExecuting { func check(_ check: HealthCheck, resources: [ResourceRecord]) async throws -> String? { throw OrchestrationFailure(category: .healthCheck, message: "not ready", retryableCategory: .healthCheck) } }
private struct FixedConditionEvaluator: ActionConditionEvaluating { let value: Bool; func evaluate(_ condition: ActionCondition) async throws -> Bool { value } }
private struct ConditionByPathEvaluator: ActionConditionEvaluating { func evaluate(_ condition: ActionCondition) async throws -> Bool { if case .pathExists(let path) = condition { return path == "/true" }; return false } }

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
