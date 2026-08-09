import Foundation
import SceneCore

private final class ProcessTerminationState: @unchecked Sendable {
    private let lock = NSLock()
    private var _timedOut = false
    private var _cancelled = false

    var timedOut: Bool { lock.withLock { _timedOut } }
    var cancelled: Bool { lock.withLock { _cancelled } }
    func markTimedOut() { lock.withLock { _timedOut = true } }
    func markCancelled() { lock.withLock { _cancelled = true } }
}

public struct FoundationProcessRunner: ProcessRunning {
    public init() {}

    public func run(_ request: ProcessRequest) async throws -> ProcessExecutionResult {
        guard FileManager.default.isExecutableFile(atPath: request.executable) else {
            throw AutomationError.executableNotFound(request.executable)
        }
        if let directory = request.workingDirectory {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw AutomationError.workingDirectoryNotFound(directory)
            }
        }

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: request.executable)
        process.arguments = request.arguments
        if let directory = request.workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: directory, isDirectory: true)
        }
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let state = ProcessTerminationState()
        let startedAt = Date()
        let stream = AsyncStream<Int32> { continuation in
            process.terminationHandler = { terminated in
                continuation.yield(terminated.terminationStatus)
                continuation.finish()
            }
        }

        do {
            try process.run()
        } catch {
            throw AutomationError.processLaunchFailed(error.localizedDescription)
        }

        let timeoutTask = request.timeoutSeconds.map { timeout in
            Task {
                do {
                    try await Task.sleep(for: .seconds(timeout))
                    if process.isRunning {
                        state.markTimedOut()
                        process.terminate()
                    }
                } catch {
                    // Normal cancellation after the process exits.
                }
            }
        }

        let exitCode = await withTaskCancellationHandler {
            var code: Int32 = -1
            for await status in stream {
                code = status
                break
            }
            return code
        } onCancel: {
            state.markCancelled()
            if process.isRunning { process.terminate() }
        }
        timeoutTask?.cancel()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        return ProcessExecutionResult(
            stdout: String(decoding: stdoutData, as: UTF8.self),
            stderr: String(decoding: stderrData, as: UTF8.self),
            exitCode: exitCode,
            startedAt: startedAt,
            endedAt: Date(),
            timedOut: state.timedOut,
            cancelled: state.cancelled
        )
    }
}
