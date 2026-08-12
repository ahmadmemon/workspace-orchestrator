import Foundation

public struct AudioFeatureFrame: Equatable, Sendable {
    public var timestamp: TimeInterval; public var rmsEnergy: Double; public var peakDuration: Double; public var highFrequencyRatio: Double; public var spectralFlatness: Double
    public init(timestamp: TimeInterval, rmsEnergy: Double, peakDuration: Double, highFrequencyRatio: Double, spectralFlatness: Double) { self.timestamp = timestamp; self.rmsEnergy = rmsEnergy; self.peakDuration = peakDuration; self.highFrequencyRatio = highFrequencyRatio; self.spectralFlatness = spectralFlatness }
}
public enum ClapDetectionEvent: Equatable, Sendable { case none, firstTransient, doubleClap, rejected }

public struct DoubleClapDetector: Sendable {
    public var configuration: ClapConfiguration; private var noiseFloor: Double = 0.01; private var firstClapAt: TimeInterval?; private var cooldownUntil: TimeInterval = 0; private var transientCount = 0
    public init(configuration: ClapConfiguration = .init()) { self.configuration = configuration }
    public mutating func consume(_ frame: AudioFeatureFrame) -> ClapDetectionEvent {
        noiseFloor = noiseFloor * 0.96 + min(frame.rmsEnergy, noiseFloor * 3) * 0.04
        guard configuration.enabled, frame.timestamp >= cooldownUntil else { return .none }
        if let firstClapAt, frame.timestamp - firstClapAt > configuration.maximumInterval { self.firstClapAt = nil; transientCount = 0 }
        let threshold = noiseFloor * (3.2 - min(max(configuration.sensitivity, 0), 1) * 1.4)
        let clapLike = frame.rmsEnergy > max(0.025, threshold) && (0.006...0.12).contains(frame.peakDuration) && frame.highFrequencyRatio > 0.2 && frame.spectralFlatness > 0.12
        guard clapLike else { return .none }
        transientCount += 1
        guard let first = firstClapAt else { firstClapAt = frame.timestamp; return .firstTransient }
        let interval = frame.timestamp - first
        if interval < configuration.minimumInterval { return .rejected }
        if interval <= configuration.maximumInterval && transientCount == 2 { firstClapAt = nil; transientCount = 0; cooldownUntil = frame.timestamp + configuration.cooldown; return .doubleClap }
        firstClapAt = nil; transientCount = 0; return .rejected
    }
}
