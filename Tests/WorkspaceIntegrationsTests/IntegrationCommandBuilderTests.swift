import XCTest
import MacAutomation
import SceneCore
@testable import WorkspaceIntegrations

final class IntegrationCommandBuilderTests: XCTestCase {
    private let builder = IntegrationCommandBuilder(locator: FakeLocator())
    func testEditorUsesOpenWithStructuredArguments() throws {
        let request = try builder.editor(.init(editor: .cursor, projectPath: "/tmp/project", profile: "Work", files: [.init(file: "/tmp/project/a.swift", line: 8, column: 2)]))
        XCTAssertEqual(request.executable, "/usr/bin/open"); XCTAssertEqual(request.arguments, ["-b", "com.todesktop.230313mzl4w4u92", "--args", "--new-window", "--profile", "Work", "/tmp/project", "--goto", "/tmp/project/a.swift:8:2"])
    }
    func testTmuxUsesSafeArgumentArray() throws {
        let request = try XCTUnwrap(builder.tmuxEnsure(.init(workingDirectory: "/tmp/project", tmuxSessionName: "project-h")))
        XCTAssertEqual(request.executable, "/opt/homebrew/bin/tmux"); XCTAssertEqual(request.arguments, ["new-session", "-d", "-A", "-s", "project-h", "-c", "/tmp/project"])
    }
    func testDockerComposeArguments() throws {
        let action = DockerComposeAction(projectDirectory: "/tmp/project", composeFile: "/tmp/project/compose.yml", services: ["web"], profiles: ["dev"], build: true, pullPolicy: .always)
        let request = try builder.dockerUp(action)
        XCTAssertEqual(request.executable, "/usr/local/bin/docker"); XCTAssertEqual(request.arguments, ["compose", "--project-directory", "/tmp/project", "--file", "/tmp/project/compose.yml", "--profile", "dev", "up", "--detach", "--build", "--pull", "always", "web"])
    }
    func testDockerVolumeRemovalRequiresConfirmation() {
        let action = DockerComposeAction(projectDirectory: "/tmp/project", stopPolicy: .down, removeVolumes: true)
        XCTAssertThrowsError(try builder.dockerStop(action, destructiveConfirmed: false))
    }
    func testDockerStatusUsesStructuredArguments() throws {
        let action = DockerComposeAction(projectDirectory: "/tmp/project", composeFile: "/tmp/project/compose.yml")
        let request = try builder.dockerStatus(action, service: "web", timeoutSeconds: 7)
        XCTAssertEqual(request.arguments, ["compose", "--project-directory", "/tmp/project", "--file", "/tmp/project/compose.yml", "ps", "--format", "json", "web"])
        XCTAssertEqual(request.timeoutSeconds, 7)
    }
    func testDockerHealthUsesOwnedComposeIdentity() async throws {
        let runner = QueueProcessRunner(outputs: ["started", #"[{"Service":"web","State":"running","Health":"healthy"}]"#])
        let action = SceneAction.dockerCompose(.init(id: "compose", projectDirectory: "/tmp/project", services: ["web"]))
        let executor = WorkspaceIntegrationExecutor(processRunner: runner, builder: builder)
        let outcome = try await executor.execute(action)
        let checker = DockerIntegrationHealthChecker(processRunner: runner, builder: builder)
        let message = try await checker.check(.docker(.init(composeActionID: "compose", service: "web")), resources: outcome.resources)
        XCTAssertEqual(message, "Docker service is healthy")
        let requestCount = await runner.requests.count
        XCTAssertEqual(requestCount, 2)
    }
    func testShortcutRejectsControlCharacters() { XCTAssertThrowsError(try builder.shortcut(.init(name: "Bad\0Name"))) }
}

private struct FakeLocator: IntegrationExecutableLocating { func executable(for kind: IntegrationKind) -> String? { switch kind { case .tmux: "/opt/homebrew/bin/tmux"; case .docker: "/usr/local/bin/docker"; case .shortcuts: "/usr/bin/shortcuts"; default: nil } } }

private actor QueueProcessRunner: ProcessRunning {
    private var outputs: [String]; private(set) var requests: [ProcessRequest] = []
    init(outputs: [String]) { self.outputs = outputs }
    func run(_ request: ProcessRequest) async throws -> ProcessExecutionResult { requests.append(request); let output = outputs.isEmpty ? "" : outputs.removeFirst(); return .init(stdout: output, stderr: "", exitCode: 0, startedAt: Date(), endedAt: Date(), timedOut: false, cancelled: false) }
}
