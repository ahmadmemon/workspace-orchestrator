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
        return .init(outputSummary: Redactor.redact(summaries.joined(separator: "\n")))
    }
}

private extension SceneAction { var isDocker: Bool { if case .dockerCompose = self { true } else { false } } }
