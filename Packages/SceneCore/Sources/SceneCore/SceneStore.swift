import Foundation

public protocol SceneStoring: Sendable {
    func loadScenes() async throws -> [Scene]
    func save(_ scene: Scene) async throws
    func deleteScene(id: String) async throws
}

public enum SceneStoreError: LocalizedError, Equatable {
    case corruptData(String)
    case fileSystem(String)
    case migration(String)

    public var errorDescription: String? {
        switch self {
        case .corruptData(let message): "Stored scene data is invalid: \(message)"
        case .fileSystem(let message): "Scene storage failed: \(message)"
        case .migration(let message): "Scene migration failed without changing the original data: \(message)"
        }
    }
}

public actor JSONSceneStore: SceneStoring {
    public let directoryURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public static func applicationSupportStore() throws -> JSONSceneStore {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw SceneStoreError.fileSystem("Application Support directory is unavailable.")
        }
        return JSONSceneStore(
            directoryURL: base.appendingPathComponent("WorkspaceOrchestrator", isDirectory: true)
        )
    }

    public func loadScenes() async throws -> [Scene] {
        let fileURL = directoryURL.appendingPathComponent("scenes.json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            let requiresMigration = try containsLegacyScene(in: data)
            let scenes = try decoder.decode([Scene].self, from: data)
            for scene in scenes { try SceneValidator.validate(scene) }
            if requiresMigration {
                try migrate(originalData: data, migratedScenes: scenes)
            }
            return scenes.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch let error as SceneValidationError {
            throw SceneStoreError.corruptData(error.localizedDescription)
        } catch let error as DecodingError {
            throw SceneStoreError.corruptData(String(describing: error))
        } catch let error as SceneStoreError {
            throw error
        } catch {
            throw SceneStoreError.fileSystem(error.localizedDescription)
        }
    }

    public func save(_ scene: Scene) async throws {
        try SceneValidator.validate(scene)
        var scenes = try await loadScenes()
        if let index = scenes.firstIndex(where: { $0.id == scene.id }) {
            scenes[index] = scene
        } else {
            scenes.append(scene)
        }
        try write(scenes)
    }

    public func deleteScene(id: String) async throws {
        var scenes = try await loadScenes()
        scenes.removeAll { $0.id == id }
        try write(scenes)
    }

    private func write(_ scenes: [Scene]) throws {
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let data = try encoder.encode(scenes)
            try data.write(to: directoryURL.appendingPathComponent("scenes.json"), options: .atomic)
        } catch {
            throw SceneStoreError.fileSystem(error.localizedDescription)
        }
    }

    private func containsLegacyScene(in data: Data) throws -> Bool {
        do {
            guard let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { throw SceneStoreError.corruptData("The root value must be a scene array.") }
            return array.contains { ($0["schemaVersion"] as? Int ?? 1) < Scene.currentSchemaVersion }
        } catch let error as SceneStoreError { throw error }
        catch { throw SceneStoreError.corruptData(error.localizedDescription) }
    }

    private func migrate(originalData: Data, migratedScenes: [Scene]) throws {
        do {
            let backupDirectory = directoryURL.appendingPathComponent("migration-backups", isDirectory: true)
            try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            let formatter = ISO8601DateFormatter()
            let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let backupURL = backupDirectory.appendingPathComponent("scenes-v1-\(stamp).json")
            try originalData.write(to: backupURL, options: .withoutOverwriting)
            try write(migratedScenes)
        } catch {
            throw SceneStoreError.migration(error.localizedDescription)
        }
    }
}
