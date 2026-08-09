import XCTest
@testable import MacAutomation

final class ProcessRunnerTests: XCTestCase {
    private let runner = FoundationProcessRunner()

    func testSuccessfulProcessAndStdoutCapture() async throws {
        let result = try await runner.run(.init(
            executable: "/usr/bin/printf", arguments: ["hello"], workingDirectory: nil, timeoutSeconds: 2
        ))
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout, "hello")
        XCTAssertEqual(result.stderr, "")
        XCTAssertFalse(result.timedOut)
        XCTAssertFalse(result.cancelled)
        XCTAssertGreaterThanOrEqual(result.duration, 0)
    }

    func testNonZeroExitAndStderrCapture() async throws {
        let result = try await runner.run(.init(
            executable: "/usr/bin/env", arguments: ["definitely-not-a-real-executable"], workingDirectory: nil, timeoutSeconds: 2
        ))
        XCTAssertNotEqual(result.exitCode, 0)
        XCTAssertFalse(result.stderr.isEmpty)
    }

    func testTimeout() async throws {
        let result = try await runner.run(.init(
            executable: "/bin/sleep", arguments: ["2"], workingDirectory: nil, timeoutSeconds: 0.05
        ))
        XCTAssertTrue(result.timedOut)
        XCTAssertFalse(result.cancelled)
    }

    func testCancellation() async throws {
        let task = Task {
            try await runner.run(.init(
                executable: "/bin/sleep", arguments: ["2"], workingDirectory: nil, timeoutSeconds: nil
            ))
        }
        try await Task.sleep(for: .milliseconds(50))
        task.cancel()
        let result = try await task.value
        XCTAssertTrue(result.cancelled)
    }
}
