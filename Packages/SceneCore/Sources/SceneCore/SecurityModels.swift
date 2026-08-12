import Foundation

public struct SecretReference: Codable, Equatable, Identifiable, Sendable {
    public var id: String; public var label: String
    public init(id: String = UUID().uuidString, label: String) { self.id = id; self.label = label }
}

public struct ProcessApproval: Codable, Equatable, Identifiable, Sendable {
    public var id: String { fingerprint }
    public var fingerprint: String; public var actionID: String; public var approvedAt: Date
    public init(fingerprint: String, actionID: String, approvedAt: Date = Date()) { self.fingerprint = fingerprint; self.actionID = actionID; self.approvedAt = approvedAt }
}

public enum ProcessApprovalScope: String, Codable, Sendable {
    case once
    case exactAction
}

public struct ProcessApprovalDetails: Equatable, Sendable {
    public let actionID: String
    public let kind: String
    public let executable: String
    public let arguments: [String]
    public let workingDirectory: String?
    public let environmentNames: [String]
    public let environmentDescriptions: [String]
    public let timeout: Double?
    public let retryPolicy: RetryPolicy
    public let managed: Bool
    public let stopBehavior: String?
    let environmentFingerprintComponents: [String]

    public init(actionID: String, kind: String, executable: String, arguments: [String], workingDirectory: String?, environmentNames: [String], environmentDescriptions: [String] = [], timeout: Double?, retryPolicy: RetryPolicy, managed: Bool, stopBehavior: String?, environmentFingerprintComponents: [String] = []) {
        self.actionID = actionID; self.kind = kind; self.executable = executable; self.arguments = arguments; self.workingDirectory = workingDirectory; self.environmentNames = environmentNames; self.environmentDescriptions = environmentDescriptions; self.timeout = timeout; self.retryPolicy = retryPolicy; self.managed = managed; self.stopBehavior = stopBehavior; self.environmentFingerprintComponents = environmentFingerprintComponents
    }
}

public protocol ProcessApprovalAuthorizing: Sendable {
    func isApproved(_ action: SceneAction) async throws -> Bool
    func approve(_ action: SceneAction, scope: ProcessApprovalScope) async throws
    func consumeApproval(for action: SceneAction) async throws -> Bool
    func revoke(actionID: String) async throws
    func clearAll() async throws
}

public extension ProcessApprovalAuthorizing { func clearAll() async throws {} }

public struct RejectingProcessApprovalAuthorizer: ProcessApprovalAuthorizing {
    public init() {}
    public func isApproved(_ action: SceneAction) async throws -> Bool { !action.requiresProcessApproval }
    public func approve(_ action: SceneAction, scope: ProcessApprovalScope) async throws {}
    public func consumeApproval(for action: SceneAction) async throws -> Bool { !action.requiresProcessApproval }
    public func revoke(actionID: String) async throws {}
}

public actor JSONProcessApprovalStore: ProcessApprovalAuthorizing {
    public let fileURL: URL
    private var onceFingerprints = Set<String>()
    private var loadedApprovals: [ProcessApproval]?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileURL: URL) {
        self.fileURL = fileURL
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
    }

    public static func applicationSupportStore() throws -> JSONProcessApprovalStore {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw ApprovalStoreError.fileSystem("Application Support is unavailable.")
        }
        return .init(fileURL: base.appendingPathComponent("WorkspaceOrchestrator/process-approvals.json"))
    }

    public func isApproved(_ action: SceneAction) async throws -> Bool {
        guard action.requiresProcessApproval else { return true }
        let fingerprint = try ApprovalFingerprint.make(for: action)
        if onceFingerprints.contains(fingerprint) { return true }
        return try load().contains { $0.actionID == action.id && $0.fingerprint == fingerprint }
    }

    public func approve(_ action: SceneAction, scope: ProcessApprovalScope) async throws {
        guard action.requiresProcessApproval else { return }
        let fingerprint = try ApprovalFingerprint.make(for: action)
        switch scope {
        case .once:
            onceFingerprints.insert(fingerprint)
        case .exactAction:
            var approvals = try load().filter { $0.actionID != action.id }
            approvals.append(.init(fingerprint: fingerprint, actionID: action.id))
            try write(approvals)
        }
    }

    public func consumeApproval(for action: SceneAction) async throws -> Bool {
        guard action.requiresProcessApproval else { return true }
        let fingerprint = try ApprovalFingerprint.make(for: action)
        if onceFingerprints.remove(fingerprint) != nil { return true }
        return try load().contains { $0.actionID == action.id && $0.fingerprint == fingerprint }
    }

    public func revoke(actionID: String) async throws {
        try write(try load().filter { $0.actionID != actionID })
    }

    public func clearAll() async throws {
        onceFingerprints.removeAll()
        try write([])
    }

    private func load() throws -> [ProcessApproval] {
        if let loadedApprovals { return loadedApprovals }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { loadedApprovals = []; return [] }
        do {
            let values = try decoder.decode([ProcessApproval].self, from: Data(contentsOf: fileURL))
            loadedApprovals = values
            return values
        } catch {
            throw ApprovalStoreError.corrupt(error.localizedDescription)
        }
    }

    private func write(_ approvals: [ProcessApproval]) throws {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoder.encode(approvals).write(to: fileURL, options: .atomic)
            loadedApprovals = approvals
        } catch let error as ApprovalStoreError {
            throw error
        } catch {
            throw ApprovalStoreError.fileSystem(error.localizedDescription)
        }
    }
}

public enum ApprovalStoreError: LocalizedError {
    case corrupt(String)
    case fileSystem(String)

    public var errorDescription: String? {
        switch self {
        case .corrupt(let message): "Stored process approvals are corrupt and were not used: \(message)"
        case .fileSystem(let message): "Process approval storage failed: \(message)"
        }
    }
}

public extension SceneAction {
    var requiresProcessApproval: Bool {
        switch self {
        case .runProcess, .managedProcess, .editorWorkspace, .terminalWorkspace, .dockerCompose, .shortcut: true
        default: false
        }
    }

    var processApprovalDetails: ProcessApprovalDetails? {
        let retry = configuration.retryPolicy
        switch self {
        case .runProcess(let value):
            let environment = approvalEnvironment(value.environment)
            return .init(actionID: id, kind: "One-shot process", executable: value.executable, arguments: value.arguments, workingDirectory: value.workingDirectory, environmentNames: environment.names, environmentDescriptions: environment.descriptions, timeout: value.timeoutSeconds ?? configuration.timeoutSeconds, retryPolicy: retry, managed: false, stopBehavior: nil, environmentFingerprintComponents: environment.fingerprintComponents)
        case .managedProcess(let value):
            let environment = approvalEnvironment(value.environment)
            return .init(actionID: id, kind: "Managed process", executable: value.executable, arguments: value.arguments, workingDirectory: value.workingDirectory, environmentNames: environment.names, environmentDescriptions: environment.descriptions, timeout: configuration.timeoutSeconds, retryPolicy: retry, managed: true, stopBehavior: "Graceful stop after \(value.gracefulStopSeconds) seconds", environmentFingerprintComponents: environment.fingerprintComponents)
        case .editorWorkspace(let value):
            var arguments = [value.editor.rawValue, value.projectPath, value.profile ?? "", String(value.newWindow)]
            arguments += value.files.map { "\($0.file):\($0.line.map(String.init) ?? ""):\($0.column.map(String.init) ?? "")" }
            return .init(actionID: id, kind: "Editor workspace", executable: "/usr/bin/open", arguments: arguments, workingDirectory: nil, environmentNames: [], timeout: configuration.timeoutSeconds, retryPolicy: retry, managed: false, stopBehavior: nil)
        case .terminalWorkspace(let value):
            return .init(actionID: id, kind: "Terminal workspace", executable: value.tmuxSessionName == nil ? "/usr/bin/open" : "detected tmux executable", arguments: [value.terminal.rawValue, value.workingDirectory, value.tmuxSessionName ?? ""], workingDirectory: value.workingDirectory, environmentNames: [], timeout: configuration.timeoutSeconds, retryPolicy: retry, managed: value.tmuxSessionName != nil, stopBehavior: value.stopTmuxOnDeactivate ? "Stop owned tmux session on deactivation" : "Leave tmux session running")
        case .dockerCompose(let value):
            return .init(actionID: id, kind: "Docker Compose", executable: "detected Docker CLI", arguments: [value.projectDirectory, value.composeFile ?? "", value.services.joined(separator: ","), value.profiles.joined(separator: ","), String(value.build), value.pullPolicy.rawValue, value.stopPolicy.rawValue, String(value.removeVolumes)], workingDirectory: value.projectDirectory, environmentNames: [], timeout: configuration.timeoutSeconds, retryPolicy: retry, managed: true, stopBehavior: "\(value.stopPolicy.rawValue), remove volumes: \(value.removeVolumes)")
        case .shortcut(let value):
            return .init(actionID: id, kind: "macOS Shortcut", executable: "/usr/bin/shortcuts", arguments: ["run", value.name, value.inputFile ?? ""], workingDirectory: nil, environmentNames: [], timeout: configuration.timeoutSeconds, retryPolicy: retry, managed: false, stopBehavior: nil)
        default:
            return nil
        }
    }
}

public enum ApprovalFingerprint {
    public static func make(for action: SceneAction) throws -> String {
        guard let details = action.processApprovalDetails else {
            throw FingerprintError.notExecutable
        }
        let safe = ApprovalInput(kind: details.kind, executable: details.executable, arguments: details.arguments, workingDirectory: details.workingDirectory, environmentConfiguration: details.environmentFingerprintComponents, timeout: details.timeout, retry: details.retryPolicy, managed: details.managed, stopBehavior: details.stopBehavior)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return SHA256.hexDigest(try encoder.encode(safe))
    }

    private struct ApprovalInput: Codable {
        let kind: String; let executable: String; let arguments: [String]; let workingDirectory: String?
        let environmentConfiguration: [String]; let timeout: Double?; let retry: RetryPolicy; let managed: Bool; let stopBehavior: String?
    }
    public enum FingerprintError: LocalizedError { case notExecutable; public var errorDescription: String? { "This action does not execute a binary and does not require a process fingerprint." } }
}

private func approvalEnvironment(_ values: [String: EnvironmentValue]) -> (names: [String], descriptions: [String], fingerprintComponents: [String]) {
    let names = values.keys.sorted()
    var descriptions: [String] = []
    var components: [String] = []
    for name in names {
        guard let value = values[name] else { continue }
        switch value {
        case .plain(let plain): descriptions.append("\(name) (plain value)"); components.append("\(name)\u{0}plain\u{0}\(plain)")
        case .secretReference(let reference): descriptions.append("\(name) (Keychain reference)"); components.append("\(name)\u{0}secretReference\u{0}\(reference)")
        case .inherited: descriptions.append("\(name) (inherited)"); components.append("\(name)\u{0}inherited")
        }
    }
    return (names, descriptions, components)
}

public struct RedactionConfiguration: Codable, Equatable, Sendable {
    public var customPatterns: [String]; public var maximumBytes: Int
    public init(customPatterns: [String] = [], maximumBytes: Int = 32_768) { self.customPatterns = customPatterns; self.maximumBytes = maximumBytes }
}

public enum Redactor {
    private static let patterns = [
        #"(?i)(authorization:\s*(?:bearer|basic)\s+)[^\s]+"#,
        #"(?i)((?:password|passwd|token|secret|api[_-]?key)\s*[=:]\s*)[^\s,;]+"#,
        #"\b(?:sk|pk)_(?:live|test)_[A-Za-z0-9]{12,}\b"#,
        #"\bgh[opsu]_[A-Za-z0-9]{20,}\b"#
    ]

    public static func redact(_ value: String, secrets: [String] = [], configuration: RedactionConfiguration = .init()) -> String {
        var result = value
        for secret in secrets where !secret.isEmpty { result = result.replacingOccurrences(of: secret, with: "[REDACTED]") }
        for pattern in patterns + configuration.customPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "$1[REDACTED]")
        }
        let data = Data(result.utf8)
        guard data.count > configuration.maximumBytes else { return result }
        let prefix = data.prefix(max(0, configuration.maximumBytes))
        return String(decoding: prefix, as: UTF8.self) + "\n[OUTPUT TRUNCATED]"
    }
}

private enum SHA256 {
    private static let constants: [UInt32] = [
        0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
        0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
        0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
        0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
        0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
        0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
        0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
        0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
    ]
    static func hexDigest(_ data: Data) -> String { digest(data).map { String(format: "%02x", $0) }.joined() }
    private static func digest(_ input: Data) -> [UInt8] {
        var message = [UInt8](input); let bitLength = UInt64(message.count) * 8; message.append(0x80)
        while message.count % 64 != 56 { message.append(0) }
        message.append(contentsOf: withUnsafeBytes(of: bitLength.bigEndian, Array.init))
        var h: [UInt32] = [0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19]
        for offset in stride(from: 0, to: message.count, by: 64) {
            var w = [UInt32](repeating: 0, count: 64)
            for i in 0..<16 { let j = offset + i * 4; w[i] = UInt32(message[j]) << 24 | UInt32(message[j+1]) << 16 | UInt32(message[j+2]) << 8 | UInt32(message[j+3]) }
            for i in 16..<64 { let s0 = rotate(w[i-15], 7) ^ rotate(w[i-15], 18) ^ (w[i-15] >> 3); let s1 = rotate(w[i-2], 17) ^ rotate(w[i-2], 19) ^ (w[i-2] >> 10); w[i] = w[i-16] &+ s0 &+ w[i-7] &+ s1 }
            var a=h[0],b=h[1],c=h[2],d=h[3],e=h[4],f=h[5],g=h[6],hh=h[7]
            for i in 0..<64 { let s1 = rotate(e,6)^rotate(e,11)^rotate(e,25); let ch=(e&f)^((~e)&g); let t1=hh&+s1&+ch&+constants[i]&+w[i]; let s0=rotate(a,2)^rotate(a,13)^rotate(a,22); let maj=(a&b)^(a&c)^(b&c); let t2=s0&+maj; hh=g;g=f;f=e;e=d&+t1;d=c;c=b;b=a;a=t1&+t2 }
            h[0]&+=a;h[1]&+=b;h[2]&+=c;h[3]&+=d;h[4]&+=e;h[5]&+=f;h[6]&+=g;h[7]&+=hh
        }
        return h.flatMap { withUnsafeBytes(of: $0.bigEndian, Array.init) }
    }
    private static func rotate(_ x: UInt32, _ n: UInt32) -> UInt32 { (x >> n) | (x << (32 - n)) }
}
