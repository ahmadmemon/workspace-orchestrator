import Foundation

public struct SceneArchive: Codable, Equatable, Sendable {
    public static let currentFormatVersion = 1
    public var formatVersion: Int; public var exportedAt: Date; public var appVersion: String; public var scenes: [Scene]
    public init(formatVersion: Int = currentFormatVersion, exportedAt: Date = Date(), appVersion: String, scenes: [Scene]) { self.formatVersion = formatVersion; self.exportedAt = exportedAt; self.appVersion = appVersion; self.scenes = scenes }
}

public struct SceneImportPreview: Equatable, Sendable {
    public var scenes: [Scene]; public var applications: [String]; public var urls: [String]; public var paths: [String]
    public var executables: [String]; public var destructiveActions: [String]; public var requiredPermissions: [String]
}

public enum SceneArchiveError: LocalizedError {
    case unsupportedVersion(Int); case empty; case invalid(String)
    public var errorDescription: String? {
        switch self { case .unsupportedVersion(let version): "Unsupported scene archive version \(version)."; case .empty: "The archive contains no scenes."; case .invalid(let message): "Scene archive is invalid: \(message)" }
    }
}

public enum SceneArchiveService {
    public static func export(_ scenes: [Scene], appVersion: String) throws -> Data {
        guard !scenes.isEmpty else { throw SceneArchiveError.empty }
        for scene in scenes { try SceneValidator.validate(scene) }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(SceneArchive(appVersion: appVersion, scenes: scenes))
    }

    public static func previewImport(_ data: Data, regenerateIDs: Bool = false) throws -> SceneImportPreview {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let archive: SceneArchive
        do { archive = try decoder.decode(SceneArchive.self, from: data) } catch { throw SceneArchiveError.invalid(error.localizedDescription) }
        guard archive.formatVersion == SceneArchive.currentFormatVersion else { throw SceneArchiveError.unsupportedVersion(archive.formatVersion) }
        guard !archive.scenes.isEmpty else { throw SceneArchiveError.empty }
        var scenes = archive.scenes
        for index in scenes.indices {
            scenes[index].trustState = .importedUntrusted
            if regenerateIDs {
                scenes[index].id = UUID().uuidString
                // Action IDs remain stable so dependencies stay valid within the imported scene.
            }
            try SceneValidator.validate(scenes[index])
        }
        var apps = Set<String>(), urls = Set<String>(), paths = Set<String>(), executables = Set<String>(), destructive = Set<String>(), permissions = Set<String>()
        for action in scenes.flatMap({ $0.actions + $0.deactivationActions }) {
            switch action {
            case .openApplication(let value): apps.insert(value.bundleIdentifier)
            case .openURL(let value): value.urls.forEach { urls.insert($0) }
            case .openFile(let value): paths.insert(value.path)
            case .runProcess(let value): executables.insert(value.executable)
            case .managedProcess(let value): executables.insert(value.executable)
            case .wait: break
            case .editorWorkspace(let value): paths.insert(value.projectPath)
            case .terminalWorkspace(let value): paths.insert(value.workingDirectory)
            case .dockerCompose(let value): executables.insert("docker compose"); paths.insert(value.projectDirectory); if value.removeVolumes { destructive.insert("Docker volume removal") }
            case .shortcut(let value): executables.insert("/usr/bin/shortcuts"); if let input = value.inputFile { paths.insert(input) }
            case .windowLayout: permissions.insert("Accessibility")
            }
        }
        return .init(scenes: scenes, applications: apps.sorted(), urls: urls.sorted(), paths: paths.sorted(), executables: executables.sorted(), destructiveActions: destructive.sorted(), requiredPermissions: permissions.sorted())
    }
}
