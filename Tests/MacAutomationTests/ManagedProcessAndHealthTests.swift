import Foundation
import XCTest
import OrchestrationEngine
import SceneCore
@testable import MacAutomation

final class ManagedProcessAndHealthTests: XCTestCase {
    func testManagedProcessReuseAndOwnedStop() async throws {
        let controller = ManagedProcessController()
        let action = ManagedProcessAction(id: "sleep", executable: "/bin/sleep", arguments: ["5"], singleInstanceKey: "test-\(UUID().uuidString)", gracefulStopSeconds: 1)
        let first = try await controller.start(action, environment: [:]); let second = try await controller.start(action, environment: [:])
        let running = await controller.snapshot(identifier: action.singleInstanceKey)?.running
        XCTAssertEqual(first.ownership, .created); XCTAssertEqual(second.ownership, .adopted); XCTAssertEqual(running, true)
        try await controller.stop(identifier: action.singleInstanceKey, graceSeconds: 1)
        let stopped = await controller.snapshot(identifier: action.singleInstanceKey)
        XCTAssertNil(stopped)
    }

    func testFileHealthCheckUsesLocalFilesystem() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("ok".utf8).write(to: file)
        let message = try await NativeHealthChecker().check(.file(.init(path: file.path, mustBeDirectory: false)), resources: [])
        XCTAssertEqual(message, "Path exists")
    }

    func testMissingFileHealthCheckFailsClearly() async {
        do { _ = try await NativeHealthChecker().check(.file(.init(path: "/tmp/definitely-missing-\(UUID().uuidString)")), resources: []); XCTFail("Expected failure") }
        catch { XCTAssertTrue(error.localizedDescription.contains("does not exist")) }
    }

    func testStaleFileHealthCheckFailsRecencyRequirement() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("old".utf8).write(to: file)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -120)], ofItemAtPath: file.path)
        do { _ = try await NativeHealthChecker().check(.file(.init(path: file.path, modifiedWithinSeconds: 10)), resources: []); XCTFail("Expected stale failure") }
        catch { XCTAssertTrue(error.localizedDescription.contains("recently")) }
    }

    func testHTTPHealthUsesInjectedClientAndBoundedBodyMatch() async throws {
        let client = MockHTTPClient(responses: [.success(.init(data: Data("service ready".utf8), statusCode: 204))])
        let checker = NativeHealthChecker(httpClient: client, tcpClient: MockTCPClient(results: []), sleeper: RecordingHealthSleeper())
        let message = try await checker.check(.http(.init(url: "https://localhost/health", expectedStatus: 200...299, responseContains: "ready", maximumAttempts: 1)), resources: [])
        XCTAssertEqual(message, "HTTP 204")
        let count = await client.requestCount
        XCTAssertEqual(count, 1)
    }

    func testHTTPHealthRetriesThenFailsWrongStatus() async {
        let client = MockHTTPClient(responses: [.success(.init(data: Data(), statusCode: 503)), .success(.init(data: Data(), statusCode: 503))])
        let sleeper = RecordingHealthSleeper()
        let checker = NativeHealthChecker(httpClient: client, tcpClient: MockTCPClient(results: []), sleeper: sleeper)
        do { _ = try await checker.check(.http(.init(url: "https://localhost/health", intervalSeconds: 0.1, maximumAttempts: 2)), resources: []); XCTFail("Expected HTTP failure") }
        catch { XCTAssertTrue(error.localizedDescription.contains("outside")) }
        let requestCount = await client.requestCount
        let sleepValues = await sleeper.values
        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(sleepValues, [0.1])
    }

    func testTCPHealthRetriesWithInjectedConnector() async throws {
        let connector = MockTCPClient(results: [.failure(TestHealthError.failed), .success(())])
        let sleeper = RecordingHealthSleeper()
        let checker = NativeHealthChecker(httpClient: MockHTTPClient(responses: []), tcpClient: connector, sleeper: sleeper)
        let message = try await checker.check(.tcp(.init(host: "127.0.0.1", port: 8080, intervalSeconds: 0.2, maximumAttempts: 2)), resources: [])
        XCTAssertEqual(message, "TCP port 8080 accepted a connection")
        let attempts = await connector.attempts
        let sleepValues = await sleeper.values
        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(sleepValues, [0.2])
    }
}

private enum TestHealthError: Error { case failed }
private actor MockHTTPClient: HTTPHealthRequesting {
    private var responses: [Result<HTTPHealthResponse, Error>]; private(set) var requestCount = 0
    init(responses: [Result<HTTPHealthResponse, Error>]) { self.responses = responses }
    func response(for request: URLRequest) async throws -> HTTPHealthResponse { requestCount += 1; guard !responses.isEmpty else { throw TestHealthError.failed }; return try responses.removeFirst().get() }
}
private actor MockTCPClient: TCPHealthConnecting {
    private var results: [Result<Void, Error>]; private(set) var attempts = 0
    init(results: [Result<Void, Error>]) { self.results = results }
    func connect(host: String, port: Int, timeout: Double) async throws { attempts += 1; guard !results.isEmpty else { throw TestHealthError.failed }; try results.removeFirst().get() }
}
private actor RecordingHealthSleeper: HealthCheckSleeping {
    private(set) var values: [Double] = []
    func sleep(seconds: Double) async throws { values.append(seconds) }
}
