import Foundation

public struct AudioFeatureFrame: Equatable, Sendable {
    public var timestamp: TimeInterval; public var rmsEnergy: Double; public var peakDuration: Double; public var highFrequencyRatio: Double; public var spectralFlatness: Double
    public init(timestamp: TimeInterval, rmsEnergy: Double, peakDuration: Double, highFrequencyRatio: Double, spectralFlatness: Double) { self.timestamp = timestamp; self.rmsEnergy = rmsEnergy; self.peakDuration = peakDuration; self.highFrequencyRatio = highFrequencyRatio; self.spectralFlatness = spectralFlatness }
}
public enum ClapDetectionEvent: Equatable, Sendable { case none, firstTransient, doubleClap, rejected }
public struct ClapDetectionAnalysis: Equatable, Sendable {
    public var event: ClapDetectionEvent
    public var rejectionReason: ClapRejectionReason?
    public var cooldownRemaining: Double?
    public init(event: ClapDetectionEvent, rejectionReason: ClapRejectionReason? = nil, cooldownRemaining: Double? = nil) { self.event = event; self.rejectionReason = rejectionReason; self.cooldownRemaining = cooldownRemaining }
}

public struct DoubleClapDetector: Sendable {
    public var configuration: ClapConfiguration; private var noiseFloor: Double = 0.01; private var firstClapAt: TimeInterval?; private var cooldownUntil: TimeInterval = 0; private var transientCount = 0
    public init(configuration: ClapConfiguration = .init()) { self.configuration = configuration }
    public mutating func consume(_ frame: AudioFeatureFrame) -> ClapDetectionEvent {
        let analysis = consumeDetailed(frame)
        if [.tooQuiet, .tooLoudOrClipped, .resemblesSpeechOrNoise, .detectorInCooldown].contains(analysis.rejectionReason) { return .none }
        if analysis.rejectionReason == .intervalTooLong { return .firstTransient }
        return analysis.event
    }
    public mutating func consumeDetailed(_ frame: AudioFeatureFrame) -> ClapDetectionAnalysis {
        noiseFloor = noiseFloor * 0.96 + min(frame.rmsEnergy, noiseFloor * 3) * 0.04
        guard configuration.enabled else { return .init(event: .none) }
        if frame.timestamp < cooldownUntil { return .init(event: .none, rejectionReason: .detectorInCooldown, cooldownRemaining: cooldownUntil - frame.timestamp) }
        let threshold = noiseFloor * (3.2 - min(max(configuration.sensitivity, 0), 1) * 1.4)
        let energyThreshold = max(0.025, threshold)
        let transientShape = (0.006...0.12).contains(frame.peakDuration) && frame.highFrequencyRatio > 0.2 && frame.spectralFlatness > 0.12
        if frame.rmsEnergy >= 0.98 { return .init(event: .rejected, rejectionReason: .tooLoudOrClipped) }
        if transientShape, frame.rmsEnergy > noiseFloor * 1.25, frame.rmsEnergy <= energyThreshold { return .init(event: .rejected, rejectionReason: .tooQuiet) }
        if frame.rmsEnergy > energyThreshold, !transientShape { return .init(event: .rejected, rejectionReason: .resemblesSpeechOrNoise) }
        guard frame.rmsEnergy > energyThreshold, transientShape else { return .init(event: .none) }
        if let firstClapAt, frame.timestamp - firstClapAt > configuration.maximumInterval {
            self.firstClapAt = frame.timestamp; transientCount = 1
            return .init(event: .rejected, rejectionReason: .intervalTooLong)
        }
        transientCount += 1
        guard let first = firstClapAt else { firstClapAt = frame.timestamp; return .init(event: .firstTransient) }
        let interval = frame.timestamp - first
        if interval < configuration.minimumInterval { firstClapAt = nil; transientCount = 0; return .init(event: .rejected, rejectionReason: .intervalTooShort) }
        if interval <= configuration.maximumInterval && transientCount == 2 { firstClapAt = nil; transientCount = 0; cooldownUntil = frame.timestamp + configuration.cooldown; return .init(event: .doubleClap) }
        firstClapAt = nil; transientCount = 0; return .init(event: .rejected, rejectionReason: .resemblesSpeechOrNoise)
    }
}
