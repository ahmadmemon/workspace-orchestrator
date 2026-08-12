import Foundation
import SceneCore

public protocol ApplicationOpening: Sendable {
    func openApplication(bundleIdentifier: String) async throws
}

public protocol URLOpening: Sendable {
    func openURL(_ url: URL) async throws
}

public protocol FileOpening: Sendable {
    func openFile(at url: URL, applicationBundleIdentifier: String?, revealInFinder: Bool) async throws
}

public struct ProcessRequest: Equatable, Sendable {
    public let executable: String
    public let arguments: [String]
    public let workingDirectory: String?
    public let timeoutSeconds: Double?
    public let environment: [String: String]
    public let maximumOutputBytes: Int

    public init(executable: String, arguments: [String], workingDirectory: String?, timeoutSeconds: Double?, environment: [String: String] = [:], maximumOutputBytes: Int = 262_144) {
        self.executable = executable
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.timeoutSeconds = timeoutSeconds
        self.environment = environment
        self.maximumOutputBytes = maximumOutputBytes
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
    case restrictedExecutable(String)
    case fileOpenFailed(String)
    case unsupportedAction(String)

    public var errorDescription: String? {
        switch self {
        case .applicationNotFound(let id): "No installed application has bundle identifier \(id)."
        case .applicationLaunchFailed(let message): "Application could not be opened: \(message)"
        case .urlOpenFailed(let value): "URL could not be opened: \(value)"
        case .executableNotFound(let path): "Executable does not exist or is not executable: \(path)"
        case .workingDirectoryNotFound(let path): "Working directory does not exist: \(path)"
        case .processLaunchFailed(let message): "Process could not start: \(message)"
        case .restrictedExecutable(let path): "Executable is restricted by the security policy: \(path)"
        case .fileOpenFailed(let message): "File or folder could not be opened: \(message)"
        case .unsupportedAction(let name): "The \(name) integration is unavailable."
        }
    }
}
