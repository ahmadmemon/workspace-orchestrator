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
}
