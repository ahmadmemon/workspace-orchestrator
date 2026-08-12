import Foundation

public enum FailurePolicy: String, Codable, CaseIterable, Sendable {
    case stopScene
    case continueDegraded
    case continueOptional
    case skipDependents
}

public enum RetryStrategy: String, Codable, CaseIterable, Sendable {
    case none
    case fixed
    case exponential
}

public enum RetryableErrorCategory: String, Codable, CaseIterable, Sendable {
    case missingIntegration
    case processLaunch
    case processExit
    case timeout
    case healthCheck
    case network
}

public struct RetryPolicy: Codable, Equatable, Sendable {
    public var strategy: RetryStrategy
    public var maximumAttempts: Int
    public var initialDelaySeconds: Double
    public var maximumDelaySeconds: Double
    public var maximumTotalDurationSeconds: Double
    public var jitterFraction: Double
    public var retryableCategories: Set<RetryableErrorCategory>

    public init(
        strategy: RetryStrategy = .none,
        maximumAttempts: Int = 1,
        initialDelaySeconds: Double = 1,
        maximumDelaySeconds: Double = 30,
        maximumTotalDurationSeconds: Double = 120,
        jitterFraction: Double = 0,
        retryableCategories: Set<RetryableErrorCategory> = Set(RetryableErrorCategory.allCases)
    ) {
        self.strategy = strategy
        self.maximumAttempts = maximumAttempts
        self.initialDelaySeconds = initialDelaySeconds
        self.maximumDelaySeconds = maximumDelaySeconds
        self.maximumTotalDurationSeconds = maximumTotalDurationSeconds
        self.jitterFraction = jitterFraction
        self.retryableCategories = retryableCategories
    }

    public func delay(beforeAttempt attempt: Int, deterministicUnit: Double = 0.5) -> TimeInterval {
        guard strategy != .none, attempt > 1 else { return 0 }
        let base: Double
        switch strategy {
        case .none: base = 0
        case .fixed: base = initialDelaySeconds
        case .exponential:
            base = min(maximumDelaySeconds, initialDelaySeconds * pow(2, Double(attempt - 2)))
        }
        let clampedUnit = min(max(deterministicUnit, 0), 1)
        let jitter = base * jitterFraction * ((clampedUnit * 2) - 1)
        return max(0, min(maximumDelaySeconds, base + jitter))
    }
}

public enum IdempotencyPolicy: String, Codable, CaseIterable, Sendable {
    case alwaysRun
    case oncePerRun
    case reuseExisting
    case singleInstance
    case reapply
}

public enum OutputRetentionPolicy: String, Codable, CaseIterable, Sendable {
    case none
    case summary
    case bounded
}

public enum TrustState: String, Codable, CaseIterable, Sendable {
    case local
    case importedUntrusted
    case reviewed
}

public enum ActionCondition: Codable, Equatable, Sendable {
    case pathExists(String)
    case environmentEquals(name: String, value: String)

    private enum CodingKeys: String, CodingKey { case type, path, name, value }
    private enum Kind: String, Codable { case pathExists, environmentEquals }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .pathExists:
            self = .pathExists(try container.decode(String.self, forKey: .path))
        case .environmentEquals:
            self = .environmentEquals(
                name: try container.decode(String.self, forKey: .name),
                value: try container.decode(String.self, forKey: .value)
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .pathExists(let path):
            try container.encode(Kind.pathExists, forKey: .type)
            try container.encode(path, forKey: .path)
        case .environmentEquals(let name, let value):
            try container.encode(Kind.environmentEquals, forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encode(value, forKey: .value)
        }
    }
}

public enum ConditionEvaluationMode: String, Codable, CaseIterable, Sendable {
    case all
    case any
}

public enum HTTPMethod: String, Codable, CaseIterable, Sendable { case head = "HEAD"; case get = "GET" }

public enum HealthCheck: Codable, Equatable, Identifiable, Sendable {
    case http(HTTPHealthCheck)
    case tcp(TCPHealthCheck)
    case process(ProcessHealthCheck)
    case application(ApplicationHealthCheck)
    case file(FileHealthCheck)
    case docker(DockerHealthCheck)

    public var id: String {
        switch self {
        case .http(let value): value.id
        case .tcp(let value): value.id
        case .process(let value): value.id
        case .application(let value): value.id
        case .file(let value): value.id
        case .docker(let value): value.id
        }
    }

    private enum CodingKeys: String, CodingKey { case type, payload }
    private enum Kind: String, Codable { case http, tcp, process, application, file, docker }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .http: self = .http(try container.decode(HTTPHealthCheck.self, forKey: .payload))
        case .tcp: self = .tcp(try container.decode(TCPHealthCheck.self, forKey: .payload))
        case .process: self = .process(try container.decode(ProcessHealthCheck.self, forKey: .payload))
        case .application: self = .application(try container.decode(ApplicationHealthCheck.self, forKey: .payload))
        case .file: self = .file(try container.decode(FileHealthCheck.self, forKey: .payload))
        case .docker: self = .docker(try container.decode(DockerHealthCheck.self, forKey: .payload))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .http(let value): try container.encode(Kind.http, forKey: .type); try container.encode(value, forKey: .payload)
        case .tcp(let value): try container.encode(Kind.tcp, forKey: .type); try container.encode(value, forKey: .payload)
        case .process(let value): try container.encode(Kind.process, forKey: .type); try container.encode(value, forKey: .payload)
        case .application(let value): try container.encode(Kind.application, forKey: .type); try container.encode(value, forKey: .payload)
        case .file(let value): try container.encode(Kind.file, forKey: .type); try container.encode(value, forKey: .payload)
        case .docker(let value): try container.encode(Kind.docker, forKey: .type); try container.encode(value, forKey: .payload)
        }
    }
}

public struct HTTPHealthCheck: Codable, Equatable, Sendable {
    public var id: String; public var url: String; public var method: HTTPMethod
    public var expectedStatus: ClosedRange<Int>; public var responseContains: String?
    public var timeoutSeconds: Double; public var intervalSeconds: Double; public var maximumAttempts: Int
    public var required: Bool?
    public init(id: String = UUID().uuidString, url: String, method: HTTPMethod = .get, expectedStatus: ClosedRange<Int> = 200...299, responseContains: String? = nil, timeoutSeconds: Double = 5, intervalSeconds: Double = 1, maximumAttempts: Int = 10, required: Bool = true) {
        self.id = id; self.url = url; self.method = method; self.expectedStatus = expectedStatus; self.responseContains = responseContains; self.timeoutSeconds = timeoutSeconds; self.intervalSeconds = intervalSeconds; self.maximumAttempts = maximumAttempts; self.required = required
    }
}

public struct TCPHealthCheck: Codable, Equatable, Sendable {
    public var id: String; public var host: String; public var port: Int
    public var timeoutSeconds: Double; public var intervalSeconds: Double; public var maximumAttempts: Int
    public var required: Bool?
    public init(id: String = UUID().uuidString, host: String = "127.0.0.1", port: Int, timeoutSeconds: Double = 3, intervalSeconds: Double = 1, maximumAttempts: Int = 10, required: Bool = true) {
        self.id = id; self.host = host; self.port = port; self.timeoutSeconds = timeoutSeconds; self.intervalSeconds = intervalSeconds; self.maximumAttempts = maximumAttempts; self.required = required
    }
}

public struct ProcessHealthCheck: Codable, Equatable, Sendable {
    public var id: String; public var actionID: String; public var timeoutSeconds: Double?; public var intervalSeconds: Double?; public var maximumAttempts: Int?; public var required: Bool?
    public init(id: String = UUID().uuidString, actionID: String, timeoutSeconds: Double = 3, intervalSeconds: Double = 1, maximumAttempts: Int = 1, required: Bool = true) { self.id = id; self.actionID = actionID; self.timeoutSeconds = timeoutSeconds; self.intervalSeconds = intervalSeconds; self.maximumAttempts = maximumAttempts; self.required = required }
}
public struct ApplicationHealthCheck: Codable, Equatable, Sendable {
    public var id: String; public var bundleIdentifier: String; public var timeoutSeconds: Double?; public var intervalSeconds: Double?; public var maximumAttempts: Int?; public var required: Bool?
    public init(id: String = UUID().uuidString, bundleIdentifier: String, timeoutSeconds: Double = 3, intervalSeconds: Double = 1, maximumAttempts: Int = 1, required: Bool = true) { self.id = id; self.bundleIdentifier = bundleIdentifier; self.timeoutSeconds = timeoutSeconds; self.intervalSeconds = intervalSeconds; self.maximumAttempts = maximumAttempts; self.required = required }
}
public struct FileHealthCheck: Codable, Equatable, Sendable {
    public var id: String; public var path: String; public var mustBeDirectory: Bool?; public var modifiedWithinSeconds: Double?; public var timeoutSeconds: Double?; public var intervalSeconds: Double?; public var maximumAttempts: Int?; public var required: Bool?
    public init(id: String = UUID().uuidString, path: String, mustBeDirectory: Bool? = nil, modifiedWithinSeconds: Double? = nil, timeoutSeconds: Double = 3, intervalSeconds: Double = 1, maximumAttempts: Int = 1, required: Bool = true) { self.id = id; self.path = path; self.mustBeDirectory = mustBeDirectory; self.modifiedWithinSeconds = modifiedWithinSeconds; self.timeoutSeconds = timeoutSeconds; self.intervalSeconds = intervalSeconds; self.maximumAttempts = maximumAttempts; self.required = required }
}
public struct DockerHealthCheck: Codable, Equatable, Sendable {
    public var id: String; public var composeActionID: String; public var service: String; public var requireHealthy: Bool; public var timeoutSeconds: Double?; public var intervalSeconds: Double?; public var maximumAttempts: Int?; public var required: Bool?
    public init(id: String = UUID().uuidString, composeActionID: String, service: String, requireHealthy: Bool = true, timeoutSeconds: Double = 5, intervalSeconds: Double = 2, maximumAttempts: Int = 15, required: Bool = true) { self.id = id; self.composeActionID = composeActionID; self.service = service; self.requireHealthy = requireHealthy; self.timeoutSeconds = timeoutSeconds; self.intervalSeconds = intervalSeconds; self.maximumAttempts = maximumAttempts; self.required = required }
}

public extension HealthCheck {
    var isRequired: Bool {
        switch self { case .http(let value): value.required ?? true; case .tcp(let value): value.required ?? true; case .process(let value): value.required ?? true; case .application(let value): value.required ?? true; case .file(let value): value.required ?? true; case .docker(let value): value.required ?? true }
    }
}

public struct ActionConfiguration: Codable, Equatable, Sendable {
    public var name: String?
    public var enabled: Bool
    public var dependencies: [String]
    public var timeoutSeconds: Double?
    public var retryPolicy: RetryPolicy
    public var failurePolicy: FailurePolicy
    public var idempotencyPolicy: IdempotencyPolicy
    public var conditions: [ActionCondition]
    public var conditionEvaluationMode: ConditionEvaluationMode
    public var disabledConditionIndexes: Set<Int>
    public var healthChecks: [HealthCheck]
    public var outputRetention: OutputRetentionPolicy

    public init(name: String? = nil, enabled: Bool = true, dependencies: [String] = [], timeoutSeconds: Double? = nil, retryPolicy: RetryPolicy = .init(), failurePolicy: FailurePolicy = .stopScene, idempotencyPolicy: IdempotencyPolicy = .alwaysRun, conditions: [ActionCondition] = [], conditionEvaluationMode: ConditionEvaluationMode = .all, disabledConditionIndexes: Set<Int> = [], healthChecks: [HealthCheck] = [], outputRetention: OutputRetentionPolicy = .summary) {
        self.name = name; self.enabled = enabled; self.dependencies = dependencies; self.timeoutSeconds = timeoutSeconds; self.retryPolicy = retryPolicy; self.failurePolicy = failurePolicy; self.idempotencyPolicy = idempotencyPolicy; self.conditions = conditions; self.conditionEvaluationMode = conditionEvaluationMode; self.disabledConditionIndexes = disabledConditionIndexes; self.healthChecks = healthChecks; self.outputRetention = outputRetention
    }

    private enum CodingKeys: String, CodingKey { case name, enabled, dependencies, timeoutSeconds, retryPolicy, failurePolicy, idempotencyPolicy, conditions, conditionEvaluationMode, disabledConditionIndexes, healthChecks, outputRetention }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        dependencies = try container.decodeIfPresent([String].self, forKey: .dependencies) ?? []
        timeoutSeconds = try container.decodeIfPresent(Double.self, forKey: .timeoutSeconds)
        retryPolicy = try container.decodeIfPresent(RetryPolicy.self, forKey: .retryPolicy) ?? .init()
        failurePolicy = try container.decodeIfPresent(FailurePolicy.self, forKey: .failurePolicy) ?? .stopScene
        idempotencyPolicy = try container.decodeIfPresent(IdempotencyPolicy.self, forKey: .idempotencyPolicy) ?? .alwaysRun
        conditions = try container.decodeIfPresent([ActionCondition].self, forKey: .conditions) ?? []
        conditionEvaluationMode = try container.decodeIfPresent(ConditionEvaluationMode.self, forKey: .conditionEvaluationMode) ?? .all
        disabledConditionIndexes = try container.decodeIfPresent(Set<Int>.self, forKey: .disabledConditionIndexes) ?? []
        healthChecks = try container.decodeIfPresent([HealthCheck].self, forKey: .healthChecks) ?? []
        outputRetention = try container.decodeIfPresent(OutputRetentionPolicy.self, forKey: .outputRetention) ?? .summary
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name); try container.encode(enabled, forKey: .enabled); try container.encode(dependencies, forKey: .dependencies); try container.encodeIfPresent(timeoutSeconds, forKey: .timeoutSeconds); try container.encode(retryPolicy, forKey: .retryPolicy); try container.encode(failurePolicy, forKey: .failurePolicy); try container.encode(idempotencyPolicy, forKey: .idempotencyPolicy); try container.encode(conditions, forKey: .conditions); try container.encode(conditionEvaluationMode, forKey: .conditionEvaluationMode); try container.encode(disabledConditionIndexes, forKey: .disabledConditionIndexes); try container.encode(healthChecks, forKey: .healthChecks); try container.encode(outputRetention, forKey: .outputRetention)
    }
}

public enum EnvironmentValue: Codable, Equatable, Sendable {
    case plain(String)
    case secretReference(String)
    case inherited

    private enum CodingKeys: String, CodingKey { case type, value }
    private enum Kind: String, Codable { case plain, secretReference, inherited }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .plain: self = .plain(try container.decode(String.self, forKey: .value))
        case .secretReference: self = .secretReference(try container.decode(String.self, forKey: .value))
        case .inherited: self = .inherited
        }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .plain(let value): try container.encode(Kind.plain, forKey: .type); try container.encode(value, forKey: .value)
        case .secretReference(let value): try container.encode(Kind.secretReference, forKey: .type); try container.encode(value, forKey: .value)
        case .inherited: try container.encode(Kind.inherited, forKey: .type)
        }
    }
}
