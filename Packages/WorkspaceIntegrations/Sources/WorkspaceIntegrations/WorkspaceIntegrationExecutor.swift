import Foundation
import MacAutomation
import OrchestrationEngine
import SceneCore

public struct WorkspaceIntegrationExecutor: ActionExecuting {
    private let processRunner: any ProcessRunning; private let builder: IntegrationCommandBuilder
    public init(processRunner: any ProcessRunning, builder: IntegrationCommandBuilder = .init()) { self.processRunner = processRunner; self.builder = builder }
    public func execute(_ action: SceneAction) async throws -> ActionExecutionOutcome {
        let requests: [ProcessRequest]
        switch action {
        case .editorWorkspace(let value): requests = [try builder.editor(value)]
        case .terminalWorkspace(let value): requests = [try builder.tmuxEnsure(value), builder.terminalOpen(value)].compactMap { $0 }
        case .dockerCompose(let value): requests = [try builder.dockerUp(value)]
        case .shortcut(let value): requests = [try builder.shortcut(value)]
        default: throw OrchestrationFailure(category: .missingIntegration, message: "\(action.displayName) is not handled by WorkspaceIntegrations.")
        }
        var summaries: [String] = []
        for request in requests { let result = try await processRunner.run(request); if result.timedOut { throw OrchestrationFailure(category: .timeout, message: "Integration command timed out.", retryableCategory: .timeout, processResult: result) }; if result.cancelled { throw CancellationError() }; if result.exitCode != 0 { throw OrchestrationFailure(category: action.isDocker ? .docker : .processExit, message: "Integration command exited with status \(result.exitCode).", retryableCategory: .processExit, processResult: result) }; summaries.append(result.stdout + result.stderr) }
        let resources: [ResourceRecord]
        if case .dockerCompose(let value) = action { resources = [.init(actionID: value.id, kind: "dockerCompose", identifier: try DockerResourceIdentity(value).encoded, ownership: .created)] }
        else { resources = [] }
        return .init(outputSummary: Redactor.redact(summaries.joined(separator: "\n")), resources: resources)
    }
}

public struct DockerIntegrationHealthChecker: HealthCheckExecuting {
    private let processRunner: any ProcessRunning; private let builder: IntegrationCommandBuilder
    public init(processRunner: any ProcessRunning, builder: IntegrationCommandBuilder = .init()) { self.processRunner = processRunner; self.builder = builder }
    public func check(_ check: HealthCheck, resources: [ResourceRecord]) async throws -> String? {
        guard case .docker(let value) = check else { throw OrchestrationFailure(category: .missingIntegration, message: "This adapter handles Docker health checks only.") }
        guard let resource = resources.last(where: { $0.actionID == value.composeActionID && $0.kind == "dockerCompose" }), let compose = try? DockerResourceIdentity.decode(resource.identifier).action else { throw OrchestrationFailure(category: .healthCheck, message: "Docker Compose ownership information is unavailable.", retryableCategory: .healthCheck) }
        let result = try await processRunner.run(builder.dockerStatus(compose, service: value.service))
        guard result.exitCode == 0 else { throw OrchestrationFailure(category: .docker, message: "Docker service status exited with \(result.exitCode).", retryableCategory: .healthCheck, processResult: result) }
        let bounded = String((result.stdout + result.stderr).prefix(65_536))
        guard bounded.localizedCaseInsensitiveContains("running") else { throw OrchestrationFailure(category: .healthCheck, message: "Docker service is not running.", retryableCategory: .healthCheck) }
        if value.requireHealthy, !bounded.localizedCaseInsensitiveContains("healthy") { throw OrchestrationFailure(category: .healthCheck, message: "Docker service is running but not healthy.", retryableCategory: .healthCheck) }
        return value.requireHealthy ? "Docker service is healthy" : "Docker service is running"
    }
}

private struct DockerResourceIdentity: Codable {
    let action: DockerComposeAction
    init(_ action: DockerComposeAction) { self.action = action }
    var encoded: String { get throws { try JSONEncoder().encode(self).base64EncodedString() } }
    static func decode(_ value: String) throws -> DockerResourceIdentity { guard let data = Data(base64Encoded: value) else { throw IntegrationCommandError.invalidField("Docker resource identity is invalid") }; return try JSONDecoder().decode(Self.self, from: data) }
}

private extension SceneAction { var isDocker: Bool { if case .dockerCompose = self { true } else { false } } }
