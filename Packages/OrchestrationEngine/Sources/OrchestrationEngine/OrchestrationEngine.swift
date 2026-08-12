import Foundation
import SceneCore

public struct ActionExecutionOutcome: Sendable {
    public var processResult: ProcessExecutionResult?; public var outputSummary: String?; public var resources: [ResourceRecord]
    public init(processResult: ProcessExecutionResult? = nil, outputSummary: String? = nil, resources: [ResourceRecord] = []) { self.processResult = processResult; self.outputSummary = outputSummary; self.resources = resources }
}

public struct OrchestrationFailure: LocalizedError, Sendable {
    public var category: UserFacingErrorCategory; public var message: String; public var retryableCategory: RetryableErrorCategory?; public var processResult: ProcessExecutionResult?
    public init(category: UserFacingErrorCategory, message: String, retryableCategory: RetryableErrorCategory? = nil, processResult: ProcessExecutionResult? = nil) { self.category = category; self.message = message; self.retryableCategory = retryableCategory; self.processResult = processResult }
    public var errorDescription: String? { message }
}

public protocol ActionExecuting: Sendable { func execute(_ action: SceneAction) async throws -> ActionExecutionOutcome }
public protocol HealthCheckExecuting: Sendable { func check(_ check: HealthCheck, resources: [ResourceRecord]) async throws -> String? }
public protocol OrchestrationSleeping: Sendable { func sleep(seconds: TimeInterval) async throws }
public protocol JitterSourcing: Sendable { func unitValue(actionID: String, attempt: Int) -> Double }
public protocol ActionConditionEvaluating: Sendable { func evaluate(_ condition: ActionCondition) async throws -> Bool }

public struct ContinuousOrchestrationSleeper: OrchestrationSleeping { public init() {} ; public func sleep(seconds: TimeInterval) async throws { try await Task.sleep(for: .seconds(seconds)) } }
public struct DeterministicJitterSource: JitterSourcing {
    public init() {}
    public func unitValue(actionID: String, attempt: Int) -> Double { let value = actionID.utf8.reduce(UInt64(attempt)) { ($0 &* 1_099_511_628_211) ^ UInt64($1) }; return Double(value % 10_000) / 10_000 }
}
public struct NoHealthChecks: HealthCheckExecuting { public init() {} ; public func check(_ check: HealthCheck, resources: [ResourceRecord]) async throws -> String? { nil } }
public struct LocalActionConditionEvaluator: ActionConditionEvaluating {
    public init() {}
    public func evaluate(_ condition: ActionCondition) async throws -> Bool {
        switch condition {
        case .pathExists(let path): return FileManager.default.fileExists(atPath: path)
        case .environmentEquals(let name, let value): return ProcessInfo.processInfo.environment[name] == value
        }
    }
}

public struct OrchestrationEngine: Sendable {
    public typealias UpdateHandler = @Sendable (SceneRunResult) async -> Void
    private let actionExecutor: any ActionExecuting; private let healthChecker: any HealthCheckExecuting; private let sleeper: any OrchestrationSleeping; private let jitter: any JitterSourcing; private let conditionEvaluator: any ActionConditionEvaluating; private let appVersion: String
    public init(actionExecutor: any ActionExecuting, healthChecker: any HealthCheckExecuting = NoHealthChecks(), sleeper: any OrchestrationSleeping = ContinuousOrchestrationSleeper(), jitter: any JitterSourcing = DeterministicJitterSource(), conditionEvaluator: any ActionConditionEvaluating = LocalActionConditionEvaluator(), appVersion: String = "unknown") { self.actionExecutor = actionExecutor; self.healthChecker = healthChecker; self.sleeper = sleeper; self.jitter = jitter; self.conditionEvaluator = conditionEvaluator; self.appVersion = appVersion }

    public func execute(scene: Scene, deactivating: Bool = false, onUpdate: UpdateHandler? = nil) async -> SceneRunResult {
        var effective = scene
        if deactivating { effective.actions = scene.deactivationActions }
        var result = SceneRunResult(scene: effective, appVersion: appVersion)
        do { try SceneValidator.validate(scene) } catch { result.status = .failed; result.errorCategory = .validation; result.errorMessage = error.localizedDescription; result.endedAt = Date(); await onUpdate?(result); return result }
        result.status = deactivating ? .stopping : .preparing; result.startedAt = Date(); await onUpdate?(result)
        if effective.actions.isEmpty { result.status = deactivating ? .stopped : .ready; result.endedAt = Date(); await onUpdate?(result); return result }
        result.status = deactivating ? .stopping : .running; await onUpdate?(result)

        let actions = Dictionary(uniqueKeysWithValues: effective.actions.map { ($0.id, $0) })
        var remaining = Set(actions.keys); var finished: [String: ActionRunStatus] = [:]; var halt = false; var degraded = false
        while !remaining.isEmpty && !halt {
            if Task.isCancelled { markCancelled(&result, remaining: remaining); await onUpdate?(result); return result }
            var skipped: [String] = []
            for id in remaining.sorted() {
                guard let action = actions[id] else { continue }
                if !action.configuration.enabled { skipped.append(id); update(&result, id: id) { $0.status = .skipped; $0.skipReason = "Action is disabled."; $0.endedAt = Date() }; continue }
                let failedDependencies = action.configuration.dependencies.filter { dep in guard let state = finished[dep] else { return false }; return ![.succeeded, .succeededWithWarning, .skipped].contains(state) }
                if !failedDependencies.isEmpty { skipped.append(id); update(&result, id: id) { $0.status = .skipped; $0.skipReason = "Required dependency failed: \(failedDependencies.joined(separator: ", "))."; $0.dependencyState = "blocked"; $0.endedAt = Date() } }
            }
            for id in skipped { remaining.remove(id); finished[id] = .skipped }
            if !skipped.isEmpty { await onUpdate?(result) }

            let runnable = effective.actions.map(\.id).filter { id in guard remaining.contains(id), let action = actions[id] else { return false }; return action.configuration.dependencies.allSatisfy { finished[$0] != nil } }
            if runnable.isEmpty {
                for id in remaining { update(&result, id: id) { $0.status = .failed; $0.errorCategory = .validation; $0.errorMessage = "No schedulable dependency path remained." } }
                result.status = .failed; result.errorCategory = .validation; result.errorMessage = "The action graph could not make progress."; result.endedAt = Date(); await onUpdate?(result); return result
            }
            let batch = Array(runnable.prefix(effective.maximumConcurrency))
            for id in batch { update(&result, id: id) { $0.status = .queued; $0.dependencyState = "dependencies satisfied" } }
            await onUpdate?(result)
            let priorResources = result.resources
            let completed: [(String, ActionResult)] = await withTaskGroup(of: (String, ActionResult).self, returning: [(String, ActionResult)].self) { group in
                for id in batch { if let action = actions[id] { group.addTask { (id, await executeAction(action, priorResources: priorResources)) } } }
                var values: [(String, ActionResult)] = []; for await value in group { values.append(value) }; return values.sorted { $0.0 < $1.0 }
            }
            var batchCancelled = false
            for (id, completion) in completed {
                remaining.remove(id); finished[id] = completion.record.status
                if let index = result.actionRecords.firstIndex(where: { $0.id == id }) { result.actionRecords[index] = completion.record }
                result.resources.append(contentsOf: completion.resources)
                guard let action = actions[id] else { continue }
                switch completion.record.status {
                case .cancelled: batchCancelled = true
                case .failed, .timedOut:
                    switch action.configuration.failurePolicy {
                    case .stopScene: halt = true; result.failedActionID = id; result.errorCategory = completion.record.errorCategory; result.errorMessage = completion.record.errorMessage
                    case .continueDegraded, .skipDependents: degraded = true
                    case .continueOptional: break
                    }
                case .succeededWithWarning: if action.configuration.failurePolicy != .continueOptional { degraded = true }
                default: break
                }
            }
            await onUpdate?(result)
            if batchCancelled || Task.isCancelled { markCancelled(&result, remaining: remaining); await onUpdate?(result); return result }
        }
        if halt {
            for id in remaining { update(&result, id: id) { $0.status = .skipped; $0.skipReason = "Scene stopped after required failure."; $0.endedAt = Date() } }
            result.status = .failed
        } else { result.status = deactivating ? .stopped : (degraded ? .readyWithWarnings : .ready) }
        result.endedAt = Date(); await onUpdate?(result); return result
    }

    private func executeAction(_ action: SceneAction, priorResources: [ResourceRecord]) async -> ActionResult {
        var record = ActionExecutionRecord(id: action.id, name: action.displayName, status: .running); record.startedAt = Date()
        do {
            let enabledConditions = action.configuration.conditions.enumerated().filter { !action.configuration.disabledConditionIndexes.contains($0.offset) }.map(\.element)
            var conditionSatisfied = true
            if !enabledConditions.isEmpty {
                switch action.configuration.conditionEvaluationMode {
                case .all:
                    conditionSatisfied = true
                    for condition in enabledConditions where conditionSatisfied { conditionSatisfied = try await conditionEvaluator.evaluate(condition) }
                case .any:
                    conditionSatisfied = false
                    for condition in enabledConditions where !conditionSatisfied { conditionSatisfied = try await conditionEvaluator.evaluate(condition) }
                }
            }
            if !conditionSatisfied {
                record.status = .skipped; record.skipReason = "The enabled \(action.configuration.conditionEvaluationMode.rawValue) condition rule was not satisfied."; record.endedAt = Date(); return .init(record: record, resources: [])
            }
        } catch {
            record.status = .failed; record.errorCategory = .validation; record.errorMessage = "Condition evaluation failed: \(error.localizedDescription)"; record.endedAt = Date(); return .init(record: record, resources: [])
        }
        let policy = action.configuration.retryPolicy; let totalStart = Date()
        for attempt in 1...max(1, policy.maximumAttempts) {
            if Task.isCancelled { record.status = .cancelled; record.errorCategory = .cancellation; record.errorMessage = "Execution was cancelled."; record.endedAt = Date(); return .init(record: record, resources: []) }
            record.attemptNumber = attempt; record.status = attempt == 1 ? .running : .retrying
            var attemptRecord = ActionAttemptRecord(attempt: attempt, reason: record.retryReason)
            do {
                if attempt > 1 { let delay = policy.delay(beforeAttempt: attempt, deterministicUnit: jitter.unitValue(actionID: action.id, attempt: attempt)); if Date().timeIntervalSince(totalStart) + delay > policy.maximumTotalDurationSeconds { throw OrchestrationFailure(category: .timeout, message: "Maximum retry duration exceeded.", retryableCategory: nil) }; try await sleeper.sleep(seconds: delay) }
                let outcome: ActionExecutionOutcome
                if case .wait(let wait) = action { try await sleeper.sleep(seconds: wait.durationSeconds); outcome = .init() } else { outcome = try await actionExecutor.execute(action) }
                record.processResult = outcome.processResult; record.outputSummary = outcome.outputSummary.map { Redactor.redact($0) }
                var optionalHealthWarning = false
                if !action.configuration.healthChecks.isEmpty {
                    record.status = .checking
                    for check in action.configuration.healthChecks {
                        do {
                            let message = try await healthChecker.check(check, resources: priorResources + outcome.resources)
                            record.healthChecks.append(.init(id: check.id, kind: String(describing: check), attempt: attempt, status: .succeeded, message: message))
                        } catch {
                            record.healthChecks.append(.init(id: check.id, kind: String(describing: check), attempt: attempt, status: .failed, message: Redactor.redact(error.localizedDescription)))
                            if check.isRequired { throw error }
                            optionalHealthWarning = true
                        }
                    }
                }
                record.status = optionalHealthWarning ? .succeededWithWarning : .succeeded; record.ownsResource = outcome.resources.contains { $0.ownership == .created }; record.endedAt = Date(); attemptRecord.status = record.status; attemptRecord.endedAt = Date(); record.attempts.append(attemptRecord); return .init(record: record, resources: outcome.resources)
            } catch {
                if error is CancellationError || Task.isCancelled { attemptRecord.status = .cancelled; attemptRecord.errorCategory = .cancellation; attemptRecord.errorMessage = "Execution was cancelled."; attemptRecord.endedAt = Date(); record.attempts.append(attemptRecord); record.status = .cancelled; record.errorCategory = .cancellation; record.errorMessage = "Execution was cancelled."; record.endedAt = Date(); return .init(record: record, resources: []) }
                let failure = error as? OrchestrationFailure ?? .init(category: .unknownInternal, message: error.localizedDescription)
                record.processResult = failure.processResult
                attemptRecord.status = failure.category == .timeout ? .timedOut : .failed; attemptRecord.errorCategory = failure.category; attemptRecord.errorMessage = Redactor.redact(failure.message); attemptRecord.endedAt = Date(); record.attempts.append(attemptRecord)
                let retryable = failure.retryableCategory.map { policy.retryableCategories.contains($0) } ?? false
                if attempt < policy.maximumAttempts, policy.strategy != .none, retryable { record.retryReason = failure.message; continue }
                record.status = failure.category == .timeout ? .timedOut : .failed; record.errorCategory = failure.category; record.errorMessage = Redactor.redact(failure.message); record.endedAt = Date(); return .init(record: record, resources: [])
            }
        }
        record.status = .failed; record.errorCategory = .unknownInternal; record.errorMessage = "Retry policy completed without a result."; record.endedAt = Date(); return .init(record: record, resources: [])
    }

    private func update(_ result: inout SceneRunResult, id: String, body: (inout ActionExecutionRecord) -> Void) { guard let index = result.actionRecords.firstIndex(where: { $0.id == id }) else { return }; body(&result.actionRecords[index]) }
    private func markCancelled(_ result: inout SceneRunResult, remaining: Set<String>) { for id in remaining { update(&result, id: id) { $0.status = .cancelled; $0.errorCategory = .cancellation; $0.errorMessage = "Execution was cancelled."; $0.endedAt = Date() } }; result.status = .cancelled; result.errorCategory = .cancellation; result.errorMessage = "Execution was cancelled."; result.endedAt = Date() }
    private struct ActionResult: Sendable { var record: ActionExecutionRecord; var resources: [ResourceRecord] }
}
