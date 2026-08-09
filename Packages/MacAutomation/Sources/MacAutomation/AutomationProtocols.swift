import Foundation
import SceneCore

public protocol ApplicationOpening: Sendable {
    func openApplication(bundleIdentifier: String) async throws
}

public protocol URLOpening: Sendable {
    func openURL(_ url: URL) async throws
}

public struct ProcessRequest: Equatable, Sendable {
    public let executable: String
    public let arguments: [String]
    public let workingDirectory: String?
    public let timeoutSeconds: Double?

    public init(executable: String, arguments: [String], workingDirectory: String?, timeoutSeconds: Double?) {
        self.executable = executable
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.timeoutSeconds = timeoutSeconds
    }
}

public protocol ProcessRunning: Sendable {
    func run(_ request: ProcessRequest) async throws -> ProcessExecutionResult
}

public enum AutomationError: LocalizedError, Equatable, Sendable {
    case applicationNotFound(String)
    case applicationLaunchFailed(String)
    case urlOpenFailed(String)
    case executableNotFound(String)
    case workingDirectoryNotFound(String)
    case processLaunchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .applicationNotFound(let id): "No installed application has bundle identifier \(id)."
        case .applicationLaunchFailed(let message): "Application could not be opened: \(message)"
        case .urlOpenFailed(let value): "URL could not be opened: \(value)"
        case .executableNotFound(let path): "Executable does not exist or is not executable: \(path)"
        case .workingDirectoryNotFound(let path): "Working directory does not exist: \(path)"
        case .processLaunchFailed(let message): "Process could not start: \(message)"
        }
    }
}
