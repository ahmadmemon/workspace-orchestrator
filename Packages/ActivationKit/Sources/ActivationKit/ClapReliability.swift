import Foundation

public enum ClapCalibrationWarning: String, Codable, Equatable, Sendable {
    case tooFewSamples
    case highAmbientNoise
    case unstableNoise
    case representativeClapMissing
    case representativeClapTooQuiet
    case representativeClapClipped
    case representativeSignalUnclear
    case representativeIntervalOutOfRange
}

public struct ClapCalibrationResult: Codable, Equatable, Sendable {
    public var sampleCount: Int
    public var ambientNoiseFloor: Double
    public var highNoisePercentile: Double
    public var recommendedSensitivity: Double
    public var recommendedMinimumInterval: Double
    public var recommendedMaximumInterval: Double
    public var representativePeakEnergy: Double?
    public var representativeInterval: Double?
    public var confidence: Double
    public var warnings: [ClapCalibrationWarning]
    public var isUsable: Bool { warnings.isEmpty }

    public init(sampleCount: Int, ambientNoiseFloor: Double, highNoisePercentile: Double, recommendedSensitivity: Double, recommendedMinimumInterval: Double = 0.12, recommendedMaximumInterval: Double = 0.65, representativePeakEnergy: Double? = nil, representativeInterval: Double? = nil, confidence: Double, warnings: [ClapCalibrationWarning]) {
        self.sampleCount = sampleCount; self.ambientNoiseFloor = ambientNoiseFloor; self.highNoisePercentile = highNoisePercentile; self.recommendedSensitivity = recommendedSensitivity; self.recommendedMinimumInterval = recommendedMinimumInterval; self.recommendedMaximumInterval = recommendedMaximumInterval; self.representativePeakEnergy = representativePeakEnergy; self.representativeInterval = representativeInterval; self.confidence = confidence; self.warnings = warnings
    }

    private enum CodingKeys: String, CodingKey { case sampleCount, ambientNoiseFloor, highNoisePercentile, recommendedSensitivity, recommendedMinimumInterval, recommendedMaximumInterval, representativePeakEnergy, representativeInterval, confidence, warnings }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(sampleCount: try container.decode(Int.self, forKey: .sampleCount), ambientNoiseFloor: try container.decode(Double.self, forKey: .ambientNoiseFloor), highNoisePercentile: try container.decode(Double.self, forKey: .highNoisePercentile), recommendedSensitivity: try container.decode(Double.self, forKey: .recommendedSensitivity), recommendedMinimumInterval: try container.decodeIfPresent(Double.self, forKey: .recommendedMinimumInterval) ?? 0.12, recommendedMaximumInterval: try container.decodeIfPresent(Double.self, forKey: .recommendedMaximumInterval) ?? 0.65, representativePeakEnergy: try container.decodeIfPresent(Double.self, forKey: .representativePeakEnergy), representativeInterval: try container.decodeIfPresent(Double.self, forKey: .representativeInterval), confidence: try container.decode(Double.self, forKey: .confidence), warnings: try container.decode([ClapCalibrationWarning].self, forKey: .warnings))
    }

    public func configurationAfterConfirmation(base: ClapConfiguration, sensitivity: Double, minimumInterval: Double, maximumInterval: Double) -> ClapConfiguration? {
        guard isUsable else { return nil }
        var accepted = base
        accepted.sensitivity = min(max(sensitivity, 0.1), 1)
        accepted.minimumInterval = min(max(minimumInterval, 0.08), 1.1)
        accepted.maximumInterval = min(max(maximumInterval, accepted.minimumInterval + 0.08), 1.2)
        return accepted
    }
}

public struct ClapCalibrationSession: Sendable {
    public var duration: TimeInterval
    public var minimumSamples: Int
    private var startedAt: TimeInterval?
    private var energies: [Double] = []

    public init(duration: TimeInterval = 5, minimumSamples: Int = 40) {
        self.duration = max(1, duration)
        self.minimumSamples = max(10, minimumSamples)
    }

    public mutating func consume(_ frame: AudioFeatureFrame) -> ClapCalibrationResult? {
        if startedAt == nil { startedAt = frame.timestamp }
        energies.append(max(0, frame.rmsEnergy))
        guard let startedAt, frame.timestamp - startedAt >= duration else { return nil }
        return result()
    }

    public func result() -> ClapCalibrationResult {
        let sorted = energies.sorted()
        let median = percentile(sorted, fraction: 0.5)
        let high = percentile(sorted, fraction: 0.9)
        let spread = max(0, high - median)
        var warnings: [ClapCalibrationWarning] = []
        if energies.count < minimumSamples { warnings.append(.tooFewSamples) }
        if high > 0.16 { warnings.append(.highAmbientNoise) }
        if median > 0, spread / median > 4.5 { warnings.append(.unstableNoise) }
        let sampleConfidence = min(1, Double(energies.count) / Double(minimumSamples))
        let noiseConfidence = max(0, 1 - high / 0.2)
        let stabilityConfidence = median == 0 ? 1 : max(0, 1 - spread / max(0.001, median * 5))
        let recommended = min(0.9, max(0.2, 0.82 - high * 3.2))
        return .init(sampleCount: energies.count, ambientNoiseFloor: median, highNoisePercentile: high, recommendedSensitivity: recommended, confidence: sampleConfidence * noiseConfidence * stabilityConfidence, warnings: warnings)
    }

    private func percentile(_ values: [Double], fraction: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let index = min(values.count - 1, max(0, Int((Double(values.count - 1) * fraction).rounded())))
        return values[index]
    }
}

public enum ClapCalibrationPhase: String, Equatable, Sendable { case ambientNoise; case representativeDoubleClap }

public struct ClapCalibrationWorkflow: Sendable {
    public private(set) var phase: ClapCalibrationPhase = .ambientNoise
    private var ambient: ClapCalibrationSession
    private let representativeDuration: TimeInterval
    private var ambientResult: ClapCalibrationResult?
    private var representativeStartedAt: TimeInterval?
    private var firstClap: AudioFeatureFrame?

    public init(ambientDuration: TimeInterval = 5, representativeDuration: TimeInterval = 5, minimumAmbientSamples: Int = 40) {
        ambient = .init(duration: ambientDuration, minimumSamples: minimumAmbientSamples)
        self.representativeDuration = max(1, representativeDuration)
    }

    public mutating func consume(_ frame: AudioFeatureFrame) -> ClapCalibrationResult? {
        switch phase {
        case .ambientNoise:
            guard let result = ambient.consume(frame) else { return nil }
            ambientResult = result
            guard result.warnings.isEmpty else { return result }
            phase = .representativeDoubleClap
            representativeStartedAt = frame.timestamp
            return nil
        case .representativeDoubleClap:
            guard var result = ambientResult else { return nil }
            if let started = representativeStartedAt, frame.timestamp - started >= representativeDuration {
                result.warnings.append(.representativeClapMissing); result.confidence *= 0.4; return result
            }
            let threshold = max(0.025, result.highNoisePercentile * 2.5)
            guard frame.rmsEnergy > result.highNoisePercentile * 1.25 else { return nil }
            if frame.rmsEnergy >= 0.98 { result.warnings.append(.representativeClapClipped); result.confidence *= 0.4; return result }
            guard (0.006...0.12).contains(frame.peakDuration), frame.highFrequencyRatio > 0.2, frame.spectralFlatness > 0.12 else { result.warnings.append(.representativeSignalUnclear); result.confidence *= 0.6; return result }
            guard frame.rmsEnergy >= threshold else { result.warnings.append(.representativeClapTooQuiet); result.confidence *= 0.5; return result }
            guard let firstClap else { self.firstClap = frame; return nil }
            let interval = frame.timestamp - firstClap.timestamp
            guard (0.08...1.2).contains(interval) else { result.warnings.append(.representativeIntervalOutOfRange); result.representativeInterval = interval; result.confidence *= 0.5; return result }
            let representativePeak = max(firstClap.rmsEnergy, frame.rmsEnergy)
            result.representativePeakEnergy = representativePeak
            result.representativeInterval = interval
            result.recommendedMinimumInterval = max(0.08, interval * 0.55)
            result.recommendedMaximumInterval = min(1.2, max(result.recommendedMinimumInterval + 0.08, interval * 1.55))
            let signalRatio = min(20, representativePeak / max(0.001, result.ambientNoiseFloor))
            result.recommendedSensitivity = min(0.95, max(0.15, 0.35 + signalRatio / 35))
            result.confidence = min(1, result.confidence * min(1, signalRatio / 6))
            return result
        }
    }
}

public enum ClapPauseReason: String, Codable, Equatable, Sendable {
    case repeatedFalseDetections
    case unusableNoise
    case permissionRevoked
    case audioHardwareUnavailable
    case audioRouteChanged
    case audioInterrupted
    case restartRequiresResume
    case configurationChanged
    case unusableInputFormat
    case repeatedClipping
    case manualPause
    case unsafeApplicationState

    public var displayName: String {
        switch self {
        case .repeatedFalseDetections: "repeated false detections"
        case .unusableNoise: "ambient noise is unusable"
        case .permissionRevoked: "microphone permission is unavailable"
        case .audioHardwareUnavailable: "audio hardware is unavailable"
        case .audioRouteChanged: "the audio route changed"
        case .audioInterrupted: "audio capture was interrupted"
        case .restartRequiresResume: "the app restarted"
        case .configurationChanged: "the detection configuration changed"
        case .unusableInputFormat: "the microphone input format is unusable"
        case .repeatedClipping: "repeated clipping prevents reliable analysis"
        case .manualPause: "listening was paused manually"
        case .unsafeApplicationState: "the application cannot listen safely in its current state"
        }
    }
}

public enum ClapListenerState: Equatable, Sendable {
    case stopped
    case calibrating(ClapCalibrationPhase)
    case calibrated(ClapCalibrationResult)
    case listening
    case testing
    case testSucceeded
    case paused(ClapPauseReason)
    case recovering(ClapPauseReason, attempt: Int)

    public var displayName: String {
        switch self {
        case .stopped: "Off"
        case .calibrating(.ambientNoise): "Calibration: sampling ambient noise locally"
        case .calibrating(.representativeDoubleClap): "Calibration: perform one representative double clap"
        case .calibrated: "Calibrated — resume when ready"
        case .listening: "Listening"
        case .testing: "Test mode — no scene will run"
        case .testSucceeded: "Test succeeded — no scene ran"
        case .paused(let reason): "Paused: \(reason.displayName)"
        case .recovering(let reason, let attempt): "Recovering from \(reason.displayName) (attempt \(attempt))"
        }
    }

    public var isCalibrating: Bool { if case .calibrating = self { true } else { false } }
}

public enum ClapRejectionReason: String, Codable, Equatable, Sendable {
    case tooQuiet
    case tooLoudOrClipped
    case intervalTooShort
    case intervalTooLong
    case resemblesSpeechOrNoise
    case detectorInCooldown

    public var displayName: String { switch self { case .tooQuiet: "Too quiet"; case .tooLoudOrClipped: "Too loud or clipped"; case .intervalTooShort: "Interval too short"; case .intervalTooLong: "Interval too long"; case .resemblesSpeechOrNoise: "Signal resembles ongoing speech or noise"; case .detectorInCooldown: "Detector in cooldown" } }
}

public enum ClapTestStatus: Equatable, Sendable {
    case listening
    case detectedTransient
    case firstClap
    case waitingForSecondClap
    case succeeded
    case rejected(ClapRejectionReason)
    case cooldown(remainingSeconds: Double)
    case stopped

    public var displayName: String { switch self { case .listening: "Listening — no scene will run"; case .detectedTransient: "Detected a transient"; case .firstClap: "First clap detected"; case .waitingForSecondClap: "Waiting for the second clap"; case .succeeded: "Double clap detected successfully — no scene ran"; case .rejected(let reason): "Rejected: \(reason.displayName)"; case .cooldown(let remaining): "Cooldown: \(String(format: "%.1f", remaining)) seconds remaining"; case .stopped: "Test stopped" } }
}

public enum AudioFeatureSourceEvent: Equatable, Sendable {
    case routeChanged
    case interrupted
    case hardwareUnavailable
    case permissionRevoked
    case unusableInputFormat
    case unsafeApplicationState
}

@MainActor
public protocol AudioFeatureSourcing: AnyObject {
    var isRunning: Bool { get }
    func start(onFrame: @escaping (AudioFeatureFrame) -> Void, onEvent: @escaping (AudioFeatureSourceEvent) -> Void) throws
    func stop()
}

@MainActor
public protocol ClapRecoveryScheduling: AnyObject {
    func schedule(after delay: TimeInterval, operation: @escaping @MainActor () -> Void)
    func cancel()
}

@MainActor
public final class TaskClapRecoveryScheduler: ClapRecoveryScheduling {
    private var task: Task<Void, Never>?

    public init() {}

    public func schedule(after delay: TimeInterval, operation: @escaping @MainActor () -> Void) {
        cancel()
        task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(max(0, delay)))
            guard !Task.isCancelled else { return }
            operation()
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
    }
}

public struct ClapReliabilityMonitor: Sendable {
    public var maximumRejectedTransients: Int
    public var rejectionWindow: TimeInterval
    public var maximumConsecutiveNoisyFrames: Int
    public var maximumConsecutiveClippedFrames: Int
    private var rejectedAt: [TimeInterval] = []
    private var noisyFrameCount = 0
    private var clippedFrameCount = 0

    public init(maximumRejectedTransients: Int = 6, rejectionWindow: TimeInterval = 20, maximumConsecutiveNoisyFrames: Int = 120, maximumConsecutiveClippedFrames: Int = 8) {
        self.maximumRejectedTransients = maximumRejectedTransients
        self.rejectionWindow = rejectionWindow
        self.maximumConsecutiveNoisyFrames = maximumConsecutiveNoisyFrames
        self.maximumConsecutiveClippedFrames = maximumConsecutiveClippedFrames
    }

    public mutating func observe(frame: AudioFeatureFrame, event: ClapDetectionEvent, calibratedNoiseFloor: Double?) -> ClapPauseReason? {
        if event == .rejected, frame.rmsEnergy < 0.98 {
            rejectedAt.append(frame.timestamp)
            rejectedAt.removeAll { frame.timestamp - $0 > rejectionWindow }
            if rejectedAt.count >= maximumRejectedTransients { return .repeatedFalseDetections }
        }
        let noiseLimit = max(0.18, (calibratedNoiseFloor ?? 0.02) * 8)
        if frame.rmsEnergy > noiseLimit { noisyFrameCount += 1 } else { noisyFrameCount = 0 }
        if noisyFrameCount >= maximumConsecutiveNoisyFrames { return .unusableNoise }
        if frame.rmsEnergy >= 0.98 { clippedFrameCount += 1 } else { clippedFrameCount = 0 }
        if clippedFrameCount >= maximumConsecutiveClippedFrames { return .repeatedClipping }
        return nil
    }

    public mutating func reset() { rejectedAt.removeAll(); noisyFrameCount = 0; clippedFrameCount = 0 }
}
