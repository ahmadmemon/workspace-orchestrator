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

public struct HTTPHealthResponse: Sendable {
    public var data: Data; public var statusCode: Int
    public init(data: Data, statusCode: Int) { self.data = data; self.statusCode = statusCode }
}
public protocol HTTPHealthRequesting: Sendable { func response(for request: URLRequest) async throws -> HTTPHealthResponse }
public protocol TCPHealthConnecting: Sendable { func connect(host: String, port: Int, timeout: Double) async throws }
public protocol HealthCheckSleeping: Sendable { func sleep(seconds: Double) async throws }
public struct SystemHealthCheckSleeper: HealthCheckSleeping { public init() {}; public func sleep(seconds: Double) async throws { try await Task.sleep(for: .seconds(seconds)) } }
public struct URLSessionHTTPHealthClient: HTTPHealthRequesting {
    public init() {}
    public func response(for request: URLRequest) async throws -> HTTPHealthResponse { let (data, response) = try await URLSession.shared.data(for: request); guard let http = response as? HTTPURLResponse else { throw OrchestrationFailure(category: .healthCheck, message: "The health endpoint did not return HTTP.", retryableCategory: .healthCheck) }; return .init(data: data, statusCode: http.statusCode) }
}
public struct NetworkTCPHealthClient: TCPHealthConnecting {
    public init() {}
    public func connect(host: String, port: Int, timeout: Double) async throws {
        guard let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)) else { throw OrchestrationFailure(category: .validation, message: "TCP port is invalid.") }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let connection = NWConnection(host: NWEndpoint.Host(host), port: endpointPort, using: .tcp); let gate = TCPCompletionGate(continuation: continuation, connection: connection)
            connection.stateUpdateHandler = { state in switch state { case .ready: gate.finish(.success(())); case .failed(let error): gate.finish(.failure(error)); default: break } }
            connection.start(queue: .global(qos: .utility)); DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) { gate.finish(.failure(OrchestrationFailure(category: .timeout, message: "TCP connection timed out.", retryableCategory: .timeout))) }
        }
    }
}

public struct NativeHealthChecker: HealthCheckExecuting {
    private let managedProcesses: (any ManagedProcessControlling)?; private let httpClient: any HTTPHealthRequesting; private let tcpClient: any TCPHealthConnecting; private let sleeper: any HealthCheckSleeping; private let additionalHealthChecker: (any HealthCheckExecuting)?
    public init(managedProcesses: (any ManagedProcessControlling)? = nil, httpClient: any HTTPHealthRequesting = URLSessionHTTPHealthClient(), tcpClient: any TCPHealthConnecting = NetworkTCPHealthClient(), sleeper: any HealthCheckSleeping = SystemHealthCheckSleeper(), additionalHealthChecker: (any HealthCheckExecuting)? = nil) { self.managedProcesses = managedProcesses; self.httpClient = httpClient; self.tcpClient = tcpClient; self.sleeper = sleeper; self.additionalHealthChecker = additionalHealthChecker }
    public func check(_ check: HealthCheck, resources: [ResourceRecord]) async throws -> String? {
        switch check {
        case .http(let value): return try await checkHTTP(value)
        case .tcp(let value): return try await checkTCP(value)
        case .process(let value):
            return try await retry(interval: value.intervalSeconds ?? 1, maximumAttempts: value.maximumAttempts ?? 1) { guard let resource = resources.last(where: { $0.actionID == value.actionID }), let snapshot = await managedProcesses?.snapshot(identifier: resource.identifier), snapshot.running else { throw OrchestrationFailure(category: .healthCheck, message: "Managed process is not running.", retryableCategory: .healthCheck) }; return "PID \(snapshot.processIdentifier) is running" }
        case .application(let value):
            return try await retry(interval: value.intervalSeconds ?? 1, maximumAttempts: value.maximumAttempts ?? 1) { guard NSRunningApplication.runningApplications(withBundleIdentifier: value.bundleIdentifier).isEmpty == false else { throw OrchestrationFailure(category: .healthCheck, message: "Application is not running.", retryableCategory: .healthCheck) }; return "Application is running" }
        case .file(let value):
            return try await retry(interval: value.intervalSeconds ?? 1, maximumAttempts: value.maximumAttempts ?? 1) { var isDirectory: ObjCBool = false; guard FileManager.default.fileExists(atPath: value.path, isDirectory: &isDirectory) else { throw OrchestrationFailure(category: .healthCheck, message: "Required path does not exist.", retryableCategory: .healthCheck) }; if let expected = value.mustBeDirectory, expected != isDirectory.boolValue { throw OrchestrationFailure(category: .healthCheck, message: "Required path has the wrong type.") }; if let maximumAge = value.modifiedWithinSeconds { let attributes = try FileManager.default.attributesOfItem(atPath: value.path); guard let modified = attributes[.modificationDate] as? Date, Date().timeIntervalSince(modified) <= maximumAge else { throw OrchestrationFailure(category: .healthCheck, message: "Required path was not modified recently enough.", retryableCategory: .healthCheck) } }; return "Path exists" }
        case .docker(let value):
            guard let additionalHealthChecker else { throw OrchestrationFailure(category: .missingIntegration, message: "Docker health requires the Docker integration health adapter.", retryableCategory: .missingIntegration) }
            return try await retry(interval: value.intervalSeconds ?? 2, maximumAttempts: value.maximumAttempts ?? 15) { try await additionalHealthChecker.check(check, resources: resources) }
        }
    }
    private func checkHTTP(_ value: HTTPHealthCheck) async throws -> String? {
        guard let url = URL(string: value.url) else { throw OrchestrationFailure(category: .validation, message: "Health URL is invalid.") }
        var request = URLRequest(url: url); request.httpMethod = value.method.rawValue; request.timeoutInterval = value.timeoutSeconds
        var lastError = "No response"
        for attempt in 1...value.maximumAttempts {
            do { let response = try await httpClient.response(for: request); guard value.expectedStatus.contains(response.statusCode) else { throw OrchestrationFailure(category: .healthCheck, message: "HTTP status was outside \(value.expectedStatus).", retryableCategory: .healthCheck) }; if let match = value.responseContains, !String(decoding: response.data.prefix(65_536), as: UTF8.self).contains(match) { throw OrchestrationFailure(category: .healthCheck, message: "HTTP response did not contain the expected bounded text.", retryableCategory: .healthCheck) }; return "HTTP \(response.statusCode)" } catch { lastError = error.localizedDescription; if attempt < value.maximumAttempts { try await sleeper.sleep(seconds: value.intervalSeconds) } }
        }
        throw OrchestrationFailure(category: .healthCheck, message: lastError, retryableCategory: .healthCheck)
    }
    private func checkTCP(_ value: TCPHealthCheck) async throws -> String? {
        guard (1...65_535).contains(value.port) else { throw OrchestrationFailure(category: .validation, message: "TCP port is invalid.") }
        var lastError = "TCP connection failed"
        for attempt in 1...value.maximumAttempts {
            do { try await tcpClient.connect(host: value.host, port: value.port, timeout: value.timeoutSeconds); return "TCP port \(value.port) accepted a connection" } catch { lastError = error.localizedDescription; if attempt < value.maximumAttempts { try await sleeper.sleep(seconds: value.intervalSeconds) } }
        }
        throw OrchestrationFailure(category: .healthCheck, message: lastError, retryableCategory: .healthCheck)
    }
    private func retry(interval: Double, maximumAttempts: Int, operation: () async throws -> String?) async throws -> String? {
        var lastError: Error = OrchestrationFailure(category: .healthCheck, message: "Health check failed.", retryableCategory: .healthCheck)
        for attempt in 1...max(1, maximumAttempts) {
            do { return try await operation() }
            catch is CancellationError { throw CancellationError() }
            catch { lastError = error; if attempt < maximumAttempts { try await sleeper.sleep(seconds: interval) } }
        }
        throw lastError
    }
}
