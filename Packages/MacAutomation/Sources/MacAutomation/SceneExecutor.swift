import Foundation
import OrchestrationEngine
import SceneCore

public struct SceneExecutor: Sendable {
    public typealias UpdateHandler = @Sendable (SceneRunResult) async -> Void
    private let engine: OrchestrationEngine
    public init(applicationOpener: any ApplicationOpening, urlOpener: any URLOpening, processRunner: any ProcessRunning, fileOpener: (any FileOpening)? = nil) {
        engine = OrchestrationEngine(actionExecutor: NativeActionExecutor(applicationOpener: applicationOpener, urlOpener: urlOpener, processRunner: processRunner, fileOpener: fileOpener))
    }
    public func execute(scene: Scene, onUpdate: UpdateHandler? = nil) async -> SceneRunResult { await engine.execute(scene: scene, onUpdate: onUpdate) }
    public func deactivate(scene: Scene, onUpdate: UpdateHandler? = nil) async -> SceneRunResult { await engine.execute(scene: scene, deactivating: true, onUpdate: onUpdate) }
}

private struct NativeActionExecutor: ActionExecuting {
    let applicationOpener: any ApplicationOpening; let urlOpener: any URLOpening; let processRunner: any ProcessRunning; let fileOpener: (any FileOpening)?
    func execute(_ action: SceneAction) async throws -> ActionExecutionOutcome {
        switch action {
        case .openApplication(let value): try await applicationOpener.openApplication(bundleIdentifier: value.bundleIdentifier); return .init(resources: [.init(actionID: value.id, kind: "application", identifier: value.bundleIdentifier, ownership: .unknown)])
        case .openURL(let value):
            var opened = Set<String>()
            for urlString in value.urls where !value.deduplicateWithinRun || opened.insert(urlString).inserted { guard let url = URL(string: urlString) else { throw OrchestrationFailure(category: .validation, message: "Invalid URL \(urlString).") }; try await urlOpener.openURL(url); if value.delayBetweenURLsSeconds > 0 { try await Task.sleep(for: .seconds(value.delayBetweenURLsSeconds)) } }
            return .init()
        case .openFile(let value): guard let fileOpener else { throw OrchestrationFailure(category: .missingIntegration, message: "File opening adapter is unavailable.") }; try await fileOpener.openFile(at: URL(fileURLWithPath: value.path), applicationBundleIdentifier: value.applicationBundleIdentifier, revealInFinder: value.openPolicy == .revealInFinder); return .init()
        case .runProcess(let value):
            let environment = try plainEnvironment(value.environment)
            let process = try await processRunner.run(.init(executable: value.executable, arguments: value.arguments, workingDirectory: value.workingDirectory, timeoutSeconds: value.timeoutSeconds ?? value.configuration.timeoutSeconds, environment: environment))
            if process.cancelled || Task.isCancelled { throw CancellationError() }
            if process.timedOut { throw OrchestrationFailure(category: .timeout, message: "Process timed out.", retryableCategory: .timeout) }
            if !value.expectedExitCodes.contains(process.exitCode) { throw OrchestrationFailure(category: .processExit, message: "Process exited with status \(process.exitCode).", retryableCategory: .processExit, processResult: process) }
            return .init(processResult: process, outputSummary: Redactor.redact(process.stdout + process.stderr, configuration: .init(customPatterns: value.redactionPatterns)))
        case .wait: return .init()
        default: throw OrchestrationFailure(category: .missingIntegration, message: "\(action.displayName) is not configured by the base macOS executor.", retryableCategory: .missingIntegration)
        }
    }
    private func plainEnvironment(_ values: [String: EnvironmentValue]) throws -> [String: String] {
        var result: [String: String] = [:]
        for (name, value) in values { switch value { case .plain(let plain): result[name] = plain; case .secretReference: throw OrchestrationFailure(category: .securityApproval, message: "A Keychain resolver is required for secret environment values."); case .inherited: if let inherited = ProcessInfo.processInfo.environment[name] { result[name] = inherited } } }
        return result
    }
}
