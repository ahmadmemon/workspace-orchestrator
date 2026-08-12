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

public enum ApprovalFingerprint {
    public static func make(for action: SceneAction) throws -> String {
        let safe: ApprovalInput
        switch action {
        case .runProcess(let value):
            safe = .init(kind: "process", executable: value.executable, arguments: value.arguments, workingDirectory: value.workingDirectory, environmentNames: value.environment.keys.sorted(), timeout: value.timeoutSeconds ?? value.configuration.timeoutSeconds, retry: value.configuration.retryPolicy, managed: false, stopBehavior: nil)
        case .managedProcess(let value):
            safe = .init(kind: "managedProcess", executable: value.executable, arguments: value.arguments, workingDirectory: value.workingDirectory, environmentNames: value.environment.keys.sorted(), timeout: value.configuration.timeoutSeconds, retry: value.configuration.retryPolicy, managed: true, stopBehavior: String(value.gracefulStopSeconds))
        case .dockerCompose(let value):
            safe = .init(kind: "dockerCompose", executable: "/usr/local/bin/docker", arguments: [value.projectDirectory, value.composeFile ?? "", value.services.joined(separator: ","), value.profiles.joined(separator: ","), String(value.build), value.pullPolicy.rawValue], workingDirectory: value.projectDirectory, environmentNames: [], timeout: value.configuration.timeoutSeconds, retry: value.configuration.retryPolicy, managed: true, stopBehavior: "\(value.stopPolicy.rawValue):removeVolumes=\(value.removeVolumes)")
        case .shortcut(let value):
            safe = .init(kind: "shortcut", executable: "/usr/bin/shortcuts", arguments: [value.name, value.inputFile ?? ""], workingDirectory: nil, environmentNames: [], timeout: value.configuration.timeoutSeconds, retry: value.configuration.retryPolicy, managed: false, stopBehavior: nil)
        default:
            throw FingerprintError.notExecutable
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return SHA256.hexDigest(try encoder.encode(safe))
    }

    private struct ApprovalInput: Codable {
        let kind: String; let executable: String; let arguments: [String]; let workingDirectory: String?
        let environmentNames: [String]; let timeout: Double?; let retry: RetryPolicy; let managed: Bool; let stopBehavior: String?
    }
    public enum FingerprintError: LocalizedError { case notExecutable; public var errorDescription: String? { "This action does not execute a binary and does not require a process fingerprint." } }
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
