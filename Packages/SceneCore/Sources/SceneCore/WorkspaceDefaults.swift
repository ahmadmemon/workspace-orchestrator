import Foundation

public enum DefaultOwnershipPolicy: String, Codable, CaseIterable, Sendable {
    case createdOnly
    case includeAdopted
}

public struct WorkspaceExecutionDefaults: Codable, Equatable, Sendable {
    public var maximumConcurrency: Int
    public var timeoutSeconds: Double?
    public var retryPolicy: RetryPolicy
    public var failurePolicy: FailurePolicy
    public var managedProcessGraceSeconds: Double
    public var managedProcessForcedStopSeconds: Double
    public var outputRetention: OutputRetentionPolicy
    public var healthCheckIntervalSeconds: Double
    public var healthCheckMaximumAttempts: Int
    public var ownershipPolicy: DefaultOwnershipPolicy

    public init(maximumConcurrency: Int = 3, timeoutSeconds: Double? = nil, retryPolicy: RetryPolicy = .init(), failurePolicy: FailurePolicy = .stopScene, managedProcessGraceSeconds: Double = 5, managedProcessForcedStopSeconds: Double = 2, outputRetention: OutputRetentionPolicy = .summary, healthCheckIntervalSeconds: Double = 1, healthCheckMaximumAttempts: Int = 10, ownershipPolicy: DefaultOwnershipPolicy = .createdOnly) {
        self.maximumConcurrency = min(max(1, maximumConcurrency), 16)
        self.timeoutSeconds = timeoutSeconds.flatMap { $0 > 0 ? min($0, 86_400) : nil }
        self.retryPolicy = retryPolicy
        self.failurePolicy = failurePolicy
        self.managedProcessGraceSeconds = min(max(0.1, managedProcessGraceSeconds), 300)
        self.managedProcessForcedStopSeconds = min(max(0.1, managedProcessForcedStopSeconds), 60)
        self.outputRetention = outputRetention
        self.healthCheckIntervalSeconds = min(max(0.1, healthCheckIntervalSeconds), 300)
        self.healthCheckMaximumAttempts = min(max(1, healthCheckMaximumAttempts), 100)
        self.ownershipPolicy = ownershipPolicy
    }

    private enum CodingKeys: String, CodingKey { case maximumConcurrency, timeoutSeconds, retryPolicy, failurePolicy, managedProcessGraceSeconds, managedProcessForcedStopSeconds, outputRetention, healthCheckIntervalSeconds, healthCheckMaximumAttempts, ownershipPolicy }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            maximumConcurrency: try container.decodeIfPresent(Int.self, forKey: .maximumConcurrency) ?? 3,
            timeoutSeconds: try container.decodeIfPresent(Double.self, forKey: .timeoutSeconds),
            retryPolicy: try container.decodeIfPresent(RetryPolicy.self, forKey: .retryPolicy) ?? .init(),
            failurePolicy: try container.decodeIfPresent(FailurePolicy.self, forKey: .failurePolicy) ?? .stopScene,
            managedProcessGraceSeconds: try container.decodeIfPresent(Double.self, forKey: .managedProcessGraceSeconds) ?? 5,
            managedProcessForcedStopSeconds: try container.decodeIfPresent(Double.self, forKey: .managedProcessForcedStopSeconds) ?? 2,
            outputRetention: try container.decodeIfPresent(OutputRetentionPolicy.self, forKey: .outputRetention) ?? .summary,
            healthCheckIntervalSeconds: try container.decodeIfPresent(Double.self, forKey: .healthCheckIntervalSeconds) ?? 1,
            healthCheckMaximumAttempts: try container.decodeIfPresent(Int.self, forKey: .healthCheckMaximumAttempts) ?? 10,
            ownershipPolicy: try container.decodeIfPresent(DefaultOwnershipPolicy.self, forKey: .ownershipPolicy) ?? .createdOnly
        )
    }

    public func newScene(named name: String) -> Scene {
        Scene(name: name, maximumConcurrency: maximumConcurrency, defaultFailurePolicy: failurePolicy)
    }

    public func applying(to action: SceneAction) -> SceneAction {
        var configuration = action.configuration
        configuration.timeoutSeconds = timeoutSeconds
        configuration.retryPolicy = retryPolicy
        configuration.failurePolicy = failurePolicy
        configuration.outputRetention = outputRetention
        let updated = action.replacing(configuration: configuration)
        if case .managedProcess(var managed) = updated {
            managed.gracefulStopSeconds = managedProcessGraceSeconds
            managed.forcedStopSeconds = managedProcessForcedStopSeconds
            return .managedProcess(managed)
        }
        return updated
    }
}
