import Foundation

public struct WorkspaceExecutionDefaults: Codable, Equatable, Sendable {
    public var maximumConcurrency: Int
    public var timeoutSeconds: Double?
    public var retryPolicy: RetryPolicy
    public var failurePolicy: FailurePolicy
    public var managedProcessGraceSeconds: Double

    public init(maximumConcurrency: Int = 3, timeoutSeconds: Double? = nil, retryPolicy: RetryPolicy = .init(), failurePolicy: FailurePolicy = .stopScene, managedProcessGraceSeconds: Double = 5) {
        self.maximumConcurrency = min(max(1, maximumConcurrency), 16)
        self.timeoutSeconds = timeoutSeconds.flatMap { $0 > 0 ? min($0, 86_400) : nil }
        self.retryPolicy = retryPolicy
        self.failurePolicy = failurePolicy
        self.managedProcessGraceSeconds = min(max(0.1, managedProcessGraceSeconds), 300)
    }

    public func newScene(named name: String) -> Scene {
        Scene(name: name, maximumConcurrency: maximumConcurrency, defaultFailurePolicy: failurePolicy)
    }

    public func applying(to action: SceneAction) -> SceneAction {
        var configuration = action.configuration
        configuration.timeoutSeconds = timeoutSeconds
        configuration.retryPolicy = retryPolicy
        configuration.failurePolicy = failurePolicy
        let updated = action.replacing(configuration: configuration)
        if case .managedProcess(var managed) = updated {
            managed.gracefulStopSeconds = managedProcessGraceSeconds
            return .managedProcess(managed)
        }
        return updated
    }
}
