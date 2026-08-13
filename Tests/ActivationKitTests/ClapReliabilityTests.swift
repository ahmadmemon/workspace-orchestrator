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

    func testCalibrationSettingsExistOnlyAfterUsableResultIsConfirmed() {
        let base = ClapConfiguration(enabled: true, sensitivity: 0.4, minimumInterval: 0.12, maximumInterval: 0.65)
        let usable = ClapCalibrationResult(sampleCount: 50, ambientNoiseFloor: 0.01, highNoisePercentile: 0.02, recommendedSensitivity: 0.7, representativePeakEnergy: 0.3, representativeInterval: 0.3, confidence: 0.9, warnings: [])
        let accepted = usable.configurationAfterConfirmation(base: base, sensitivity: 0.75, minimumInterval: 0.16, maximumInterval: 0.58)
        XCTAssertEqual(accepted?.sensitivity, 0.75)
        XCTAssertEqual(accepted?.minimumInterval, 0.16)
        XCTAssertEqual(accepted?.maximumInterval, 0.58)

        let unusable = ClapCalibrationResult(sampleCount: 2, ambientNoiseFloor: 0.2, highNoisePercentile: 0.3, recommendedSensitivity: 0.2, confidence: 0.1, warnings: [.highAmbientNoise])
        XCTAssertNil(unusable.configurationAfterConfirmation(base: base, sensitivity: 0.2, minimumInterval: 0.1, maximumInterval: 0.4))
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
    func testRouteChangeUsesOneEngineAndRecoversWithinBound() throws {
        let source = SyntheticAudioFeatureSource()
        let scheduler = ManualRecoveryScheduler()
        var states: [ClapListenerState] = []
        let listener = LocalClapListener(configuration: .init(enabled: true), audioSource: source, recoveryScheduler: scheduler, onDoubleClap: {}, onStateChange: { states.append($0) })
        try listener.startExplicitly()
        XCTAssertEqual(listener.state, .listening)
        source.emit(event: .routeChanged)
        XCTAssertEqual(listener.state, .recovering(.audioRouteChanged, attempt: 1))
        XCTAssertFalse(source.isRunning)
        XCTAssertEqual(source.startCount, 1)
        scheduler.run()
        XCTAssertEqual(listener.state, .listening)
        XCTAssertEqual(source.startCount, 2)
        XCTAssertTrue(states.contains(.recovering(.audioRouteChanged, attempt: 1)))
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
        try listener.beginCalibration(duration: 1, representativeDuration: 2)
        for index in 0...50 { source.emit(frame: .init(timestamp: Double(index) / 50, rmsEnergy: 0.01, peakDuration: 0.02, highFrequencyRatio: 0.05, spectralFlatness: 0.04)) }
        XCTAssertEqual(listener.state, .calibrating(.representativeDoubleClap))
        source.emit(frame: clap(1.2))
        source.emit(frame: clap(1.5))
        XCTAssertEqual(calibrationResult?.isUsable, true)
        XCTAssertEqual(calibrationResult?.representativeInterval ?? 0, 0.3, accuracy: 0.001)
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

    @MainActor
    func testDeviceLossRecoveryStopsAfterBoundedFailures() throws {
        let source = SyntheticAudioFeatureSource()
        let scheduler = ManualRecoveryScheduler()
        let listener = LocalClapListener(configuration: .init(enabled: true), audioSource: source, recoveryScheduler: scheduler, maximumRecoveryAttempts: 2, onDoubleClap: {})
        try listener.startExplicitly()
        source.failNextStarts = 2
        source.emit(event: .hardwareUnavailable)
        scheduler.run()
        XCTAssertEqual(listener.state, .recovering(.audioHardwareUnavailable, attempt: 2))
        scheduler.run()
        XCTAssertEqual(listener.state, .paused(.audioHardwareUnavailable))
        XCTAssertEqual(source.startCount, 3)
        XCTAssertFalse(source.isRunning)
        XCTAssertFalse(scheduler.hasPendingOperation)
    }

    @MainActor
    func testInterruptionRecoversOnceHardwareIsReady() throws {
        let source = SyntheticAudioFeatureSource()
        let scheduler = ManualRecoveryScheduler()
        let listener = LocalClapListener(configuration: .init(enabled: true), audioSource: source, recoveryScheduler: scheduler, onDoubleClap: {})
        try listener.startExplicitly()
        source.emit(event: .interrupted)
        XCTAssertEqual(listener.state, .recovering(.audioInterrupted, attempt: 1))
        scheduler.run()
        XCTAssertEqual(listener.state, .listening)
    }

    @MainActor
    func testUnusableInputFormatUsesBoundedRecovery() throws {
        let source = SyntheticAudioFeatureSource()
        let scheduler = ManualRecoveryScheduler()
        let listener = LocalClapListener(configuration: .init(enabled: true), audioSource: source, recoveryScheduler: scheduler, maximumRecoveryAttempts: 1, onDoubleClap: {})
        try listener.startExplicitly()
        source.failNextStarts = 1
        source.emit(event: .unusableInputFormat)
        scheduler.run()
        XCTAssertEqual(listener.state, .paused(.unusableInputFormat))
    }

    @MainActor
    func testRepeatedClippingAutoPausesWithExactReason() throws {
        let source = SyntheticAudioFeatureSource()
        let listener = LocalClapListener(configuration: .init(enabled: true), audioSource: source, onDoubleClap: {})
        try listener.startExplicitly()
        for index in 0..<8 { source.emit(frame: .init(timestamp: Double(index) / 10, rmsEnergy: 0.99, peakDuration: 0.02, highFrequencyRatio: 0.4, spectralFlatness: 0.3)) }
        XCTAssertEqual(listener.state, .paused(.repeatedClipping))
        XCTAssertFalse(source.isRunning)
    }

    @MainActor
    func testManualPauseRequiresExplicitResume() throws {
        let source = SyntheticAudioFeatureSource()
        let listener = LocalClapListener(configuration: .init(enabled: true), audioSource: source, onDoubleClap: {})
        try listener.startExplicitly()
        listener.pauseExplicitly()
        XCTAssertEqual(listener.state, .paused(.manualPause))
        XCTAssertEqual(source.startCount, 1)
        try listener.resumeExplicitly()
        XCTAssertEqual(listener.state, .listening)
        XCTAssertEqual(source.startCount, 2)
    }

    @MainActor
    func testCalibrationCanBeCancelledWithoutSavingAResult() throws {
        let source = SyntheticAudioFeatureSource()
        var result: ClapCalibrationResult?
        let listener = LocalClapListener(configuration: .init(enabled: true), audioSource: source, onDoubleClap: {}, onCalibration: { result = $0 })
        try listener.beginCalibration(duration: 1)
        listener.cancelCalibration()
        XCTAssertEqual(listener.state, .stopped)
        XCTAssertNil(result)
        XCTAssertFalse(source.isRunning)
    }

    @MainActor
    func testTestModeReportsProgressAndRejectionReasonsWithoutRunningAction() throws {
        let source = SyntheticAudioFeatureSource()
        var activationCount = 0
        var statuses: [ClapTestStatus] = []
        let listener = LocalClapListener(configuration: .init(enabled: true), audioSource: source, onDoubleClap: { activationCount += 1 }, onTestStatus: { statuses.append($0) })
        try listener.beginTest()
        source.emit(frame: .init(timestamp: 1, rmsEnergy: 0.02, peakDuration: 0.02, highFrequencyRatio: 0.4, spectralFlatness: 0.3))
        source.emit(frame: clap(2))
        XCTAssertTrue(statuses.contains(.listening))
        XCTAssertTrue(statuses.contains(.rejected(.tooQuiet)))
        XCTAssertTrue(statuses.contains(.detectedTransient))
        XCTAssertTrue(statuses.contains(.firstClap))
        XCTAssertTrue(statuses.contains(.waitingForSecondClap))
        XCTAssertEqual(activationCount, 0)
    }

    func testDetailedDetectorExplainsClippingSpeechTimingAndCooldown() {
        var detector = DoubleClapDetector(configuration: .init(enabled: true, minimumInterval: 0.12, maximumInterval: 0.65, cooldown: 2))
        XCTAssertEqual(detector.consumeDetailed(.init(timestamp: 0, rmsEnergy: 0.99, peakDuration: 0.02, highFrequencyRatio: 0.4, spectralFlatness: 0.3)).rejectionReason, .tooLoudOrClipped)
        XCTAssertEqual(detector.consumeDetailed(.init(timestamp: 1, rmsEnergy: 0.3, peakDuration: 0.3, highFrequencyRatio: 0.05, spectralFlatness: 0.05)).rejectionReason, .resemblesSpeechOrNoise)
        XCTAssertEqual(detector.consumeDetailed(clap(2)).event, .firstTransient)
        XCTAssertEqual(detector.consumeDetailed(clap(2.05)).rejectionReason, .intervalTooShort)
        XCTAssertEqual(detector.consumeDetailed(clap(3)).event, .firstTransient)
        XCTAssertEqual(detector.consumeDetailed(clap(3.8)).rejectionReason, .intervalTooLong)
        detector = DoubleClapDetector(configuration: .init(enabled: true, minimumInterval: 0.12, maximumInterval: 0.65, cooldown: 2))
        XCTAssertEqual(detector.consumeDetailed(clap(5)).event, .firstTransient)
        XCTAssertEqual(detector.consumeDetailed(clap(5.3)).event, .doubleClap)
        let cooldown = detector.consumeDetailed(clap(5.4))
        XCTAssertEqual(cooldown.rejectionReason, .detectorInCooldown)
        XCTAssertEqual(cooldown.cooldownRemaining ?? 0, 1.9, accuracy: 0.001)
    }

    private func clap(_ timestamp: Double) -> AudioFeatureFrame { .init(timestamp: timestamp, rmsEnergy: 0.3, peakDuration: 0.02, highFrequencyRatio: 0.4, spectralFlatness: 0.35) }
}

@MainActor
private final class SyntheticAudioFeatureSource: AudioFeatureSourcing {
    private var frameHandler: ((AudioFeatureFrame) -> Void)?
    private var eventHandler: ((AudioFeatureSourceEvent) -> Void)?
    private(set) var isRunning = false
    private(set) var startCount = 0
    var failNextStarts = 0
    func start(onFrame: @escaping (AudioFeatureFrame) -> Void, onEvent: @escaping (AudioFeatureSourceEvent) -> Void) throws {
        frameHandler = onFrame; eventHandler = onEvent; startCount += 1
        if failNextStarts > 0 { failNextStarts -= 1; isRunning = false; throw SyntheticError.startFailed }
        isRunning = true
    }
    func stop() { isRunning = false }
    func emit(frame: AudioFeatureFrame) { guard isRunning else { return }; frameHandler?(frame) }
    func emit(event: AudioFeatureSourceEvent) { guard isRunning else { return }; eventHandler?(event) }
}

private enum SyntheticError: Error { case startFailed }

@MainActor
private final class ManualRecoveryScheduler: ClapRecoveryScheduling {
    private var operation: (@MainActor () -> Void)?
    var hasPendingOperation: Bool { operation != nil }
    func schedule(after _: TimeInterval, operation: @escaping @MainActor () -> Void) { self.operation = operation }
    func cancel() { operation = nil }
    func run() { let pending = operation; operation = nil; pending?() }
}
