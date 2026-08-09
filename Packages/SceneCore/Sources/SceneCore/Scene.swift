import Foundation

public struct Scene: Codable, Equatable, Identifiable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var id: String
    public var name: String
    public var description: String?
    public var actions: [SceneAction]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        schemaVersion: Int = Scene.currentSchemaVersion,
        id: String = UUID().uuidString,
        name: String,
        description: String? = nil,
        actions: [SceneAction] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.description = description
        self.actions = actions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum SceneAction: Equatable, Identifiable, Sendable {
    case openApplication(OpenApplicationAction)
    case openURL(OpenURLAction)
    case runProcess(RunProcessAction)

    public var id: String {
        switch self {
        case .openApplication(let action): action.id
        case .openURL(let action): action.id
        case .runProcess(let action): action.id
        }
    }

    public var displayName: String {
        switch self {
        case .openApplication: "Open Application"
        case .openURL: "Open URL"
        case .runProcess: "Run Process"
        }
    }
}

public struct OpenApplicationAction: Codable, Equatable, Sendable {
    public var id: String
    public var bundleIdentifier: String

    public init(id: String = UUID().uuidString, bundleIdentifier: String) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
    }
}

public struct OpenURLAction: Codable, Equatable, Sendable {
    public var id: String
    public var url: String

    public init(id: String = UUID().uuidString, url: String) {
        self.id = id
        self.url = url
    }
}

public struct RunProcessAction: Codable, Equatable, Sendable {
    public var id: String
    public var executable: String
    public var arguments: [String]
    public var workingDirectory: String?
    public var timeoutSeconds: Double?

    public init(
        id: String = UUID().uuidString,
        executable: String,
        arguments: [String] = [],
        workingDirectory: String? = nil,
        timeoutSeconds: Double? = nil
    ) {
        self.id = id
        self.executable = executable
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.timeoutSeconds = timeoutSeconds
    }
}

extension SceneAction: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, id, bundleIdentifier, url, executable, arguments, workingDirectory, timeoutSeconds
    }

    private enum ActionType: String, Codable {
        case openApplication, openURL, runProcess
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ActionType.self, forKey: .type)
        let id = try container.decode(String.self, forKey: .id)
        switch type {
        case .openApplication:
            self = .openApplication(.init(
                id: id,
                bundleIdentifier: try container.decode(String.self, forKey: .bundleIdentifier)
            ))
        case .openURL:
            self = .openURL(.init(
                id: id,
                url: try container.decode(String.self, forKey: .url)
            ))
        case .runProcess:
            self = .runProcess(.init(
                id: id,
                executable: try container.decode(String.self, forKey: .executable),
                arguments: try container.decode([String].self, forKey: .arguments),
                workingDirectory: try container.decodeIfPresent(String.self, forKey: .workingDirectory),
                timeoutSeconds: try container.decodeIfPresent(Double.self, forKey: .timeoutSeconds)
            ))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .openApplication(let action):
            try container.encode(ActionType.openApplication, forKey: .type)
            try container.encode(action.id, forKey: .id)
            try container.encode(action.bundleIdentifier, forKey: .bundleIdentifier)
        case .openURL(let action):
            try container.encode(ActionType.openURL, forKey: .type)
            try container.encode(action.id, forKey: .id)
            try container.encode(action.url, forKey: .url)
        case .runProcess(let action):
            try container.encode(ActionType.runProcess, forKey: .type)
            try container.encode(action.id, forKey: .id)
            try container.encode(action.executable, forKey: .executable)
            try container.encode(action.arguments, forKey: .arguments)
            try container.encodeIfPresent(action.workingDirectory, forKey: .workingDirectory)
            try container.encodeIfPresent(action.timeoutSeconds, forKey: .timeoutSeconds)
        }
    }
}
