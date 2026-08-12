import XCTest
@testable import ActivationKit

final class ClapReliabilityTests: XCTestCase {
    func testQuietCalibrationProducesUsableRecommendationWithoutRawAudio() {
        var calibration = ClapCalibrationSession(duration: 1, minimumSamples: 10)
        var result: ClapCalibrationResult?
        for index in 0...10 {
            result = calibration.consume(.init(timestamp: Double(index) / 10, rmsEnergy: 0.012 + Double(index % 2) * 0.001, peakDuration: 0.02, highFrequencyRatio: 0.05, spectralFlatness: 0.04)) ?? result
        }
        let value = try? XCTUnwrap(result)
        XCTAssertEqual(value?.sampleCount, 11)
        XCTAssertEqual(value?.warnings, [])
        XCTAssertEqual(value?.isUsable, true)
        XCTAssertGreaterThan(value?.confidence ?? 0, 0.5)
        XCTAssertTrue((0.2...0.9).contains(value?.recommendedSensitivity ?? 0))
    }

    func testNoisyCalibrationWarnsAndIsNotUsable() {
        var calibration = ClapCalibrationSession(duration: 1, minimumSamples: 10)
        var result: ClapCalibrationResult?
        for index in 0...10 { result = calibration.consume(.init(timestamp: Double(index) / 10, rmsEnergy: 0.2, peakDuration: 0.02, highFrequencyRatio: 0.3, spectralFlatness: 0.3)) ?? result }
        XCTAssertEqual(result?.isUsable, false)
        XCTAssertTrue(result?.warnings.contains(.highAmbientNoise) == true)
    }

    func testReliabilityMonitorPausesAfterRepeatedRejectedTransients() {
        var monitor = ClapReliabilityMonitor(maximumRejectedTransients: 3, rejectionWindow: 5)
        let frame: (Double) -> AudioFeatureFrame = { .init(timestamp: $0, rmsEnergy: 0.05, peakDuration: 0.02, highFrequencyRatio: 0.3, spectralFlatness: 0.2) }
        XCTAssertNil(monitor.observe(frame: frame(1), event: .rejected, calibratedNoiseFloor: 0.01))
        XCTAssertNil(monitor.observe(frame: frame(2), event: .rejected, calibratedNoiseFloor: 0.01))
        XCTAssertEqual(monitor.observe(frame: frame(3), event: .rejected, calibratedNoiseFloor: 0.01), .repeatedFalseDetections)
    }

    func testReliabilityMonitorPausesInSustainedUnusableNoise() {
        var monitor = ClapReliabilityMonitor(maximumConsecutiveNoisyFrames: 3)
        let frame: (Double) -> AudioFeatureFrame = { .init(timestamp: $0, rmsEnergy: 0.3, peakDuration: 0.2, highFrequencyRatio: 0.1, spectralFlatness: 0.1) }
        XCTAssertNil(monitor.observe(frame: frame(1), event: .none, calibratedNoiseFloor: 0.01))
        XCTAssertNil(monitor.observe(frame: frame(2), event: .none, calibratedNoiseFloor: 0.01))
        XCTAssertEqual(monitor.observe(frame: frame(3), event: .none, calibratedNoiseFloor: 0.01), .unusableNoise)
    }

    @MainActor
    func testRouteChangePausesUntilExplicitResume() throws {
        let source = SyntheticAudioFeatureSource()
        var states: [ClapListenerState] = []
        let listener = LocalClapListener(configuration: .init(enabled: true), audioSource: source, onDoubleClap: {}, onStateChange: { states.append($0) })
        try listener.startExplicitly()
        XCTAssertEqual(listener.state, .listening)
        source.emit(event: .routeChanged)
        XCTAssertEqual(listener.state, .paused(.audioRouteChanged))
        XCTAssertFalse(source.isRunning)
        XCTAssertEqual(source.startCount, 1)
        try listener.resumeExplicitly()
        XCTAssertEqual(listener.state, .listening)
        XCTAssertEqual(source.startCount, 2)
        XCTAssertTrue(states.contains(.paused(.audioRouteChanged)))
    }

    @MainActor
    func testControlledTestModeNeverRunsConfiguredAction() throws {
        let source = SyntheticAudioFeatureSource()
        var activationCount = 0
        var testCount = 0
        let listener = LocalClapListener(configuration: .init(enabled: true, minimumInterval: 0.12, maximumInterval: 0.65), audioSource: source, onDoubleClap: { activationCount += 1 }, onTestDetection: { testCount += 1 })
        try listener.beginTest()
        source.emit(frame: clap(1))
        source.emit(frame: clap(1.3))
        XCTAssertEqual(listener.state, .testSucceeded)
        XCTAssertEqual(testCount, 1)
        XCTAssertEqual(activationCount, 0)
        XCTAssertFalse(source.isRunning)
    }

    @MainActor
    func testListenerCalibrationCompletesFromFeaturesWithoutActivating() throws {
        let source = SyntheticAudioFeatureSource()
        var activationCount = 0
        var calibrationResult: ClapCalibrationResult?
        let listener = LocalClapListener(configuration: .init(enabled: true), audioSource: source, onDoubleClap: { activationCount += 1 }, onCalibration: { calibrationResult = $0 })
        try listener.beginCalibration(duration: 1)
        for index in 0...50 { source.emit(frame: .init(timestamp: Double(index) / 50, rmsEnergy: 0.01, peakDuration: 0.02, highFrequencyRatio: 0.05, spectralFlatness: 0.04)) }
        XCTAssertEqual(calibrationResult?.isUsable, true)
        XCTAssertEqual(activationCount, 0)
        XCTAssertFalse(source.isRunning)
        if case .calibrated = listener.state {} else { XCTFail("Expected calibrated state") }
    }

    @MainActor
    func testPermissionRevocationPausesWithoutAutomaticRestart() throws {
        let source = SyntheticAudioFeatureSource()
        let listener = LocalClapListener(configuration: .init(enabled: true), audioSource: source, onDoubleClap: {})
        try listener.startExplicitly()
        source.emit(event: .permissionRevoked)
        XCTAssertEqual(listener.state, .paused(.permissionRevoked))
        XCTAssertFalse(source.isRunning)
        XCTAssertEqual(source.startCount, 1)
    }

    private func clap(_ timestamp: Double) -> AudioFeatureFrame { .init(timestamp: timestamp, rmsEnergy: 0.3, peakDuration: 0.02, highFrequencyRatio: 0.4, spectralFlatness: 0.35) }
}

@MainActor
private final class SyntheticAudioFeatureSource: AudioFeatureSourcing {
    private var frameHandler: ((AudioFeatureFrame) -> Void)?
    private var eventHandler: ((AudioFeatureSourceEvent) -> Void)?
    private(set) var isRunning = false
    private(set) var startCount = 0
    func start(onFrame: @escaping (AudioFeatureFrame) -> Void, onEvent: @escaping (AudioFeatureSourceEvent) -> Void) throws { frameHandler = onFrame; eventHandler = onEvent; isRunning = true; startCount += 1 }
    func stop() { isRunning = false }
    func emit(frame: AudioFeatureFrame) { guard isRunning else { return }; frameHandler?(frame) }
    func emit(event: AudioFeatureSourceEvent) { guard isRunning else { return }; eventHandler?(event) }
}
