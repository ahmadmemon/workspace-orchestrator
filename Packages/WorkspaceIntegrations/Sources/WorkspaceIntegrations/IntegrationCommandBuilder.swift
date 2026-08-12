import Foundation
import MacAutomation
import SceneCore

public enum IntegrationCommandError: LocalizedError, Equatable {
    case missingTool(String); case invalidField(String)
    public var errorDescription: String? { switch self { case .missingTool(let name): "\(name) is not installed in a supported location."; case .invalidField(let message): "Integration configuration is invalid: \(message)" } }
}

public struct IntegrationCommandBuilder: Sendable {
    private let locator: any IntegrationExecutableLocating
    public init(locator: any IntegrationExecutableLocating = StandardIntegrationExecutableLocator()) { self.locator = locator }

    public func editor(_ value: EditorWorkspaceAction) throws -> ProcessRequest {
        let bundleID: String
        switch value.editor { case .visualStudioCode: bundleID = "com.microsoft.VSCode"; case .visualStudioCodeInsiders: bundleID = "com.microsoft.VSCodeInsiders"; case .cursor: bundleID = "com.todesktop.230313mzl4w4u92"; case .vscodium: bundleID = "com.vscodium" }
        var arguments = ["-b", bundleID, "--args"]
        if value.newWindow { arguments.append("--new-window") }
        if let profile = value.profile { try safe(profile, field: "editor profile"); arguments += ["--profile", profile] }
        arguments.append(value.projectPath)
        for location in value.files { var target = location.file; if let line = location.line { target += ":\(line)"; if let column = location.column { target += ":\(column)" } }; arguments += ["--goto", target] }
        return .init(executable: "/usr/bin/open", arguments: arguments, workingDirectory: nil, timeoutSeconds: value.configuration.timeoutSeconds)
    }

    public func tmuxEnsure(_ value: TerminalWorkspaceAction) throws -> ProcessRequest? {
        guard let session = value.tmuxSessionName else { return nil }; try safeIdentifier(session, field: "tmux session")
        guard let executable = locator.executable(for: .tmux) else { throw IntegrationCommandError.missingTool("tmux") }
        return .init(executable: executable, arguments: ["new-session", "-d", "-A", "-s", session, "-c", value.workingDirectory], workingDirectory: value.workingDirectory, timeoutSeconds: value.configuration.timeoutSeconds ?? 10)
    }

    public func terminalOpen(_ value: TerminalWorkspaceAction) -> ProcessRequest {
        let bundle = value.terminal == .terminal ? "com.apple.Terminal" : "com.googlecode.iterm2"
        return .init(executable: "/usr/bin/open", arguments: ["-b", bundle, value.workingDirectory], workingDirectory: nil, timeoutSeconds: value.configuration.timeoutSeconds ?? 10)
    }

    public func dockerUp(_ value: DockerComposeAction) throws -> ProcessRequest {
        guard let executable = locator.executable(for: .docker) else { throw IntegrationCommandError.missingTool("Docker CLI") }
        var args = ["compose", "--project-directory", value.projectDirectory]
        if let file = value.composeFile { args += ["--file", file] }
        for profile in value.profiles { try safeIdentifier(profile, field: "Docker profile"); args += ["--profile", profile] }
        if let file = value.environmentFile { args += ["--env-file", file] }
        args += ["up", "--detach"]
        if value.build { args.append("--build") }
        switch value.pullPolicy { case .missing: args += ["--pull", "missing"]; case .always: args += ["--pull", "always"]; case .never: args += ["--pull", "never"] }
        for service in value.services { try safeIdentifier(service, field: "Docker service"); args.append(service) }
        return .init(executable: executable, arguments: args, workingDirectory: value.projectDirectory, timeoutSeconds: value.configuration.timeoutSeconds ?? 300)
    }

    public func dockerStop(_ value: DockerComposeAction, destructiveConfirmed: Bool) throws -> ProcessRequest {
        guard let executable = locator.executable(for: .docker) else { throw IntegrationCommandError.missingTool("Docker CLI") }
        if value.removeVolumes && !destructiveConfirmed { throw IntegrationCommandError.invalidField("volume removal requires explicit confirmation") }
        var args = ["compose", "--project-directory", value.projectDirectory]
        if let file = value.composeFile { args += ["--file", file] }
        args.append(value.stopPolicy.rawValue)
        if value.removeVolumes { args.append("--volumes") }
        return .init(executable: executable, arguments: args, workingDirectory: value.projectDirectory, timeoutSeconds: value.configuration.timeoutSeconds ?? 120)
    }

    public func dockerStatus(_ value: DockerComposeAction, service: String) throws -> ProcessRequest {
        guard let executable = locator.executable(for: .docker) else { throw IntegrationCommandError.missingTool("Docker CLI") }
        try safeIdentifier(service, field: "Docker service")
        var args = ["compose", "--project-directory", value.projectDirectory]
        if let file = value.composeFile { args += ["--file", file] }
        args += ["ps", "--format", "json", service]
        return .init(executable: executable, arguments: args, workingDirectory: value.projectDirectory, timeoutSeconds: min(value.configuration.timeoutSeconds ?? 30, 30))
    }

    public func shortcut(_ value: ShortcutAction) throws -> ProcessRequest {
        guard let executable = locator.executable(for: .shortcuts) else { throw IntegrationCommandError.missingTool("macOS Shortcuts") }
        try safe(value.name, field: "shortcut name")
        var args = ["run", value.name]
        if let input = value.inputFile { args += ["--input-path", input] }
        return .init(executable: executable, arguments: args, workingDirectory: nil, timeoutSeconds: value.configuration.timeoutSeconds ?? 120)
    }

    private func safe(_ value: String, field: String) throws { if value.isEmpty || value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) { throw IntegrationCommandError.invalidField("\(field) contains control characters") } }
    private func safeIdentifier(_ value: String, field: String) throws { try safe(value, field: field); let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "._-")); if !value.unicodeScalars.allSatisfy(allowed.contains) { throw IntegrationCommandError.invalidField("\(field) contains unsupported characters") } }
}
