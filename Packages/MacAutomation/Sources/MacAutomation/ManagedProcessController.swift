import Foundation
import SceneCore

public struct ManagedProcessSnapshot: Equatable, Sendable {
    public var key: String; public var processIdentifier: Int32; public var running: Bool; public var stdout: String; public var stderr: String
}
public protocol ManagedProcessControlling: Sendable {
    func start(_ action: ManagedProcessAction, environment: [String: String]) async throws -> ResourceRecord
    func stop(identifier: String, graceSeconds: Double) async throws
    func snapshot(identifier: String) async -> ManagedProcessSnapshot?
}

private final class ManagedHandle: @unchecked Sendable {
    let process: Process; let stdoutPipe: Pipe; let stderrPipe: Pipe; let lock = NSLock(); var stdout = Data(); var stderr = Data(); let limit: Int
    init(process: Process, stdoutPipe: Pipe, stderrPipe: Pipe, limit: Int = 262_144) { self.process = process; self.stdoutPipe = stdoutPipe; self.stderrPipe = stderrPipe; self.limit = limit }
    func append(_ data: Data, stderr isError: Bool) { lock.withLock { if isError { self.stderr.append(data.prefix(max(0, limit - self.stderr.count))) } else { stdout.append(data.prefix(max(0, limit - stdout.count))) } } }
    func snapshot(key: String) -> ManagedProcessSnapshot { lock.withLock { .init(key: key, processIdentifier: process.processIdentifier, running: process.isRunning, stdout: String(decoding: stdout, as: UTF8.self), stderr: String(decoding: stderr, as: UTF8.self)) } }
}

public actor ManagedProcessController: ManagedProcessControlling {
    private var handles: [String: ManagedHandle] = [:]
    public init() {}
    public func start(_ action: ManagedProcessAction, environment: [String: String] = [:]) async throws -> ResourceRecord {
        if let existing = handles[action.singleInstanceKey], existing.process.isRunning { return .init(actionID: action.id, kind: "managedProcess", identifier: action.singleInstanceKey, ownership: .adopted) }
        guard !SceneValidator.restrictedExecutables.contains(action.executable) else { throw AutomationError.restrictedExecutable(action.executable) }
        guard FileManager.default.isExecutableFile(atPath: action.executable) else { throw AutomationError.executableNotFound(action.executable) }
        let process = Process(), stdoutPipe = Pipe(), stderrPipe = Pipe(); process.executableURL = URL(fileURLWithPath: action.executable); process.arguments = action.arguments; process.standardOutput = stdoutPipe; process.standardError = stderrPipe
        if let directory = action.workingDirectory { process.currentDirectoryURL = URL(fileURLWithPath: directory) }; if !environment.isEmpty { process.environment = environment }
        let handle = ManagedHandle(process: process, stdoutPipe: stdoutPipe, stderrPipe: stderrPipe)
        stdoutPipe.fileHandleForReading.readabilityHandler = { file in let data = file.availableData; if !data.isEmpty { handle.append(data, stderr: false) } }
        stderrPipe.fileHandleForReading.readabilityHandler = { file in let data = file.availableData; if !data.isEmpty { handle.append(data, stderr: true) } }
        process.terminationHandler = { _ in stdoutPipe.fileHandleForReading.readabilityHandler = nil; stderrPipe.fileHandleForReading.readabilityHandler = nil }
        do { try process.run() } catch { throw AutomationError.processLaunchFailed(error.localizedDescription) }
        handles[action.singleInstanceKey] = handle
        return .init(actionID: action.id, kind: "managedProcess", identifier: action.singleInstanceKey, ownership: .created)
    }
    public func stop(identifier: String, graceSeconds: Double) async throws {
        guard let handle = handles[identifier] else { return }; guard handle.process.isRunning else { handles.removeValue(forKey: identifier); return }
        handle.process.terminate(); let deadline = Date().addingTimeInterval(max(0.1, min(graceSeconds, 120)))
        while handle.process.isRunning, Date() < deadline { try await Task.sleep(for: .milliseconds(50)) }
        if handle.process.isRunning { kill(handle.process.processIdentifier, SIGKILL) }
        handles.removeValue(forKey: identifier)
    }
    public func snapshot(identifier: String) async -> ManagedProcessSnapshot? { handles[identifier]?.snapshot(key: identifier) }
}
