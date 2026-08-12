import Foundation

public struct ValidationIssue: Codable, Equatable, Error, Sendable {
    public let path: String
    public let message: String
    public init(path: String, message: String) { self.path = path; self.message = message }
}

public struct SceneValidationError: LocalizedError, Equatable, Sendable {
    public let issues: [ValidationIssue]
    public init(issues: [ValidationIssue]) { self.issues = issues }
    public var errorDescription: String? { issues.map { "\($0.path): \($0.message)" }.joined(separator: "\n") }
}

public enum SceneValidator {
    public static let restrictedExecutables: Set<String> = [
        "/bin/sh", "/bin/bash", "/bin/zsh", "/usr/bin/osascript", "/usr/bin/sudo", "/usr/bin/env"
    ]

    public static func validate(_ scene: Scene) throws {
        let issues = issues(in: scene)
        if !issues.isEmpty { throw SceneValidationError(issues: issues) }
    }

    public static func issues(in scene: Scene) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if scene.schemaVersion != Scene.currentSchemaVersion { issues.append(.init(path: "schemaVersion", message: "Unsupported schema version \(scene.schemaVersion).")) }
        if blank(scene.id) { issues.append(.init(path: "id", message: "Scene ID must not be empty.")) }
        if blank(scene.name) { issues.append(.init(path: "name", message: "Scene name must not be empty.")) }
        if !(1...16).contains(scene.maximumConcurrency) { issues.append(.init(path: "maximumConcurrency", message: "Concurrency must be between 1 and 16.")) }
        if scene.tags.count > 50 { issues.append(.init(path: "tags", message: "A scene may have at most 50 tags.")) }
        issues += validatePlan(scene.actions, path: "actions")
        issues += validatePlan(scene.deactivationActions, path: "deactivationActions")
        return issues
    }

    private static func validatePlan(_ actions: [SceneAction], path: String) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let validActions = Dictionary(actions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<String>()
        for (index, action) in actions.enumerated() {
            let itemPath = "\(path)[\(index)]"
            if blank(action.id) { issues.append(.init(path: "\(itemPath).id", message: "Action ID must not be empty.")) }
            else if !seen.insert(action.id).inserted { issues.append(.init(path: "\(itemPath).id", message: "Action ID must be unique.")) }
            issues += validateConfiguration(action.configuration, actionID: action.id, validActions: validActions, path: itemPath)
            issues += validateAction(action, path: itemPath)
        }
        issues += cycleIssues(actions, path: path)
        return issues
    }

    private static func validateConfiguration(_ value: ActionConfiguration, actionID: String, validActions: [String: SceneAction], path: String) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let validIDs = Set(validActions.keys)
        for (index, dependency) in value.dependencies.enumerated() {
            if dependency == actionID { issues.append(.init(path: "\(path).configuration.dependencies[\(index)]", message: "An action cannot depend on itself.")) }
            else if !validIDs.contains(dependency) { issues.append(.init(path: "\(path).configuration.dependencies[\(index)]", message: "Dependency \(dependency) does not exist in this plan.")) }
        }
        if Set(value.dependencies).count != value.dependencies.count { issues.append(.init(path: "\(path).configuration.dependencies", message: "Dependencies must be unique.")) }
        if let timeout = value.timeoutSeconds, timeout <= 0 || timeout > 86_400 { issues.append(.init(path: "\(path).configuration.timeoutSeconds", message: "Timeout must be between 0 and 86400 seconds.")) }
        let retry = value.retryPolicy
        if !(1...20).contains(retry.maximumAttempts) { issues.append(.init(path: "\(path).configuration.retryPolicy.maximumAttempts", message: "Maximum attempts must be between 1 and 20.")) }
        if retry.strategy == .none, retry.maximumAttempts != 1 { issues.append(.init(path: "\(path).configuration.retryPolicy", message: "No-retry policy must have exactly one attempt.")) }
        if retry.initialDelaySeconds < 0 || retry.maximumDelaySeconds < retry.initialDelaySeconds || retry.maximumTotalDurationSeconds <= 0 { issues.append(.init(path: "\(path).configuration.retryPolicy", message: "Retry delays and total duration must be positive and internally consistent.")) }
        if !(0...0.5).contains(retry.jitterFraction) { issues.append(.init(path: "\(path).configuration.retryPolicy.jitterFraction", message: "Jitter must be between 0 and 0.5.")) }
        for index in value.disabledConditionIndexes where !value.conditions.indices.contains(index) { issues.append(.init(path: "\(path).configuration.disabledConditionIndexes", message: "Disabled condition index \(index) does not exist.")) }
        for (index, condition) in value.conditions.enumerated() {
            switch condition {
            case .pathExists(let conditionPath): if !absolute(conditionPath) { issues.append(.init(path: "\(path).configuration.conditions[\(index)].path", message: "Condition path must be absolute.")) }
            case .environmentEquals(let name, _): if !validEnvironmentName(name) { issues.append(.init(path: "\(path).configuration.conditions[\(index)].name", message: "Condition environment name is invalid.")) }
            }
        }
        for (index, check) in value.healthChecks.enumerated() { issues += validateCheck(check, validActions: validActions, path: "\(path).configuration.healthChecks[\(index)]") }
        return issues
    }

    private static func validateAction(_ action: SceneAction, path: String) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        switch action {
        case .openApplication(let value):
            if !validBundleIdentifier(value.bundleIdentifier) { issues.append(.init(path: "\(path).bundleIdentifier", message: "Enter a valid bundle identifier such as com.apple.TextEdit.")) }
            if let fallback = value.applicationPathFallback, !absolute(fallback) { issues.append(.init(path: "\(path).applicationPathFallback", message: "Application fallback must be an absolute path.")) }
        case .openURL(let value):
            for (index, url) in value.urls.enumerated() where !validHTTPURL(url) { issues.append(.init(path: "\(path).urls[\(index)]", message: "Enter an absolute http or https URL.")) }
            if value.urls.count > 100 { issues.append(.init(path: "\(path).urls", message: "A browser action may contain at most 100 URLs.")) }
            if value.delayBetweenURLsSeconds < 0 || value.delayBetweenURLsSeconds > 60 { issues.append(.init(path: "\(path).delayBetweenURLsSeconds", message: "URL delay must be between 0 and 60 seconds.")) }
        case .openFile(let value):
            if !absolute(value.path) { issues.append(.init(path: "\(path).path", message: "File or folder path must be absolute.")) }
            if let bundle = value.applicationBundleIdentifier, !validBundleIdentifier(bundle) { issues.append(.init(path: "\(path).applicationBundleIdentifier", message: "Selected application bundle identifier is invalid.")) }
        case .runProcess(let value):
            issues += validateProcess(executable: value.executable, arguments: value.arguments, workingDirectory: value.workingDirectory, environment: value.environment, path: path)
            if let timeout = value.timeoutSeconds, timeout <= 0 { issues.append(.init(path: "\(path).timeoutSeconds", message: "Timeout must be greater than zero.")) }
            if value.expectedExitCodes.isEmpty { issues.append(.init(path: "\(path).expectedExitCodes", message: "At least one expected exit code is required.")) }
        case .managedProcess(let value):
            issues += validateProcess(executable: value.executable, arguments: value.arguments, workingDirectory: value.workingDirectory, environment: value.environment, path: path)
            if blank(value.singleInstanceKey) { issues.append(.init(path: "\(path).singleInstanceKey", message: "Managed processes require a stable single-instance key.")) }
            if value.gracefulStopSeconds <= 0 || value.gracefulStopSeconds > 120 { issues.append(.init(path: "\(path).gracefulStopSeconds", message: "Graceful stop must be between 0 and 120 seconds.")) }
        case .wait(let value):
            if value.durationSeconds <= 0 || value.durationSeconds > 3_600 { issues.append(.init(path: "\(path).durationSeconds", message: "Wait duration must be between 0 and 3600 seconds.")) }
        case .editorWorkspace(let value):
            if !absolute(value.projectPath) { issues.append(.init(path: "\(path).projectPath", message: "Editor project path must be absolute.")) }
            for (index, file) in value.files.enumerated() {
                if !absolute(file.file) { issues.append(.init(path: "\(path).files[\(index)].file", message: "Editor file path must be absolute.")) }
                if let line = file.line, line < 1 { issues.append(.init(path: "\(path).files[\(index)].line", message: "Line must be positive.")) }
                if let column = file.column, column < 1 { issues.append(.init(path: "\(path).files[\(index)].column", message: "Column must be positive.")) }
            }
        case .terminalWorkspace(let value):
            if !absolute(value.workingDirectory) { issues.append(.init(path: "\(path).workingDirectory", message: "Terminal working directory must be absolute.")) }
            if let name = value.tmuxSessionName, !safeIdentifier(name) { issues.append(.init(path: "\(path).tmuxSessionName", message: "tmux session names may contain letters, numbers, dot, underscore, and hyphen only.")) }
        case .dockerCompose(let value):
            if !absolute(value.projectDirectory) { issues.append(.init(path: "\(path).projectDirectory", message: "Compose project directory must be absolute.")) }
            if let file = value.composeFile, !absolute(file) { issues.append(.init(path: "\(path).composeFile", message: "Compose file must be absolute.")) }
            if let file = value.environmentFile, !absolute(file) { issues.append(.init(path: "\(path).environmentFile", message: "Environment file must be absolute.")) }
            for (index, service) in value.services.enumerated() where !safeIdentifier(service) { issues.append(.init(path: "\(path).services[\(index)]", message: "Service contains unsupported characters.")) }
            if value.removeVolumes && value.stopPolicy != .down { issues.append(.init(path: "\(path).removeVolumes", message: "Volume removal requires Docker down and explicit destructive confirmation.")) }
            if value.removeVolumes && value.configuration.retryPolicy.strategy != .none { issues.append(.init(path: "\(path).configuration.retryPolicy", message: "Destructive volume removal cannot retry automatically.")) }
        case .shortcut(let value):
            if blank(value.name) || hasControlCharacters(value.name) { issues.append(.init(path: "\(path).name", message: "Shortcut name is required and cannot contain control characters.")) }
            if let file = value.inputFile, !absolute(file) { issues.append(.init(path: "\(path).inputFile", message: "Shortcut input file must be absolute.")) }
        case .windowLayout(let value):
            if value.placements.isEmpty { issues.append(.init(path: "\(path).placements", message: "A window layout requires at least one reviewed placement.")) }
            for (index, placement) in value.placements.enumerated() {
                if !validBundleIdentifier(placement.bundleIdentifier) { issues.append(.init(path: "\(path).placements[\(index)].bundleIdentifier", message: "Window application identifier is invalid.")) }
                let frame = placement.frame
                if frame.width <= 0 || frame.height <= 0 || frame.x < 0 || frame.y < 0 || frame.x + frame.width > 1.001 || frame.y + frame.height > 1.001 { issues.append(.init(path: "\(path).placements[\(index)].frame", message: "Normalized frame must fit within 0...1.")) }
            }
        }
        return issues
    }

    private static func validateProcess(executable: String, arguments: [String], workingDirectory: String?, environment: [String: EnvironmentValue], path: String) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if blank(executable) { issues.append(.init(path: "\(path).executable", message: "Executable is required.")) }
        else if !absolute(executable) { issues.append(.init(path: "\(path).executable", message: "Executable must be an absolute path.")) }
        else if restrictedExecutables.contains(executable) { issues.append(.init(path: "\(path).executable", message: "This shell, wrapper, or privilege executable is restricted.")) }
        if let directory = workingDirectory, !directory.isEmpty, !absolute(directory) { issues.append(.init(path: "\(path).workingDirectory", message: "Working directory must be an absolute path.")) }
        for (index, argument) in arguments.enumerated() where hasControlCharacters(argument) { issues.append(.init(path: "\(path).arguments[\(index)]", message: "Arguments cannot contain control characters other than tab or newline.")) }
        for (name, value) in environment {
            if !validEnvironmentName(name) { issues.append(.init(path: "\(path).environment.\(name)", message: "Environment variable name is invalid.")) }
            if case .secretReference(let reference) = value, blank(reference) { issues.append(.init(path: "\(path).environment.\(name)", message: "Secret reference is required.")) }
        }
        return issues
    }

    private static func validateCheck(_ check: HealthCheck, validActions: [String: SceneAction], path: String) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        switch check {
        case .http(let value):
            if !validHTTPURL(value.url) { issues.append(.init(path: "\(path).url", message: "Health-check URL must use http or https.")) }
            if value.responseContains?.utf8.count ?? 0 > 4_096 { issues.append(.init(path: "\(path).responseContains", message: "Response match is limited to 4096 bytes.")) }
            issues += validateCheckBounds(timeout: value.timeoutSeconds, interval: value.intervalSeconds, attempts: value.maximumAttempts, path: path)
        case .tcp(let value):
            if blank(value.host) || !(1...65_535).contains(value.port) { issues.append(.init(path: path, message: "TCP host and port must be valid.")) }
            issues += validateCheckBounds(timeout: value.timeoutSeconds, interval: value.intervalSeconds, attempts: value.maximumAttempts, path: path)
        case .process(let value):
            if blank(value.actionID) { issues.append(.init(path: "\(path).actionID", message: "Process check requires an action ID.")) }
            else if validActions[value.actionID] == nil { issues.append(.init(path: "\(path).actionID", message: "Process check action ID does not exist in this plan.")) }
            else if let target = validActions[value.actionID], case .managedProcess = target { } else { issues.append(.init(path: "\(path).actionID", message: "Process check must reference a managed-process action.")) }
            issues += validateCheckBounds(timeout: value.timeoutSeconds ?? 3, interval: value.intervalSeconds ?? 1, attempts: value.maximumAttempts ?? 1, path: path)
        case .application(let value):
            if !validBundleIdentifier(value.bundleIdentifier) { issues.append(.init(path: "\(path).bundleIdentifier", message: "Application check bundle identifier is invalid.")) }
            issues += validateCheckBounds(timeout: value.timeoutSeconds ?? 3, interval: value.intervalSeconds ?? 1, attempts: value.maximumAttempts ?? 1, path: path)
        case .file(let value):
            if !absolute(value.path) { issues.append(.init(path: "\(path).path", message: "File check path must be absolute.")) }
            if let age = value.modifiedWithinSeconds, age <= 0 || age > 2_592_000 { issues.append(.init(path: "\(path).modifiedWithinSeconds", message: "Recent-modification age must be between 0 and 2592000 seconds.")) }
            issues += validateCheckBounds(timeout: value.timeoutSeconds ?? 3, interval: value.intervalSeconds ?? 1, attempts: value.maximumAttempts ?? 1, path: path)
        case .docker(let value):
            if blank(value.composeActionID) || !safeIdentifier(value.service) { issues.append(.init(path: path, message: "Docker check requires an action and safe service name.")) }
            else if validActions[value.composeActionID] == nil { issues.append(.init(path: "\(path).composeActionID", message: "Docker Compose action ID does not exist in this plan.")) }
            else if let target = validActions[value.composeActionID], case .dockerCompose = target { } else { issues.append(.init(path: "\(path).composeActionID", message: "Docker check must reference a Docker Compose action.")) }
            issues += validateCheckBounds(timeout: value.timeoutSeconds ?? 5, interval: value.intervalSeconds ?? 2, attempts: value.maximumAttempts ?? 15, path: path)
        }
        return issues
    }

    private static func validateCheckBounds(timeout: Double, interval: Double, attempts: Int, path: String) -> [ValidationIssue] {
        guard timeout > 0, timeout <= 60, interval > 0, interval <= 300, (1...100).contains(attempts) else { return [.init(path: path, message: "Health check timeout, interval, and attempts must be bounded.")] }
        return []
    }

    private static func cycleIssues(_ actions: [SceneAction], path: String) -> [ValidationIssue] {
        var graph: [String: [String]] = [:]
        for action in actions where graph[action.id] == nil { graph[action.id] = action.configuration.dependencies }
        var visiting = Set<String>(); var visited = Set<String>(); var cycleNodes = Set<String>()
        func visit(_ id: String) {
            if visiting.contains(id) { cycleNodes.insert(id); return }
            guard !visited.contains(id) else { return }
            visiting.insert(id)
            for dependency in graph[id] ?? [] { visit(dependency); if cycleNodes.contains(dependency) { cycleNodes.insert(id) } }
            visiting.remove(id); visited.insert(id)
        }
        for id in graph.keys.sorted() { visit(id) }
        return cycleNodes.sorted().map { .init(path: path, message: "Dependency cycle includes action \($0).") }
    }

    private static func blank(_ value: String) -> Bool { value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private static func absolute(_ value: String) -> Bool { value.hasPrefix("/") && !hasNUL(value) }
    private static func hasNUL(_ value: String) -> Bool { value.unicodeScalars.contains { $0.value == 0 } }
    private static func hasControlCharacters(_ value: String) -> Bool { value.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) && $0.value != 9 && $0.value != 10 } }
    private static func validHTTPURL(_ value: String) -> Bool { guard let c = URLComponents(string: value), let scheme = c.scheme?.lowercased(), ["http", "https"].contains(scheme), c.host?.isEmpty == false, c.user == nil, c.password == nil else { return false }; return !hasControlCharacters(value) }
    private static func validBundleIdentifier(_ value: String) -> Bool { let parts = value.split(separator: ".", omittingEmptySubsequences: false); let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-")); return parts.count >= 2 && parts.allSatisfy { !$0.isEmpty && $0.unicodeScalars.allSatisfy(allowed.contains) } }
    private static func safeIdentifier(_ value: String) -> Bool { !blank(value) && value.unicodeScalars.allSatisfy(CharacterSet.alphanumerics.union(.init(charactersIn: "._-")).contains) }
    private static func validEnvironmentName(_ value: String) -> Bool { guard let first = value.unicodeScalars.first, CharacterSet.letters.union(.init(charactersIn: "_")).contains(first) else { return false }; return value.unicodeScalars.allSatisfy(CharacterSet.alphanumerics.union(.init(charactersIn: "_")).contains) }
}
