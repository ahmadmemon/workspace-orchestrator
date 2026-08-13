import Foundation

public struct RunHistoryRetention: Codable, Equatable, Sendable {
    public var maximumRunCount: Int
    public var retentionDays: Int
    public var retainOutputSummaries: Bool
    public var maximumOutputBytesPerAction: Int

    public init(maximumRunCount: Int = 200, retentionDays: Int = 30, retainOutputSummaries: Bool = true, maximumOutputBytesPerAction: Int = 32_768) {
        self.maximumRunCount = max(1, maximumRunCount)
        self.retentionDays = max(1, retentionDays)
        self.retainOutputSummaries = retainOutputSummaries
        self.maximumOutputBytesPerAction = max(0, maximumOutputBytesPerAction)
    }

    private enum CodingKeys: String, CodingKey { case maximumRunCount, retentionDays, retainOutputSummaries, maximumOutputBytesPerAction }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            maximumRunCount: try container.decodeIfPresent(Int.self, forKey: .maximumRunCount) ?? 200,
            retentionDays: try container.decodeIfPresent(Int.self, forKey: .retentionDays) ?? 30,
            retainOutputSummaries: try container.decodeIfPresent(Bool.self, forKey: .retainOutputSummaries) ?? true,
            maximumOutputBytesPerAction: try container.decodeIfPresent(Int.self, forKey: .maximumOutputBytesPerAction) ?? 32_768
        )
    }
}

public struct RunHistoryPruneResult: Equatable, Sendable {
    public var deletedRunIDs: [String]
    public var preservedActiveRunIDs: [String]
    public var corruptFileNames: [String]
    public init(deletedRunIDs: [String] = [], preservedActiveRunIDs: [String] = [], corruptFileNames: [String] = []) {
        self.deletedRunIDs = deletedRunIDs
        self.preservedActiveRunIDs = preservedActiveRunIDs
        self.corruptFileNames = corruptFileNames
    }
}

public protocol RunHistoryStoring: Sendable {
    func save(_ run: SceneRunResult) async throws
    func loadRuns() async throws -> [SceneRunResult]
    func delete(id: String) async throws
    func delete(ids: [String]) async throws
    func clear() async throws
    func prune(referenceDate: Date) async throws -> RunHistoryPruneResult
    func storageUsageBytes() async throws -> Int64
    func corruptFileNames() async throws -> [String]
    func updateRetention(_ retention: RunHistoryRetention) async
}

public extension RunHistoryStoring {
    func delete(ids: [String]) async throws { for id in ids { try await delete(id: id) } }
    func prune(referenceDate: Date = Date()) async throws -> RunHistoryPruneResult { .init() }
    func storageUsageBytes() async throws -> Int64 { 0 }
    func corruptFileNames() async throws -> [String] { [] }
    func updateRetention(_ retention: RunHistoryRetention) async {}
}

public enum RunHistoryError: LocalizedError {
    case fileSystem(String)
    case corruptFiles([String])
    public var errorDescription: String? {
        switch self {
        case .fileSystem(let message): "Run history storage failed: \(message)"
        case .corruptFiles(let files): "Some run history files are corrupt and were preserved: \(files.joined(separator: ", "))"
        }
    }
}

public actor JSONRunHistoryStore: RunHistoryStoring {
    public let directoryURL: URL
    public private(set) var retention: RunHistoryRetention
    private let calendar: Calendar
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(directoryURL: URL, retention: RunHistoryRetention = .init(), calendar: Calendar = .current) {
        self.directoryURL = directoryURL
        self.retention = retention
        self.calendar = calendar
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public static func applicationSupportStore(retention: RunHistoryRetention = .init()) throws -> JSONRunHistoryStore {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw RunHistoryError.fileSystem("Application Support is unavailable.")
        }
        return .init(directoryURL: base.appendingPathComponent("WorkspaceOrchestrator/RunHistory", isDirectory: true), retention: retention)
    }

    public func updateRetention(_ retention: RunHistoryRetention) async { self.retention = retention }

    public func save(_ run: SceneRunResult) async throws {
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let safe = sanitized(run)
            try encoder.encode(safe).write(to: directoryURL.appendingPathComponent("\(safe.id).json"), options: .atomic)
            _ = try pruneFiles(referenceDate: Date())
        } catch let error as RunHistoryError {
            throw error
        } catch {
            throw RunHistoryError.fileSystem(error.localizedDescription)
        }
    }

    public func loadRuns() async throws -> [SceneRunResult] {
        do {
            return try decodedFiles().valid.map(\.run).sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
        } catch {
            throw RunHistoryError.fileSystem(error.localizedDescription)
        }
    }

    public func corruptFileNames() async throws -> [String] {
        do { return try decodedFiles().corrupt.map(\.lastPathComponent).sorted() }
        catch { throw RunHistoryError.fileSystem(error.localizedDescription) }
    }

    public func delete(id: String) async throws {
        do {
            let file = directoryURL.appendingPathComponent("\(id).json")
            if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
        } catch {
            throw RunHistoryError.fileSystem(error.localizedDescription)
        }
    }

    public func delete(ids: [String]) async throws {
        for id in Set(ids) { try await delete(id: id) }
    }

    public func clear() async throws {
        do {
            for entry in try decodedFiles().valid { try FileManager.default.removeItem(at: entry.url) }
        } catch {
            throw RunHistoryError.fileSystem(error.localizedDescription)
        }
    }

    public func prune(referenceDate: Date = Date()) async throws -> RunHistoryPruneResult {
        do { return try pruneFiles(referenceDate: referenceDate) }
        catch { throw RunHistoryError.fileSystem(error.localizedDescription) }
    }

    public func storageUsageBytes() async throws -> Int64 {
        guard FileManager.default.fileExists(atPath: directoryURL.path) else { return 0 }
        do {
            return try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.fileSizeKey])
                .filter { $0.pathExtension == "json" }
                .reduce(0) { total, url in total + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        } catch {
            throw RunHistoryError.fileSystem(error.localizedDescription)
        }
    }

    private func sanitized(_ run: SceneRunResult) -> SceneRunResult {
        var safe = run
        for index in safe.actionRecords.indices {
            var record = safe.actionRecords[index]
            if let message = record.errorMessage { record.errorMessage = Redactor.redact(message) }
            record.attempts = record.attempts.map { attempt in
                var copy = attempt
                if let message = copy.errorMessage { copy.errorMessage = Redactor.redact(message) }
                if let reason = copy.reason { copy.reason = Redactor.redact(reason) }
                return copy
            }
            record.healthChecks = record.healthChecks.map { check in
                var copy = check
                if let message = copy.message { copy.message = Redactor.redact(message) }
                return copy
            }

            let outputLimit = retention.retainOutputSummaries ? retention.maximumOutputBytesPerAction : 0
            if outputLimit == 0 {
                if let process = record.processResult {
                    record.processResult = .init(stdout: "", stderr: "", exitCode: process.exitCode, startedAt: process.startedAt, endedAt: process.endedAt, timedOut: process.timedOut, cancelled: process.cancelled)
                }
                record.outputSummary = nil
                record.outputTruncated = nil
            } else {
                if let process = record.processResult {
                    let originalBytes = Data(process.stdout.utf8).count + Data(process.stderr.utf8).count
                    let stdoutLimit = min(outputLimit, Data(process.stdout.utf8).count)
                    let stderrLimit = max(0, outputLimit - stdoutLimit)
                    record.processResult = .init(
                        stdout: boundedRedacted(process.stdout, maximumBytes: stdoutLimit),
                        stderr: boundedRedacted(process.stderr, maximumBytes: stderrLimit),
                        exitCode: process.exitCode,
                        startedAt: process.startedAt,
                        endedAt: process.endedAt,
                        timedOut: process.timedOut,
                        cancelled: process.cancelled
                    )
                    record.outputTruncated = originalBytes > outputLimit
                }
                if let summary = record.outputSummary {
                    record.outputSummary = boundedRedacted(summary, maximumBytes: outputLimit)
                    record.outputTruncated = record.outputTruncated == true || Data(summary.utf8).count > outputLimit
                }
            }
            safe.actionRecords[index] = record
        }
        if let message = safe.errorMessage { safe.errorMessage = Redactor.redact(message) }
        return safe
    }

    private func boundedRedacted(_ value: String, maximumBytes: Int) -> String {
        guard maximumBytes > 0 else { return "" }
        let data = Data(Redactor.redact(value).utf8)
        return String(decoding: data.prefix(maximumBytes), as: UTF8.self)
    }

    private typealias DecodedEntry = (url: URL, run: SceneRunResult)
    private func decodedFiles() throws -> (valid: [DecodedEntry], corrupt: [URL]) {
        guard FileManager.default.fileExists(atPath: directoryURL.path) else { return ([], []) }
        let files = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }
        var valid: [DecodedEntry] = []
        var corrupt: [URL] = []
        for file in files {
            do { valid.append((file, try decoder.decode(SceneRunResult.self, from: Data(contentsOf: file)))) }
            catch { corrupt.append(file) }
        }
        return (valid, corrupt)
    }

    private func pruneFiles(referenceDate: Date) throws -> RunHistoryPruneResult {
        let decoded = try decodedFiles()
        let active = decoded.valid.filter { $0.run.status.isActive }
        let terminal = decoded.valid.filter { !$0.run.status.isActive }.sorted { ($0.run.startedAt ?? .distantPast) > ($1.run.startedAt ?? .distantPast) }
        let cutoffDay = calendar.date(byAdding: .day, value: -max(1, retention.retentionDays), to: calendar.startOfDay(for: referenceDate)) ?? .distantPast
        var deleted: [String] = []
        for (index, entry) in terminal.enumerated() {
            let outsideCount = index >= max(1, retention.maximumRunCount)
            let outsideAge = (entry.run.startedAt ?? .distantPast) < cutoffDay
            if outsideCount || outsideAge {
                try FileManager.default.removeItem(at: entry.url)
                deleted.append(entry.run.id)
            }
        }
        return .init(
            deletedRunIDs: deleted.sorted(),
            preservedActiveRunIDs: active.map(\.run.id).sorted(),
            corruptFileNames: decoded.corrupt.map(\.lastPathComponent).sorted()
        )
    }
}
