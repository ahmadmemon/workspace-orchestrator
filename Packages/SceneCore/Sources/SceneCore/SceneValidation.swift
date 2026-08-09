import Foundation

public struct ValidationIssue: Codable, Equatable, Error, Sendable {
    public let path: String
    public let message: String

    public init(path: String, message: String) {
        self.path = path
        self.message = message
    }
}

public struct SceneValidationError: LocalizedError, Equatable, Sendable {
    public let issues: [ValidationIssue]

    public init(issues: [ValidationIssue]) {
        self.issues = issues
    }

    public var errorDescription: String? {
        issues.map { "\($0.path): \($0.message)" }.joined(separator: "\n")
    }
}

public enum SceneValidator {
    public static func validate(_ scene: Scene) throws {
        let issues = issues(in: scene)
        if !issues.isEmpty {
            throw SceneValidationError(issues: issues)
        }
    }

    public static func issues(in scene: Scene) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if scene.schemaVersion != Scene.currentSchemaVersion {
            issues.append(.init(path: "schemaVersion", message: "Unsupported schema version \(scene.schemaVersion)."))
        }
        if scene.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(path: "id", message: "Scene ID must not be empty."))
        }
        if scene.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(path: "name", message: "Scene name must not be empty."))
        }

        var seenIDs = Set<String>()
        for (index, action) in scene.actions.enumerated() {
            let path = "actions[\(index)]"
            if action.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(path: "\(path).id", message: "Action ID must not be empty."))
            } else if !seenIDs.insert(action.id).inserted {
                issues.append(.init(path: "\(path).id", message: "Action ID must be unique."))
            }

            switch action {
            case .openApplication(let value):
                if !isValidBundleIdentifier(value.bundleIdentifier) {
                    issues.append(.init(path: "\(path).bundleIdentifier", message: "Enter a valid bundle identifier such as com.apple.TextEdit."))
                }
            case .openURL(let value):
                if !isValidURL(value.url) {
                    issues.append(.init(path: "\(path).url", message: "Enter an absolute http or https URL."))
                }
            case .runProcess(let value):
                if value.executable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append(.init(path: "\(path).executable", message: "Executable is required."))
                } else if !value.executable.hasPrefix("/") {
                    issues.append(.init(path: "\(path).executable", message: "Executable must be an absolute path."))
                }
                if let directory = value.workingDirectory, !directory.isEmpty, !directory.hasPrefix("/") {
                    issues.append(.init(path: "\(path).workingDirectory", message: "Working directory must be an absolute path."))
                }
                if let timeout = value.timeoutSeconds, timeout <= 0 {
                    issues.append(.init(path: "\(path).timeoutSeconds", message: "Timeout must be greater than zero."))
                }
            }
        }
        return issues
    }

    private static func isValidURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host?.isEmpty == false else { return false }
        return true
    }

    private static func isValidBundleIdentifier(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        return parts.allSatisfy { part in
            !part.isEmpty && part.unicodeScalars.allSatisfy(allowed.contains)
        }
    }
}
