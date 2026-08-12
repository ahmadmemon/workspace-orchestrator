import AppKit
import Foundation
import Network
import OrchestrationEngine
import SceneCore

private final class TCPCompletionGate: @unchecked Sendable {
    private let lock = NSLock(); private var completed = false; private let continuation: CheckedContinuation<Void, Error>; private let connection: NWConnection
    init(continuation: CheckedContinuation<Void, Error>, connection: NWConnection) { self.continuation = continuation; self.connection = connection }
    func finish(_ result: Result<Void, Error>) { lock.withLock { guard !completed else { return }; completed = true; connection.cancel(); continuation.resume(with: result) } }
}

public struct NativeHealthChecker: HealthCheckExecuting {
    private let managedProcesses: (any ManagedProcessControlling)?
    public init(managedProcesses: (any ManagedProcessControlling)? = nil) { self.managedProcesses = managedProcesses }
    public func check(_ check: HealthCheck, resources: [ResourceRecord]) async throws -> String? {
        switch check {
        case .http(let value): return try await checkHTTP(value)
        case .tcp(let value): return try await checkTCP(value)
        case .process(let value): guard let resource = resources.last(where: { $0.actionID == value.actionID }), let snapshot = await managedProcesses?.snapshot(identifier: resource.identifier), snapshot.running else { throw OrchestrationFailure(category: .healthCheck, message: "Managed process is not running.", retryableCategory: .healthCheck) }; return "PID \(snapshot.processIdentifier) is running"
        case .application(let value): guard NSRunningApplication.runningApplications(withBundleIdentifier: value.bundleIdentifier).isEmpty == false else { throw OrchestrationFailure(category: .healthCheck, message: "Application is not running.", retryableCategory: .healthCheck) }; return "Application is running"
        case .file(let value): var isDirectory: ObjCBool = false; guard FileManager.default.fileExists(atPath: value.path, isDirectory: &isDirectory) else { throw OrchestrationFailure(category: .healthCheck, message: "Required path does not exist.", retryableCategory: .healthCheck) }; if let expected = value.mustBeDirectory, expected != isDirectory.boolValue { throw OrchestrationFailure(category: .healthCheck, message: "Required path has the wrong type.") }; return "Path exists"
        case .docker: throw OrchestrationFailure(category: .missingIntegration, message: "Docker health requires the Docker integration health adapter.", retryableCategory: .missingIntegration)
        }
    }
    private func checkHTTP(_ value: HTTPHealthCheck) async throws -> String? {
        guard let url = URL(string: value.url) else { throw OrchestrationFailure(category: .validation, message: "Health URL is invalid.") }
        var request = URLRequest(url: url); request.httpMethod = value.method.rawValue; request.timeoutInterval = value.timeoutSeconds
        var lastError = "No response"
        for attempt in 1...value.maximumAttempts {
            do { let (data, response) = try await URLSession.shared.data(for: request); guard let http = response as? HTTPURLResponse, value.expectedStatus.contains(http.statusCode) else { throw OrchestrationFailure(category: .healthCheck, message: "HTTP status was outside \(value.expectedStatus).", retryableCategory: .healthCheck) }; if let match = value.responseContains, !String(decoding: data.prefix(65_536), as: UTF8.self).contains(match) { throw OrchestrationFailure(category: .healthCheck, message: "HTTP response did not contain the expected bounded text.", retryableCategory: .healthCheck) }; return "HTTP \(http.statusCode)" } catch { lastError = error.localizedDescription; if attempt < value.maximumAttempts { try await Task.sleep(for: .seconds(value.intervalSeconds)) } }
        }
        throw OrchestrationFailure(category: .healthCheck, message: lastError, retryableCategory: .healthCheck)
    }
    private func checkTCP(_ value: TCPHealthCheck) async throws -> String? {
        guard let port = NWEndpoint.Port(rawValue: UInt16(value.port)) else { throw OrchestrationFailure(category: .validation, message: "TCP port is invalid.") }
        var lastError = "TCP connection failed"
        for attempt in 1...value.maximumAttempts {
            do { try await connect(host: NWEndpoint.Host(value.host), port: port, timeout: value.timeoutSeconds); return "TCP port \(value.port) accepted a connection" } catch { lastError = error.localizedDescription; if attempt < value.maximumAttempts { try await Task.sleep(for: .seconds(value.intervalSeconds)) } }
        }
        throw OrchestrationFailure(category: .healthCheck, message: lastError, retryableCategory: .healthCheck)
    }
    private func connect(host: NWEndpoint.Host, port: NWEndpoint.Port, timeout: Double) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let connection = NWConnection(host: host, port: port, using: .tcp); let gate = TCPCompletionGate(continuation: continuation, connection: connection)
            connection.stateUpdateHandler = { state in switch state { case .ready: gate.finish(.success(())); case .failed(let error): gate.finish(.failure(error)); default: break } }
            connection.start(queue: .global(qos: .utility)); DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) { gate.finish(.failure(OrchestrationFailure(category: .timeout, message: "TCP connection timed out.", retryableCategory: .timeout))) }
        }
    }
}
