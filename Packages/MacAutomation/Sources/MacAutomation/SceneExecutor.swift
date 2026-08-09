import Foundation
import SceneCore

public struct SceneExecutor: Sendable {
    public typealias UpdateHandler = @Sendable (SceneRunResult) async -> Void

    private let applicationOpener: any ApplicationOpening
    private let urlOpener: any URLOpening
    private let processRunner: any ProcessRunning

    public init(
        applicationOpener: any ApplicationOpening,
        urlOpener: any URLOpening,
        processRunner: any ProcessRunning
    ) {
        self.applicationOpener = applicationOpener
        self.urlOpener = urlOpener
        self.processRunner = processRunner
    }

    public func execute(scene: Scene, onUpdate: UpdateHandler? = nil) async -> SceneRunResult {
        var result = SceneRunResult(scene: scene)
        do {
            try SceneValidator.validate(scene)
        } catch {
            result.status = .failed
            result.errorMessage = error.localizedDescription
            result.endedAt = Date()
            await onUpdate?(result)
            return result
        }

        result.status = .running
        result.startedAt = Date()
        await onUpdate?(result)

        for (index, action) in scene.actions.enumerated() {
            if Task.isCancelled {
                cancel(&result, at: index)
                await onUpdate?(result)
                return result
            }

            result.actionRecords[index].status = .running
            result.actionRecords[index].startedAt = Date()
            await onUpdate?(result)

            do {
                switch action {
                case .openApplication(let value):
                    try await applicationOpener.openApplication(bundleIdentifier: value.bundleIdentifier)
                case .openURL(let value):
                    guard let url = URL(string: value.url) else {
                        throw AutomationError.urlOpenFailed(value.url)
                    }
                    try await urlOpener.openURL(url)
                case .runProcess(let value):
                    let processResult = try await processRunner.run(.init(
                        executable: value.executable,
                        arguments: value.arguments,
                        workingDirectory: value.workingDirectory,
                        timeoutSeconds: value.timeoutSeconds
                    ))
                    result.actionRecords[index].processResult = processResult
                    if processResult.cancelled || Task.isCancelled {
                        cancel(&result, at: index)
                        await onUpdate?(result)
                        return result
                    }
                    if processResult.timedOut {
                        result.actionRecords[index].status = .timedOut
                        throw ExecutionFailure("Process timed out after \(value.timeoutSeconds ?? 0) seconds.")
                    }
                    if processResult.exitCode != 0 {
                        throw ExecutionFailure("Process exited with status \(processResult.exitCode).")
                    }
                }

                result.actionRecords[index].status = .succeeded
                result.actionRecords[index].endedAt = Date()
                await onUpdate?(result)
            } catch {
                if Task.isCancelled {
                    cancel(&result, at: index)
                } else {
                    if result.actionRecords[index].status != .timedOut {
                        result.actionRecords[index].status = .failed
                    }
                    result.actionRecords[index].endedAt = Date()
                    result.actionRecords[index].errorMessage = error.localizedDescription
                    result.status = .failed
                    result.failedActionID = action.id
                    result.errorMessage = error.localizedDescription
                    result.endedAt = Date()
                }
                await onUpdate?(result)
                return result
            }
        }

        result.status = .succeeded
        result.endedAt = Date()
        await onUpdate?(result)
        return result
    }

    private func cancel(_ result: inout SceneRunResult, at index: Int) {
        if result.actionRecords.indices.contains(index) {
            result.actionRecords[index].status = .cancelled
            result.actionRecords[index].endedAt = Date()
        }
        result.status = .cancelled
        result.errorMessage = "Execution was cancelled."
        result.endedAt = Date()
    }
}

private struct ExecutionFailure: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
