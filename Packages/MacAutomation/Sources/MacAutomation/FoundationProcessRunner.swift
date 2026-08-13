import Foundation
import SceneCore

private final class ProcessTerminationState: @unchecked Sendable {
    private let lock = NSLock(); private var _timedOut = false; private var _cancelled = false
    var timedOut: Bool { lock.withLock { _timedOut } }; var cancelled: Bool { lock.withLock { _cancelled } }
    func markTimedOut() { lock.withLock { _timedOut = true } }; func markCancelled() { lock.withLock { _cancelled = true } }
}

private final class BoundedDataCollector: @unchecked Sendable {
    private let lock = NSLock(); private let limit: Int; private var data = Data(); private var truncated = false
    init(limit: Int) { self.limit = max(0, limit) }
    func append(_ chunk: Data) { lock.withLock { let remaining = max(0, limit - data.count); if chunk.count > remaining { truncated = true }; data.append(chunk.prefix(remaining)) } }
    func string() -> String { lock.withLock { String(decoding: data, as: UTF8.self) + (truncated ? "\n[OUTPUT TRUNCATED]" : "") } }
}

public struct FoundationProcessRunner: ProcessRunning {
    public init() {}
    public func run(_ request: ProcessRequest) async throws -> ProcessExecutionResult {
        guard !SceneValidator.restrictedExecutables.contains(request.executable) else { throw AutomationError.restrictedExecutable(request.executable) }
        guard FileManager.default.isExecutableFile(atPath: request.executable) else { throw AutomationError.executableNotFound(request.executable) }
        if let directory = request.workingDirectory { var isDirectory: ObjCBool = false; guard FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory), isDirectory.boolValue else { throw AutomationError.workingDirectoryNotFound(directory) } }
        let process = Process(), stdoutPipe = Pipe(), stderrPipe = Pipe()
        let stdout = BoundedDataCollector(limit: request.maximumOutputBytes), stderr = BoundedDataCollector(limit: request.maximumOutputBytes)
        process.executableURL = URL(fileURLWithPath: request.executable); process.arguments = request.arguments
        if let directory = request.workingDirectory { process.currentDirectoryURL = URL(fileURLWithPath: directory, isDirectory: true) }
        if !request.environment.isEmpty { process.environment = request.environment }
        process.standardOutput = stdoutPipe; process.standardError = stderrPipe
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in let data = handle.availableData; if !data.isEmpty { stdout.append(data) } }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in let data = handle.availableData; if !data.isEmpty { stderr.append(data) } }
        let state = ProcessTerminationState(), startedAt = Date()
        let stream = AsyncStream<Int32> { continuation in process.terminationHandler = { terminated in continuation.yield(terminated.terminationStatus); continuation.finish() } }
        do { try process.run() } catch { stdoutPipe.fileHandleForReading.readabilityHandler = nil; stderrPipe.fileHandleForReading.readabilityHandler = nil; throw AutomationError.processLaunchFailed(error.localizedDescription) }
        let timeoutTask = request.timeoutSeconds.map { timeout in Task { do { try await Task.sleep(for: .seconds(timeout)); if process.isRunning { state.markTimedOut(); process.terminate() } } catch {} } }
        let exitCode = await withTaskCancellationHandler { var code: Int32 = -1; for await status in stream { code = status; break }; return code } onCancel: { state.markCancelled(); if process.isRunning { process.terminate() } }
        timeoutTask?.cancel(); stdoutPipe.fileHandleForReading.readabilityHandler = nil; stderrPipe.fileHandleForReading.readabilityHandler = nil
        stdout.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile()); stderr.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())
        return .init(stdout: stdout.string(), stderr: stderr.string(), exitCode: exitCode, startedAt: startedAt, endedAt: Date(), timedOut: state.timedOut, cancelled: state.cancelled)
    }
}
