import Foundation

public enum ActionRunStatus: String, Codable, Equatable, CaseIterable, Sendable {
    case pending, queued, waitingForDependencies, running, checking, retrying
    case succeeded, succeededWithWarning, skipped, failed, timedOut
    case cancelling, cancelled, interrupted, stopping, stopped

    public var isTerminal: Bool {
        switch self {
        case .succeeded, .succeededWithWarning, .skipped, .failed, .timedOut, .cancelled, .interrupted, .stopped: true
        default: false
        }
    }
}

public enum SceneRunStatus: String, Codable, Equatable, CaseIterable, Sendable {
    case idle, preparing, running, checking, retrying, ready, readyWithWarnings
    case failed, cancelling, cancelled, interrupted, stopping, stopped

    public var isActive: Bool {
        switch self {
        case .preparing, .running, .checking, .retrying, .cancelling, .stopping: true
        default: false
        }
    }
}

public enum UserFacingErrorCategory: String, Codable, CaseIterable, Sendable {
    case validation, permission, missingIntegration, missingFile, processLaunch, processExit
    case timeout, cancellation, healthCheck, windowRestoration, storage, migration, importFailure
    case securityApproval, docker, voice, audio, unknownInternal
}

public struct ProcessExecutionResult: Codable, Equatable, Sendable {
    public let stdout: String; public let stderr: String; public let exitCode: Int32
    public let startedAt: Date; public let endedAt: Date; public let timedOut: Bool; public let cancelled: Bool
    public var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }
    public init(stdout: String, stderr: String, exitCode: Int32, startedAt: Date, endedAt: Date, timedOut: Bool, cancelled: Bool) { self.stdout = stdout; self.stderr = stderr; self.exitCode = exitCode; self.startedAt = startedAt; self.endedAt = endedAt; self.timedOut = timedOut; self.cancelled = cancelled }
}

public struct ActionAttemptRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String; public var attempt: Int; public var startedAt: Date; public var endedAt: Date?
    public var reason: String?; public var status: ActionRunStatus; public var errorCategory: UserFacingErrorCategory?; public var errorMessage: String?
    public init(id: String = UUID().uuidString, attempt: Int, startedAt: Date = Date(), endedAt: Date? = nil, reason: String? = nil, status: ActionRunStatus = .running, errorCategory: UserFacingErrorCategory? = nil, errorMessage: String? = nil) { self.id = id; self.attempt = attempt; self.startedAt = startedAt; self.endedAt = endedAt; self.reason = reason; self.status = status; self.errorCategory = errorCategory; self.errorMessage = errorMessage }
}

public struct HealthCheckRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String; public var kind: String; public var attempt: Int; public var status: ActionRunStatus; public var message: String?; public var checkedAt: Date
    public init(id: String, kind: String, attempt: Int, status: ActionRunStatus, message: String? = nil, checkedAt: Date = Date()) { self.id = id; self.kind = kind; self.attempt = attempt; self.status = status; self.message = message; self.checkedAt = checkedAt }
}

public enum ResourceOwnership: String, Codable, Sendable { case created, adopted, unknown }
public struct ResourceRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String; public var actionID: String; public var kind: String; public var identifier: String; public var ownership: ResourceOwnership; public var stopped: Bool
    public init(id: String = UUID().uuidString, actionID: String, kind: String, identifier: String, ownership: ResourceOwnership, stopped: Bool = false) { self.id = id; self.actionID = actionID; self.kind = kind; self.identifier = identifier; self.ownership = ownership; self.stopped = stopped }
}

public struct ActionExecutionRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: String; public let name: String; public var status: ActionRunStatus
    public var startedAt: Date?; public var endedAt: Date?; public var attemptNumber: Int
    public var retryReason: String?; public var dependencyState: String?; public var healthChecks: [HealthCheckRecord]
    public var errorCategory: UserFacingErrorCategory?; public var errorMessage: String?; public var processResult: ProcessExecutionResult?
    public var outputSummary: String?; public var skipReason: String?; public var ownsResource: Bool; public var attempts: [ActionAttemptRecord]
    public var duration: TimeInterval? { guard let startedAt else { return nil }; return (endedAt ?? Date()).timeIntervalSince(startedAt) }
    public init(id: String, name: String, status: ActionRunStatus = .pending) { self.id = id; self.name = name; self.status = status; startedAt = nil; endedAt = nil; attemptNumber = 0; retryReason = nil; dependencyState = nil; healthChecks = []; errorCategory = nil; errorMessage = nil; processResult = nil; outputSummary = nil; skipReason = nil; ownsResource = false; attempts = [] }
}

public struct SceneRunResult: Codable, Equatable, Identifiable, Sendable {
    public var id: String; public let sceneID: String; public let sceneName: String; public let sceneSchemaVersion: Int
    public var status: SceneRunStatus; public var actionRecords: [ActionExecutionRecord]; public var resources: [ResourceRecord]
    public var startedAt: Date?; public var endedAt: Date?; public var failedActionID: String?; public var errorCategory: UserFacingErrorCategory?; public var errorMessage: String?
    public var appVersion: String; public var interruptionState: String?
    public var currentAction: ActionExecutionRecord? { actionRecords.first { [.running, .checking, .retrying, .stopping].contains($0.status) } }
    public var duration: TimeInterval? { guard let startedAt else { return nil }; return (endedAt ?? Date()).timeIntervalSince(startedAt) }
    public var completedActionCount: Int { actionRecords.filter { $0.status.isTerminal }.count }
    public var warningCount: Int { actionRecords.filter { $0.status == .succeededWithWarning }.count }
    public var failureCount: Int { actionRecords.filter { [.failed, .timedOut].contains($0.status) }.count }
    public init(scene: Scene, id: String = UUID().uuidString, appVersion: String = "unknown") { self.id = id; sceneID = scene.id; sceneName = scene.name; sceneSchemaVersion = scene.schemaVersion; status = .idle; actionRecords = scene.actions.map { .init(id: $0.id, name: $0.displayName) }; resources = []; startedAt = nil; endedAt = nil; failedActionID = nil; errorCategory = nil; errorMessage = nil; self.appVersion = appVersion; interruptionState = nil }
}
