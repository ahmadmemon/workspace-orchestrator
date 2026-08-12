import Foundation

public enum ClapCalibrationWarning: String, Codable, Equatable, Sendable {
    case tooFewSamples
    case highAmbientNoise
    case unstableNoise
}

public struct ClapCalibrationResult: Codable, Equatable, Sendable {
    public var sampleCount: Int
    public var ambientNoiseFloor: Double
    public var highNoisePercentile: Double
    public var recommendedSensitivity: Double
    public var confidence: Double
    public var warnings: [ClapCalibrationWarning]
    public var isUsable: Bool { !warnings.contains(.tooFewSamples) && !warnings.contains(.highAmbientNoise) && !warnings.contains(.unstableNoise) }
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

public enum ClapPauseReason: String, Codable, Equatable, Sendable {
    case repeatedFalseDetections
    case unusableNoise
    case permissionRevoked
    case audioHardwareUnavailable
    case audioRouteChanged
    case audioInterrupted
    case restartRequiresResume
    case configurationChanged

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
        }
    }
}

public enum ClapListenerState: Equatable, Sendable {
    case stopped
    case calibrating
    case calibrated(ClapCalibrationResult)
    case listening
    case testing
    case testSucceeded
    case paused(ClapPauseReason)

    public var displayName: String {
        switch self {
        case .stopped: "Off"
        case .calibrating: "Calibrating ambient noise"
        case .calibrated: "Calibrated — resume when ready"
        case .listening: "Listening"
        case .testing: "Test mode — no scene will run"
        case .testSucceeded: "Test succeeded — no scene ran"
        case .paused(let reason): "Paused: \(reason.displayName)"
        }
    }
}

public enum AudioFeatureSourceEvent: Equatable, Sendable {
    case routeChanged
    case interrupted
    case hardwareUnavailable
    case permissionRevoked
}

@MainActor
public protocol AudioFeatureSourcing: AnyObject {
    var isRunning: Bool { get }
    func start(onFrame: @escaping (AudioFeatureFrame) -> Void, onEvent: @escaping (AudioFeatureSourceEvent) -> Void) throws
    func stop()
}

public struct ClapReliabilityMonitor: Sendable {
    public var maximumRejectedTransients: Int
    public var rejectionWindow: TimeInterval
    public var maximumConsecutiveNoisyFrames: Int
    private var rejectedAt: [TimeInterval] = []
    private var noisyFrameCount = 0

    public init(maximumRejectedTransients: Int = 6, rejectionWindow: TimeInterval = 20, maximumConsecutiveNoisyFrames: Int = 120) {
        self.maximumRejectedTransients = maximumRejectedTransients
        self.rejectionWindow = rejectionWindow
        self.maximumConsecutiveNoisyFrames = maximumConsecutiveNoisyFrames
    }

    public mutating func observe(frame: AudioFeatureFrame, event: ClapDetectionEvent, calibratedNoiseFloor: Double?) -> ClapPauseReason? {
        if event == .rejected {
            rejectedAt.append(frame.timestamp)
            rejectedAt.removeAll { frame.timestamp - $0 > rejectionWindow }
            if rejectedAt.count >= maximumRejectedTransients { return .repeatedFalseDetections }
        }
        let noiseLimit = max(0.18, (calibratedNoiseFloor ?? 0.02) * 8)
        if frame.rmsEnergy > noiseLimit { noisyFrameCount += 1 } else { noisyFrameCount = 0 }
        if noisyFrameCount >= maximumConsecutiveNoisyFrames { return .unusableNoise }
        return nil
    }

    public mutating func reset() { rejectedAt.removeAll(); noisyFrameCount = 0 }
}
