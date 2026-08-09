import Foundation

public enum ActionRunStatus: String, Codable, Equatable, Sendable {
    case pending, running, succeeded, failed, cancelled, timedOut
}

public enum SceneRunStatus: String, Codable, Equatable, Sendable {
    case idle, running, succeeded, failed, cancelled
}

public struct ProcessExecutionResult: Codable, Equatable, Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
    public let startedAt: Date
    public let endedAt: Date
    public let timedOut: Bool
    public let cancelled: Bool

    public var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }

    public init(stdout: String, stderr: String, exitCode: Int32, startedAt: Date, endedAt: Date, timedOut: Bool, cancelled: Bool) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.timedOut = timedOut
        self.cancelled = cancelled
    }
}

public struct ActionExecutionRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public var status: ActionRunStatus
    public var startedAt: Date?
    public var endedAt: Date?
    public var errorMessage: String?
    public var processResult: ProcessExecutionResult?

    public var duration: TimeInterval? {
        guard let startedAt else { return nil }
        return (endedAt ?? Date()).timeIntervalSince(startedAt)
    }

    public init(id: String, name: String, status: ActionRunStatus = .pending) {
        self.id = id
        self.name = name
        self.status = status
    }
}

public struct SceneRunResult: Codable, Equatable, Sendable {
    public let sceneID: String
    public let sceneName: String
    public var status: SceneRunStatus
    public var actionRecords: [ActionExecutionRecord]
    public var startedAt: Date?
    public var endedAt: Date?
    public var failedActionID: String?
    public var errorMessage: String?

    public var currentAction: ActionExecutionRecord? {
        actionRecords.first(where: { $0.status == .running })
    }

    public var duration: TimeInterval? {
        guard let startedAt else { return nil }
        return (endedAt ?? Date()).timeIntervalSince(startedAt)
    }

    public init(scene: Scene) {
        sceneID = scene.id
        sceneName = scene.name
        status = .idle
        actionRecords = scene.actions.map { .init(id: $0.id, name: $0.displayName) }
    }
}
