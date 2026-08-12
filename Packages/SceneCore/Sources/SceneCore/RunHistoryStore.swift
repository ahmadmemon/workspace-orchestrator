import Foundation

public struct RunHistoryRetention: Codable, Equatable, Sendable {
    public var maximumRunCount: Int; public var retentionDays: Int; public var retainOutputSummaries: Bool
    public init(maximumRunCount: Int = 200, retentionDays: Int = 30, retainOutputSummaries: Bool = true) { self.maximumRunCount = maximumRunCount; self.retentionDays = retentionDays; self.retainOutputSummaries = retainOutputSummaries }
}

public protocol RunHistoryStoring: Sendable {
    func save(_ run: SceneRunResult) async throws
    func loadRuns() async throws -> [SceneRunResult]
    func delete(id: String) async throws
    func clear() async throws
}

public enum RunHistoryError: LocalizedError {
    case fileSystem(String); case corruptFiles([String])
    public var errorDescription: String? { switch self { case .fileSystem(let message): "Run history storage failed: \(message)"; case .corruptFiles(let files): "Some run history files are corrupt and were preserved: \(files.joined(separator: ", "))" } }
}

public actor JSONRunHistoryStore: RunHistoryStoring {
    public let directoryURL: URL; public let retention: RunHistoryRetention
    private let encoder: JSONEncoder; private let decoder: JSONDecoder
    public init(directoryURL: URL, retention: RunHistoryRetention = .init()) {
        self.directoryURL = directoryURL; self.retention = retention
        encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    }
    public static func applicationSupportStore(retention: RunHistoryRetention = .init()) throws -> JSONRunHistoryStore {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { throw RunHistoryError.fileSystem("Application Support is unavailable.") }
        return .init(directoryURL: base.appendingPathComponent("WorkspaceOrchestrator/RunHistory", isDirectory: true), retention: retention)
    }
    public func save(_ run: SceneRunResult) async throws {
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            var safe = run
            for index in safe.actionRecords.indices {
                safe.actionRecords[index].processResult = nil
                if !retention.retainOutputSummaries { safe.actionRecords[index].outputSummary = nil }
                else if let summary = safe.actionRecords[index].outputSummary { safe.actionRecords[index].outputSummary = Redactor.redact(summary) }
                if let message = safe.actionRecords[index].errorMessage { safe.actionRecords[index].errorMessage = Redactor.redact(message) }
            }
            if let message = safe.errorMessage { safe.errorMessage = Redactor.redact(message) }
            try encoder.encode(safe).write(to: directoryURL.appendingPathComponent("\(safe.id).json"), options: .atomic)
            try prune()
        } catch { throw RunHistoryError.fileSystem(error.localizedDescription) }
    }
    public func loadRuns() async throws -> [SceneRunResult] {
        guard FileManager.default.fileExists(atPath: directoryURL.path) else { return [] }
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }
            var runs: [SceneRunResult] = [], corrupt: [String] = []
            for file in files { do { runs.append(try decoder.decode(SceneRunResult.self, from: Data(contentsOf: file))) } catch { corrupt.append(file.lastPathComponent) } }
            if !corrupt.isEmpty { throw RunHistoryError.corruptFiles(corrupt) }
            return runs.sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
        } catch let error as RunHistoryError { throw error } catch { throw RunHistoryError.fileSystem(error.localizedDescription) }
    }
    public func delete(id: String) async throws { do { let file = directoryURL.appendingPathComponent("\(id).json"); if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) } } catch { throw RunHistoryError.fileSystem(error.localizedDescription) } }
    public func clear() async throws { do { guard FileManager.default.fileExists(atPath: directoryURL.path) else { return }; for file in try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil) where file.pathExtension == "json" { try FileManager.default.removeItem(at: file) } } catch { throw RunHistoryError.fileSystem(error.localizedDescription) } }
    private func prune() throws {
        let files = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.contentModificationDateKey]).filter { $0.pathExtension == "json" }
        let cutoff = Calendar.current.date(byAdding: .day, value: -max(1, retention.retentionDays), to: Date()) ?? .distantPast
        let dated = try files.map { ($0, try $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast) }.sorted { $0.1 > $1.1 }
        for (index, item) in dated.enumerated() where index >= max(1, retention.maximumRunCount) || item.1 < cutoff { try FileManager.default.removeItem(at: item.0) }
    }
}
