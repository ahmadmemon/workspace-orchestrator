import Foundation

public enum RunHistoryDatePreset: String, CaseIterable, Sendable {
    case all, today, last7Days, last30Days, custom
}

public struct RunHistoryFilter: Equatable, Sendable {
    public var query: String
    public var sceneID: String?
    public var status: SceneRunStatus?
    public var datePreset: RunHistoryDatePreset
    public var customStart: Date?
    public var customEnd: Date?

    public init(query: String = "", sceneID: String? = nil, status: SceneRunStatus? = nil, datePreset: RunHistoryDatePreset = .all, customStart: Date? = nil, customEnd: Date? = nil) {
        self.query = query
        self.sceneID = sceneID
        self.status = status
        self.datePreset = datePreset
        self.customStart = customStart
        self.customEnd = customEnd
    }
}

public enum RunHistoryFiltering {
    public static func filter(_ runs: [SceneRunResult], using filter: RunHistoryFilter, calendar: Calendar = .current, now: Date = Date()) -> [SceneRunResult] {
        let interval = dateInterval(for: filter, calendar: calendar, now: now)
        return runs.filter { run in
            let matchesQuery = filter.query.isEmpty || run.sceneName.localizedCaseInsensitiveContains(filter.query)
            let matchesScene = filter.sceneID == nil || run.sceneID == filter.sceneID
            let matchesStatus = filter.status == nil || run.status == filter.status
            let matchesDate = interval == nil || run.startedAt.map { interval!.contains($0) } == true
            return matchesQuery && matchesScene && matchesStatus && matchesDate
        }
    }

    public static func dateInterval(for filter: RunHistoryFilter, calendar: Calendar = .current, now: Date = Date()) -> DateInterval? {
        let today = calendar.startOfDay(for: now)
        switch filter.datePreset {
        case .all:
            return nil
        case .today:
            return DateInterval(start: today, end: calendar.date(byAdding: .day, value: 1, to: today) ?? now)
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -6, to: today) ?? .distantPast
            return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: today) ?? now)
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -29, to: today) ?? .distantPast
            return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: today) ?? now)
        case .custom:
            guard let customStart = filter.customStart, let customEnd = filter.customEnd else { return nil }
            let start = calendar.startOfDay(for: min(customStart, customEnd))
            let endDay = calendar.startOfDay(for: max(customStart, customEnd))
            let end = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
            return DateInterval(start: start, end: end)
        }
    }
}

public enum HistoricalRetryScope: String, CaseIterable, Sendable {
    case fullSnapshot, failedAndDependents
}

public struct HistoricalRetryPlan: Equatable, Sendable {
    public var sourceRunID: String
    public var scope: HistoricalRetryScope
    public var scene: Scene
    public var includedActionIDs: [String]
    public var assumedSuccessfulDependencyIDs: [String]
}

public enum HistoricalRunError: LocalizedError, Equatable {
    case snapshotUnavailable
    case noFailedActions

    public var errorDescription: String? {
        switch self {
        case .snapshotUnavailable: "This older run does not contain a scene snapshot. Open the current scene and review it instead."
        case .noFailedActions: "This run has no failed or timed-out actions to retry."
        }
    }
}

public enum HistoricalRunPlanner {
    public static func retryPlan(for run: SceneRunResult, scope: HistoricalRetryScope) throws -> HistoricalRetryPlan {
        guard var snapshot = run.sceneSnapshot else { throw HistoricalRunError.snapshotUnavailable }
        let originalActions = snapshot.actions
        let originalIDs = Set(originalActions.map(\.id))
        let included: Set<String>
        var assumed: Set<String> = []

        switch scope {
        case .fullSnapshot:
            included = originalIDs
        case .failedAndDependents:
            let failed = Set(run.actionRecords.filter { [.failed, .timedOut].contains($0.status) }.map(\.id))
            guard !failed.isEmpty else { throw HistoricalRunError.noFailedActions }
            var result = failed
            var changed = true
            while changed {
                changed = false
                for action in originalActions where !result.contains(action.id) && !result.isDisjoint(with: action.configuration.dependencies) {
                    result.insert(action.id)
                    changed = true
                }
            }
            included = result
            for action in originalActions where included.contains(action.id) {
                assumed.formUnion(action.configuration.dependencies.filter { !included.contains($0) })
            }
        }

        snapshot.id = UUID().uuidString
        snapshot.name += scope == .fullSnapshot ? " (Historical Retry)" : " (Failed Actions Retry)"
        snapshot.createdAt = Date()
        snapshot.updatedAt = snapshot.createdAt
        snapshot.trustState = .local
        snapshot.actions = originalActions.filter { included.contains($0.id) }.map { action in
            var configuration = action.configuration
            configuration.dependencies = configuration.dependencies.filter { included.contains($0) }
            return action.replacing(configuration: configuration).clearingStoredApproval()
        }
        return .init(sourceRunID: run.id, scope: scope, scene: snapshot, includedActionIDs: snapshot.actions.map(\.id), assumedSuccessfulDependencyIDs: assumed.sorted())
    }

    public static func sceneCopy(from run: SceneRunResult) throws -> Scene {
        guard var scene = run.sceneSnapshot else { throw HistoricalRunError.snapshotUnavailable }
        let now = Date()
        scene.id = UUID().uuidString
        scene.name += " (From History)"
        scene.createdAt = now
        scene.updatedAt = now
        scene.trustState = .local
        scene.actions = scene.actions.map { $0.clearingStoredApproval() }
        scene.deactivationActions = scene.deactivationActions.map { $0.clearingStoredApproval() }
        return scene
    }
}

public struct RunDiagnosticExport: Sendable {
    public static func text(for run: SceneRunResult) -> String {
        var lines = [
            "Workspace Orchestrator Run Diagnostic",
            "Review before sharing: paths, scene names, URLs, and application identifiers may be private.",
            "Run: \(run.id)",
            "Scene: \(Redactor.redact(run.sceneName)) (\(run.sceneID))",
            "Status: \(run.status.rawValue)",
            "Started: \(run.startedAt.map(String.init(describing:)) ?? "unknown")",
            "Ended: \(run.endedAt.map(String.init(describing:)) ?? "unknown")",
            "App version: \(run.appVersion)",
            ""
        ]
        for record in run.actionRecords {
            lines.append("Action: \(Redactor.redact(record.name)) [\(record.id)]")
            lines.append("Status: \(record.status.rawValue); attempts: \(record.attempts.count); duration: \(record.duration.map { String(format: "%.3fs", $0) } ?? "unknown")")
            if let dependencyState = record.dependencyState { lines.append("Dependencies: \(Redactor.redact(dependencyState))") }
            if let error = record.errorMessage { lines.append("Error: \(Redactor.redact(error))") }
            if let result = record.processResult {
                lines.append("Process exit: \(result.exitCode); timed out: \(result.timedOut); cancelled: \(result.cancelled)")
                if !result.stdout.isEmpty { lines.append("stdout:\n\(Redactor.redact(result.stdout))") }
                if !result.stderr.isEmpty { lines.append("stderr:\n\(Redactor.redact(result.stderr))") }
            } else if let output = record.outputSummary {
                lines.append("Output summary:\n\(Redactor.redact(output))")
            }
            if record.outputTruncated == true { lines.append("Output was truncated by the configured history limit.") }
            for check in record.healthChecks {
                lines.append("Health check \(check.kind) attempt \(check.attempt): \(check.status.rawValue) \(Redactor.redact(check.message ?? ""))")
            }
            lines.append("")
        }
        return Redactor.redact(lines.joined(separator: "\n"))
    }
}

public extension SceneAction {
    func replacing(configuration: ActionConfiguration) -> SceneAction {
        switch self {
        case .openApplication(var value): value.configuration = configuration; return .openApplication(value)
        case .openURL(var value): value.configuration = configuration; return .openURL(value)
        case .openFile(var value): value.configuration = configuration; return .openFile(value)
        case .runProcess(var value): value.configuration = configuration; return .runProcess(value)
        case .managedProcess(var value): value.configuration = configuration; return .managedProcess(value)
        case .wait(var value): value.configuration = configuration; return .wait(value)
        case .editorWorkspace(var value): value.configuration = configuration; return .editorWorkspace(value)
        case .terminalWorkspace(var value): value.configuration = configuration; return .terminalWorkspace(value)
        case .dockerCompose(var value): value.configuration = configuration; return .dockerCompose(value)
        case .shortcut(var value): value.configuration = configuration; return .shortcut(value)
        case .windowLayout(var value): value.configuration = configuration; return .windowLayout(value)
        }
    }

    func clearingStoredApproval() -> SceneAction {
        switch self {
        case .runProcess(var value): value.approvalFingerprint = nil; return .runProcess(value)
        case .managedProcess(var value): value.approvalFingerprint = nil; return .managedProcess(value)
        default: return self
        }
    }
}
