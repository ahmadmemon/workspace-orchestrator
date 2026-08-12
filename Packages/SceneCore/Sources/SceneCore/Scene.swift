import Foundation

public enum DefaultActivationBehavior: String, Codable, CaseIterable, Sendable {
    case openDashboard
    case showOverlay
    case remainInMenuBar
}

public struct Scene: Codable, Equatable, Identifiable, Sendable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var id: String
    public var name: String
    public var description: String?
    public var iconName: String?
    public var favorite: Bool
    public var tags: [String]
    public var actions: [SceneAction]
    public var deactivationActions: [SceneAction]
    public var maximumConcurrency: Int
    public var defaultFailurePolicy: FailurePolicy
    public var defaultActivationBehavior: DefaultActivationBehavior?
    public var trustState: TrustState
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        schemaVersion: Int = Scene.currentSchemaVersion,
        id: String = UUID().uuidString,
        name: String,
        description: String? = nil,
        iconName: String? = nil,
        favorite: Bool = false,
        tags: [String] = [],
        actions: [SceneAction] = [],
        deactivationActions: [SceneAction] = [],
        maximumConcurrency: Int = 3,
        defaultFailurePolicy: FailurePolicy = .stopScene,
        defaultActivationBehavior: DefaultActivationBehavior? = nil,
        trustState: TrustState = .local,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.description = description
        self.iconName = iconName
        self.favorite = favorite
        self.tags = tags
        self.actions = actions
        self.deactivationActions = deactivationActions
        self.maximumConcurrency = maximumConcurrency
        self.defaultFailurePolicy = defaultFailurePolicy
        self.defaultActivationBehavior = defaultActivationBehavior
        self.trustState = trustState
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, name, description, iconName, favorite, tags, actions
        case deactivationActions, maximumConcurrency, defaultFailurePolicy
        case defaultActivationBehavior, trustState, createdAt, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let storedVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        guard (1...Scene.currentSchemaVersion).contains(storedVersion) else {
            throw DecodingError.dataCorruptedError(forKey: .schemaVersion, in: container, debugDescription: "Unsupported scene schema version \(storedVersion).")
        }
        schemaVersion = Scene.currentSchemaVersion
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName)
        favorite = try container.decodeIfPresent(Bool.self, forKey: .favorite) ?? false
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        actions = try container.decodeIfPresent([SceneAction].self, forKey: .actions) ?? []
        deactivationActions = try container.decodeIfPresent([SceneAction].self, forKey: .deactivationActions) ?? []
        maximumConcurrency = try container.decodeIfPresent(Int.self, forKey: .maximumConcurrency) ?? 1
        defaultFailurePolicy = try container.decodeIfPresent(FailurePolicy.self, forKey: .defaultFailurePolicy) ?? .stopScene
        defaultActivationBehavior = try container.decodeIfPresent(DefaultActivationBehavior.self, forKey: .defaultActivationBehavior)
        trustState = try container.decodeIfPresent(TrustState.self, forKey: .trustState) ?? .local
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

public enum SceneAction: Equatable, Identifiable, Sendable {
    case openApplication(OpenApplicationAction)
    case openURL(OpenURLAction)
    case openFile(OpenFileAction)
    case runProcess(RunProcessAction)
    case managedProcess(ManagedProcessAction)
    case wait(WaitAction)
    case editorWorkspace(EditorWorkspaceAction)
    case terminalWorkspace(TerminalWorkspaceAction)
    case dockerCompose(DockerComposeAction)
    case shortcut(ShortcutAction)
    case windowLayout(WindowLayoutAction)

    public var id: String {
        return switch self {
        case .openApplication(let value): value.id
        case .openURL(let value): value.id
        case .openFile(let value): value.id
        case .runProcess(let value): value.id
        case .managedProcess(let value): value.id
        case .wait(let value): value.id
        case .editorWorkspace(let value): value.id
        case .terminalWorkspace(let value): value.id
        case .dockerCompose(let value): value.id
        case .shortcut(let value): value.id
        case .windowLayout(let value): value.id
        }
    }

    public var configuration: ActionConfiguration {
        switch self {
        case .openApplication(let value): value.configuration
        case .openURL(let value): value.configuration
        case .openFile(let value): value.configuration
        case .runProcess(let value): value.configuration
        case .managedProcess(let value): value.configuration
        case .wait(let value): value.configuration
        case .editorWorkspace(let value): value.configuration
        case .terminalWorkspace(let value): value.configuration
        case .dockerCompose(let value): value.configuration
        case .shortcut(let value): value.configuration
        case .windowLayout(let value): value.configuration
        }
    }

    public var displayName: String {
        if let name = configuration.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return name }
        return switch self {
        case .openApplication: "Open Application"
        case .openURL: "Browser Workspace"
        case .openFile: "Open File or Folder"
        case .runProcess: "One-Shot Process"
        case .managedProcess: "Managed Process"
        case .wait: "Wait"
        case .editorWorkspace: "Editor Workspace"
        case .terminalWorkspace: "Terminal Workspace"
        case .dockerCompose: "Docker Compose"
        case .shortcut: "macOS Shortcut"
        case .windowLayout: "Window Layout"
        }
    }
}

public enum ApplicationLaunchPolicy: String, Codable, CaseIterable, Sendable { case reuse, alwaysLaunch }
public struct OpenApplicationAction: Codable, Equatable, Sendable {
    public var id: String; public var bundleIdentifier: String; public var applicationPathFallback: String?
    public var launchPolicy: ApplicationLaunchPolicy; public var activate: Bool; public var waitForRunning: Bool; public var launchTimeoutSeconds: Double?
    public var terminateIfOwnedOnStop: Bool; public var configuration: ActionConfiguration
    public init(id: String = UUID().uuidString, bundleIdentifier: String, applicationPathFallback: String? = nil, launchPolicy: ApplicationLaunchPolicy = .reuse, activate: Bool = true, waitForRunning: Bool = true, launchTimeoutSeconds: Double? = nil, terminateIfOwnedOnStop: Bool = false, configuration: ActionConfiguration = .init(idempotencyPolicy: .reuseExisting)) {
        self.id = id; self.bundleIdentifier = bundleIdentifier; self.applicationPathFallback = applicationPathFallback; self.launchPolicy = launchPolicy; self.activate = activate; self.waitForRunning = waitForRunning; self.launchTimeoutSeconds = launchTimeoutSeconds; self.terminateIfOwnedOnStop = terminateIfOwnedOnStop; self.configuration = configuration
    }
}

public enum BrowserWindowPolicy: String, Codable, CaseIterable, Sendable { case existing, newWindow }
public struct OpenURLAction: Codable, Equatable, Sendable {
    public var id: String; public var url: String; public var additionalURLs: [String]
    public var browserBundleIdentifier: String?; public var windowPolicy: BrowserWindowPolicy
    public var delayBetweenURLsSeconds: Double; public var deduplicateWithinRun: Bool; public var configuration: ActionConfiguration
    public var urls: [String] { [url] + additionalURLs }
    public init(id: String = UUID().uuidString, url: String, additionalURLs: [String] = [], browserBundleIdentifier: String? = nil, windowPolicy: BrowserWindowPolicy = .existing, delayBetweenURLsSeconds: Double = 0, deduplicateWithinRun: Bool = true, configuration: ActionConfiguration = .init(idempotencyPolicy: .oncePerRun)) {
        self.id = id; self.url = url; self.additionalURLs = additionalURLs; self.browserBundleIdentifier = browserBundleIdentifier; self.windowPolicy = windowPolicy; self.delayBetweenURLsSeconds = delayBetweenURLsSeconds; self.deduplicateWithinRun = deduplicateWithinRun; self.configuration = configuration
    }
}

public enum FileOpenPolicy: String, Codable, CaseIterable, Sendable { case open, revealInFinder }
public enum MissingPathPolicy: String, Codable, CaseIterable, Sendable { case fail, warn, skip }
public struct OpenFileAction: Codable, Equatable, Sendable {
    public var id: String; public var path: String; public var securityScopedBookmark: Data?
    public var applicationBundleIdentifier: String?; public var openPolicy: FileOpenPolicy; public var missingPathPolicy: MissingPathPolicy; public var configuration: ActionConfiguration
    public init(id: String = UUID().uuidString, path: String, securityScopedBookmark: Data? = nil, applicationBundleIdentifier: String? = nil, openPolicy: FileOpenPolicy = .open, missingPathPolicy: MissingPathPolicy = .fail, configuration: ActionConfiguration = .init()) {
        self.id = id; self.path = path; self.securityScopedBookmark = securityScopedBookmark; self.applicationBundleIdentifier = applicationBundleIdentifier; self.openPolicy = openPolicy; self.missingPathPolicy = missingPathPolicy; self.configuration = configuration
    }
}

public struct RunProcessAction: Codable, Equatable, Sendable {
    public var id: String; public var executable: String; public var arguments: [String]; public var workingDirectory: String?; public var timeoutSeconds: Double?
    public var environment: [String: EnvironmentValue]; public var expectedExitCodes: Set<Int32>; public var redactionPatterns: [String]; public var approvalFingerprint: String?; public var configuration: ActionConfiguration
    public init(id: String = UUID().uuidString, executable: String, arguments: [String] = [], workingDirectory: String? = nil, timeoutSeconds: Double? = nil, environment: [String: EnvironmentValue] = [:], expectedExitCodes: Set<Int32> = [0], redactionPatterns: [String] = [], approvalFingerprint: String? = nil, configuration: ActionConfiguration = .init()) {
        self.id = id; self.executable = executable; self.arguments = arguments; self.workingDirectory = workingDirectory; self.timeoutSeconds = timeoutSeconds; self.environment = environment; self.expectedExitCodes = expectedExitCodes; self.redactionPatterns = redactionPatterns; self.approvalFingerprint = approvalFingerprint; self.configuration = configuration
    }
}

public enum RestartPolicy: String, Codable, CaseIterable, Sendable { case never, onFailure }
public struct ManagedProcessAction: Codable, Equatable, Sendable {
    public var id: String; public var executable: String; public var arguments: [String]; public var workingDirectory: String?
    public var environment: [String: EnvironmentValue]; public var singleInstanceKey: String; public var restartPolicy: RestartPolicy
    public var gracefulStopSeconds: Double; public var forcedStopSeconds: Double; public var approvalFingerprint: String?; public var configuration: ActionConfiguration
    public init(id: String = UUID().uuidString, executable: String, arguments: [String] = [], workingDirectory: String? = nil, environment: [String: EnvironmentValue] = [:], singleInstanceKey: String, restartPolicy: RestartPolicy = .never, gracefulStopSeconds: Double = 5, forcedStopSeconds: Double = 2, approvalFingerprint: String? = nil, configuration: ActionConfiguration = .init(idempotencyPolicy: .singleInstance)) {
        self.id = id; self.executable = executable; self.arguments = arguments; self.workingDirectory = workingDirectory; self.environment = environment; self.singleInstanceKey = singleInstanceKey; self.restartPolicy = restartPolicy; self.gracefulStopSeconds = gracefulStopSeconds; self.forcedStopSeconds = forcedStopSeconds; self.approvalFingerprint = approvalFingerprint; self.configuration = configuration
    }
}

public struct WaitAction: Codable, Equatable, Sendable {
    public var id: String; public var durationSeconds: Double; public var message: String; public var configuration: ActionConfiguration
    public init(id: String = UUID().uuidString, durationSeconds: Double, message: String = "Waiting", configuration: ActionConfiguration = .init()) { self.id = id; self.durationSeconds = durationSeconds; self.message = message; self.configuration = configuration }
}

public enum EditorChoice: String, Codable, CaseIterable, Sendable { case visualStudioCode, visualStudioCodeInsiders, cursor, vscodium }
public struct EditorLocation: Codable, Equatable, Sendable { public var file: String; public var line: Int?; public var column: Int?; public init(file: String, line: Int? = nil, column: Int? = nil) { self.file = file; self.line = line; self.column = column } }
public struct EditorWorkspaceAction: Codable, Equatable, Sendable {
    public var id: String; public var editor: EditorChoice; public var projectPath: String; public var profile: String?; public var files: [EditorLocation]; public var newWindow: Bool; public var waitForApplication: Bool; public var configuration: ActionConfiguration
    public init(id: String = UUID().uuidString, editor: EditorChoice, projectPath: String, profile: String? = nil, files: [EditorLocation] = [], newWindow: Bool = true, waitForApplication: Bool = true, configuration: ActionConfiguration = .init(idempotencyPolicy: .reuseExisting)) { self.id = id; self.editor = editor; self.projectPath = projectPath; self.profile = profile; self.files = files; self.newWindow = newWindow; self.waitForApplication = waitForApplication; self.configuration = configuration }
}

public enum TerminalChoice: String, Codable, CaseIterable, Sendable { case terminal, iTerm2 }
public struct TerminalWorkspaceAction: Codable, Equatable, Sendable {
    public var id: String; public var terminal: TerminalChoice; public var workingDirectory: String; public var tmuxSessionName: String?; public var stopTmuxOnDeactivate: Bool; public var configuration: ActionConfiguration
    public init(id: String = UUID().uuidString, terminal: TerminalChoice = .terminal, workingDirectory: String, tmuxSessionName: String? = nil, stopTmuxOnDeactivate: Bool = false, configuration: ActionConfiguration = .init(idempotencyPolicy: .reuseExisting)) { self.id = id; self.terminal = terminal; self.workingDirectory = workingDirectory; self.tmuxSessionName = tmuxSessionName; self.stopTmuxOnDeactivate = stopTmuxOnDeactivate; self.configuration = configuration }
}

public enum DockerPullPolicy: String, Codable, CaseIterable, Sendable { case missing, always, never }
public enum DockerStopPolicy: String, Codable, CaseIterable, Sendable { case stop, down }
public struct DockerComposeAction: Codable, Equatable, Sendable {
    public var id: String; public var projectDirectory: String; public var composeFile: String?; public var services: [String]; public var profiles: [String]; public var build: Bool; public var pullPolicy: DockerPullPolicy; public var environmentFile: String?; public var stopPolicy: DockerStopPolicy; public var removeVolumes: Bool; public var configuration: ActionConfiguration
    public init(id: String = UUID().uuidString, projectDirectory: String, composeFile: String? = nil, services: [String] = [], profiles: [String] = [], build: Bool = false, pullPolicy: DockerPullPolicy = .missing, environmentFile: String? = nil, stopPolicy: DockerStopPolicy = .stop, removeVolumes: Bool = false, configuration: ActionConfiguration = .init(idempotencyPolicy: .reuseExisting)) { self.id = id; self.projectDirectory = projectDirectory; self.composeFile = composeFile; self.services = services; self.profiles = profiles; self.build = build; self.pullPolicy = pullPolicy; self.environmentFile = environmentFile; self.stopPolicy = stopPolicy; self.removeVolumes = removeVolumes; self.configuration = configuration }
}

public struct ShortcutAction: Codable, Equatable, Sendable {
    public var id: String; public var name: String; public var inputFile: String?; public var configuration: ActionConfiguration
    public init(id: String = UUID().uuidString, name: String, inputFile: String? = nil, configuration: ActionConfiguration = .init(idempotencyPolicy: .alwaysRun)) { self.id = id; self.name = name; self.inputFile = inputFile; self.configuration = configuration }
}

public struct NormalizedFrame: Codable, Equatable, Sendable {
    public var x: Double; public var y: Double; public var width: Double; public var height: Double
    public init(x: Double, y: Double, width: Double, height: Double) { self.x = x; self.y = y; self.width = width; self.height = height }
}
public enum WindowMatchRule: String, Codable, CaseIterable, Sendable { case appFrontmost, exactTitle, titleContains }
public struct WindowPlacement: Codable, Equatable, Identifiable, Sendable {
    public var id: String; public var bundleIdentifier: String; public var matchRule: WindowMatchRule; public var title: String?; public var frame: NormalizedFrame; public var displayIdentifier: String?; public var minimized: Bool
    public init(id: String = UUID().uuidString, bundleIdentifier: String, matchRule: WindowMatchRule = .appFrontmost, title: String? = nil, frame: NormalizedFrame, displayIdentifier: String? = nil, minimized: Bool = false) { self.id = id; self.bundleIdentifier = bundleIdentifier; self.matchRule = matchRule; self.title = title; self.frame = frame; self.displayIdentifier = displayIdentifier; self.minimized = minimized }
}
public struct WindowLayoutAction: Codable, Equatable, Sendable {
    public var id: String; public var placements: [WindowPlacement]; public var missingWindowPolicy: MissingPathPolicy; public var configuration: ActionConfiguration
    public init(id: String = UUID().uuidString, placements: [WindowPlacement], missingWindowPolicy: MissingPathPolicy = .warn, configuration: ActionConfiguration = .init(idempotencyPolicy: .reapply)) { self.id = id; self.placements = placements; self.missingWindowPolicy = missingWindowPolicy; self.configuration = configuration }
}

extension SceneAction: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, id, configuration, bundleIdentifier, applicationPathFallback, launchPolicy, activate, waitForRunning, launchTimeoutSeconds, terminateIfOwnedOnStop
        case url, additionalURLs, browserBundleIdentifier, windowPolicy, delayBetweenURLsSeconds, deduplicateWithinRun
        case path, securityScopedBookmark, applicationBundleIdentifier, openPolicy, missingPathPolicy
        case executable, arguments, workingDirectory, timeoutSeconds, environment, expectedExitCodes, redactionPatterns, approvalFingerprint
        case singleInstanceKey, restartPolicy, gracefulStopSeconds, forcedStopSeconds, durationSeconds, message
        case editor, projectPath, profile, files, newWindow, waitForApplication
        case terminal, tmuxSessionName, stopTmuxOnDeactivate
        case projectDirectory, composeFile, services, profiles, build, pullPolicy, environmentFile, stopPolicy, removeVolumes
        case name, inputFile, placements
    }
    private enum ActionType: String, Codable { case openApplication, openURL, openFile, runProcess, managedProcess, wait, editorWorkspace, terminalWorkspace, dockerCompose, shortcut, windowLayout }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(ActionType.self, forKey: .type)
        let id = try c.decode(String.self, forKey: .id)
        let config = try c.decodeIfPresent(ActionConfiguration.self, forKey: .configuration) ?? .init(timeoutSeconds: try c.decodeIfPresent(Double.self, forKey: .timeoutSeconds))
        switch type {
        case .openApplication: self = .openApplication(.init(id: id, bundleIdentifier: try c.decode(String.self, forKey: .bundleIdentifier), applicationPathFallback: try c.decodeIfPresent(String.self, forKey: .applicationPathFallback), launchPolicy: try c.decodeIfPresent(ApplicationLaunchPolicy.self, forKey: .launchPolicy) ?? .reuse, activate: try c.decodeIfPresent(Bool.self, forKey: .activate) ?? true, waitForRunning: try c.decodeIfPresent(Bool.self, forKey: .waitForRunning) ?? true, launchTimeoutSeconds: try c.decodeIfPresent(Double.self, forKey: .launchTimeoutSeconds), terminateIfOwnedOnStop: try c.decodeIfPresent(Bool.self, forKey: .terminateIfOwnedOnStop) ?? false, configuration: config))
        case .openURL: self = .openURL(.init(id: id, url: try c.decode(String.self, forKey: .url), additionalURLs: try c.decodeIfPresent([String].self, forKey: .additionalURLs) ?? [], browserBundleIdentifier: try c.decodeIfPresent(String.self, forKey: .browserBundleIdentifier), windowPolicy: try c.decodeIfPresent(BrowserWindowPolicy.self, forKey: .windowPolicy) ?? .existing, delayBetweenURLsSeconds: try c.decodeIfPresent(Double.self, forKey: .delayBetweenURLsSeconds) ?? 0, deduplicateWithinRun: try c.decodeIfPresent(Bool.self, forKey: .deduplicateWithinRun) ?? true, configuration: config))
        case .openFile: self = .openFile(.init(id: id, path: try c.decode(String.self, forKey: .path), securityScopedBookmark: try c.decodeIfPresent(Data.self, forKey: .securityScopedBookmark), applicationBundleIdentifier: try c.decodeIfPresent(String.self, forKey: .applicationBundleIdentifier), openPolicy: try c.decodeIfPresent(FileOpenPolicy.self, forKey: .openPolicy) ?? .open, missingPathPolicy: try c.decodeIfPresent(MissingPathPolicy.self, forKey: .missingPathPolicy) ?? .fail, configuration: config))
        case .runProcess: self = .runProcess(.init(id: id, executable: try c.decode(String.self, forKey: .executable), arguments: try c.decodeIfPresent([String].self, forKey: .arguments) ?? [], workingDirectory: try c.decodeIfPresent(String.self, forKey: .workingDirectory), timeoutSeconds: try c.decodeIfPresent(Double.self, forKey: .timeoutSeconds), environment: try c.decodeIfPresent([String: EnvironmentValue].self, forKey: .environment) ?? [:], expectedExitCodes: try c.decodeIfPresent(Set<Int32>.self, forKey: .expectedExitCodes) ?? [0], redactionPatterns: try c.decodeIfPresent([String].self, forKey: .redactionPatterns) ?? [], approvalFingerprint: try c.decodeIfPresent(String.self, forKey: .approvalFingerprint), configuration: config))
        case .managedProcess: self = .managedProcess(.init(id: id, executable: try c.decode(String.self, forKey: .executable), arguments: try c.decodeIfPresent([String].self, forKey: .arguments) ?? [], workingDirectory: try c.decodeIfPresent(String.self, forKey: .workingDirectory), environment: try c.decodeIfPresent([String: EnvironmentValue].self, forKey: .environment) ?? [:], singleInstanceKey: try c.decode(String.self, forKey: .singleInstanceKey), restartPolicy: try c.decodeIfPresent(RestartPolicy.self, forKey: .restartPolicy) ?? .never, gracefulStopSeconds: try c.decodeIfPresent(Double.self, forKey: .gracefulStopSeconds) ?? 5, forcedStopSeconds: try c.decodeIfPresent(Double.self, forKey: .forcedStopSeconds) ?? 2, approvalFingerprint: try c.decodeIfPresent(String.self, forKey: .approvalFingerprint), configuration: config))
        case .wait: self = .wait(.init(id: id, durationSeconds: try c.decode(Double.self, forKey: .durationSeconds), message: try c.decodeIfPresent(String.self, forKey: .message) ?? "Waiting", configuration: config))
        case .editorWorkspace: self = .editorWorkspace(.init(id: id, editor: try c.decode(EditorChoice.self, forKey: .editor), projectPath: try c.decode(String.self, forKey: .projectPath), profile: try c.decodeIfPresent(String.self, forKey: .profile), files: try c.decodeIfPresent([EditorLocation].self, forKey: .files) ?? [], newWindow: try c.decodeIfPresent(Bool.self, forKey: .newWindow) ?? true, waitForApplication: try c.decodeIfPresent(Bool.self, forKey: .waitForApplication) ?? true, configuration: config))
        case .terminalWorkspace: self = .terminalWorkspace(.init(id: id, terminal: try c.decodeIfPresent(TerminalChoice.self, forKey: .terminal) ?? .terminal, workingDirectory: try c.decode(String.self, forKey: .workingDirectory), tmuxSessionName: try c.decodeIfPresent(String.self, forKey: .tmuxSessionName), stopTmuxOnDeactivate: try c.decodeIfPresent(Bool.self, forKey: .stopTmuxOnDeactivate) ?? false, configuration: config))
        case .dockerCompose: self = .dockerCompose(.init(id: id, projectDirectory: try c.decode(String.self, forKey: .projectDirectory), composeFile: try c.decodeIfPresent(String.self, forKey: .composeFile), services: try c.decodeIfPresent([String].self, forKey: .services) ?? [], profiles: try c.decodeIfPresent([String].self, forKey: .profiles) ?? [], build: try c.decodeIfPresent(Bool.self, forKey: .build) ?? false, pullPolicy: try c.decodeIfPresent(DockerPullPolicy.self, forKey: .pullPolicy) ?? .missing, environmentFile: try c.decodeIfPresent(String.self, forKey: .environmentFile), stopPolicy: try c.decodeIfPresent(DockerStopPolicy.self, forKey: .stopPolicy) ?? .stop, removeVolumes: try c.decodeIfPresent(Bool.self, forKey: .removeVolumes) ?? false, configuration: config))
        case .shortcut: self = .shortcut(.init(id: id, name: try c.decode(String.self, forKey: .name), inputFile: try c.decodeIfPresent(String.self, forKey: .inputFile), configuration: config))
        case .windowLayout: self = .windowLayout(.init(id: id, placements: try c.decode([WindowPlacement].self, forKey: .placements), missingWindowPolicy: try c.decodeIfPresent(MissingPathPolicy.self, forKey: .missingPathPolicy) ?? .warn, configuration: config))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        func common(_ type: ActionType, _ id: String, _ configuration: ActionConfiguration) throws { try c.encode(type, forKey: .type); try c.encode(id, forKey: .id); try c.encode(configuration, forKey: .configuration) }
        switch self {
        case .openApplication(let v): try common(.openApplication, v.id, v.configuration); try c.encode(v.bundleIdentifier, forKey: .bundleIdentifier); try c.encodeIfPresent(v.applicationPathFallback, forKey: .applicationPathFallback); try c.encode(v.launchPolicy, forKey: .launchPolicy); try c.encode(v.activate, forKey: .activate); try c.encode(v.waitForRunning, forKey: .waitForRunning); try c.encodeIfPresent(v.launchTimeoutSeconds, forKey: .launchTimeoutSeconds); try c.encode(v.terminateIfOwnedOnStop, forKey: .terminateIfOwnedOnStop)
        case .openURL(let v): try common(.openURL, v.id, v.configuration); try c.encode(v.url, forKey: .url); try c.encode(v.additionalURLs, forKey: .additionalURLs); try c.encodeIfPresent(v.browserBundleIdentifier, forKey: .browserBundleIdentifier); try c.encode(v.windowPolicy, forKey: .windowPolicy); try c.encode(v.delayBetweenURLsSeconds, forKey: .delayBetweenURLsSeconds); try c.encode(v.deduplicateWithinRun, forKey: .deduplicateWithinRun)
        case .openFile(let v): try common(.openFile, v.id, v.configuration); try c.encode(v.path, forKey: .path); try c.encodeIfPresent(v.securityScopedBookmark, forKey: .securityScopedBookmark); try c.encodeIfPresent(v.applicationBundleIdentifier, forKey: .applicationBundleIdentifier); try c.encode(v.openPolicy, forKey: .openPolicy); try c.encode(v.missingPathPolicy, forKey: .missingPathPolicy)
        case .runProcess(let v): try common(.runProcess, v.id, v.configuration); try encodeProcess(v.executable, v.arguments, v.workingDirectory, v.environment, v.approvalFingerprint, to: &c); try c.encodeIfPresent(v.timeoutSeconds, forKey: .timeoutSeconds); try c.encode(v.expectedExitCodes, forKey: .expectedExitCodes); try c.encode(v.redactionPatterns, forKey: .redactionPatterns)
        case .managedProcess(let v): try common(.managedProcess, v.id, v.configuration); try encodeProcess(v.executable, v.arguments, v.workingDirectory, v.environment, v.approvalFingerprint, to: &c); try c.encode(v.singleInstanceKey, forKey: .singleInstanceKey); try c.encode(v.restartPolicy, forKey: .restartPolicy); try c.encode(v.gracefulStopSeconds, forKey: .gracefulStopSeconds); try c.encode(v.forcedStopSeconds, forKey: .forcedStopSeconds)
        case .wait(let v): try common(.wait, v.id, v.configuration); try c.encode(v.durationSeconds, forKey: .durationSeconds); try c.encode(v.message, forKey: .message)
        case .editorWorkspace(let v): try common(.editorWorkspace, v.id, v.configuration); try c.encode(v.editor, forKey: .editor); try c.encode(v.projectPath, forKey: .projectPath); try c.encodeIfPresent(v.profile, forKey: .profile); try c.encode(v.files, forKey: .files); try c.encode(v.newWindow, forKey: .newWindow); try c.encode(v.waitForApplication, forKey: .waitForApplication)
        case .terminalWorkspace(let v): try common(.terminalWorkspace, v.id, v.configuration); try c.encode(v.terminal, forKey: .terminal); try c.encode(v.workingDirectory, forKey: .workingDirectory); try c.encodeIfPresent(v.tmuxSessionName, forKey: .tmuxSessionName); try c.encode(v.stopTmuxOnDeactivate, forKey: .stopTmuxOnDeactivate)
        case .dockerCompose(let v): try common(.dockerCompose, v.id, v.configuration); try c.encode(v.projectDirectory, forKey: .projectDirectory); try c.encodeIfPresent(v.composeFile, forKey: .composeFile); try c.encode(v.services, forKey: .services); try c.encode(v.profiles, forKey: .profiles); try c.encode(v.build, forKey: .build); try c.encode(v.pullPolicy, forKey: .pullPolicy); try c.encodeIfPresent(v.environmentFile, forKey: .environmentFile); try c.encode(v.stopPolicy, forKey: .stopPolicy); try c.encode(v.removeVolumes, forKey: .removeVolumes)
        case .shortcut(let v): try common(.shortcut, v.id, v.configuration); try c.encode(v.name, forKey: .name); try c.encodeIfPresent(v.inputFile, forKey: .inputFile)
        case .windowLayout(let v): try common(.windowLayout, v.id, v.configuration); try c.encode(v.placements, forKey: .placements); try c.encode(v.missingWindowPolicy, forKey: .missingPathPolicy)
        }
    }

    private func encodeProcess(_ executable: String, _ arguments: [String], _ directory: String?, _ environment: [String: EnvironmentValue], _ fingerprint: String?, to c: inout KeyedEncodingContainer<CodingKeys>) throws {
        try c.encode(executable, forKey: .executable); try c.encode(arguments, forKey: .arguments); try c.encodeIfPresent(directory, forKey: .workingDirectory); try c.encode(environment, forKey: .environment); try c.encodeIfPresent(fingerprint, forKey: .approvalFingerprint)
    }
}
