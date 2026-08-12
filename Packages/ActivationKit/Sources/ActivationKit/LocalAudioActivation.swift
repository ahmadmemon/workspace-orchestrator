import AVFoundation
import Foundation
import Speech

public enum ClapAudioSourceError: LocalizedError {
    case permissionRequired
    case noInputDevice
    public var errorDescription: String? {
        switch self {
        case .permissionRequired: "Microphone permission is required before local double-clap detection can start."
        case .noInputDevice: "No usable microphone input is currently available. Double-clap detection remains paused."
        }
    }
}

@MainActor
public final class AVAudioFeatureSource: AudioFeatureSourcing {
    private let engine = AVAudioEngine()
    private var installedTap = false
    private var observers: [NSObjectProtocol] = []
    private var eventHandler: ((AudioFeatureSourceEvent) -> Void)?
    public private(set) var isRunning = false

    public init() {}

    public func start(onFrame: @escaping (AudioFeatureFrame) -> Void, onEvent: @escaping (AudioFeatureSourceEvent) -> Void) throws {
        stop()
        eventHandler = onEvent
        guard LocalClapListener.microphonePermissionStatus == .granted else { onEvent(.permissionRevoked); throw ClapAudioSourceError.permissionRequired }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { onEvent(.hardwareUnavailable); throw ClapAudioSourceError.noInputDevice }
        input.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
            guard let channel = buffer.floatChannelData?.pointee else { return }
            let count = Int(buffer.frameLength)
            guard count > 0 else { return }
            var sum = 0.0
            var crossings = 0
            var previous = channel[0]
            for index in 0..<count {
                let sample = Double(channel[index])
                sum += sample * sample
                if (channel[index] >= 0) != (previous >= 0) { crossings += 1 }
                previous = channel[index]
            }
            let highRatio = Double(crossings) / Double(count)
            let frame = AudioFeatureFrame(timestamp: ProcessInfo.processInfo.systemUptime, rmsEnergy: sqrt(sum / Double(count)), peakDuration: Double(count) / format.sampleRate, highFrequencyRatio: highRatio, spectralFlatness: min(1, highRatio * 4))
            Task { @MainActor in onFrame(frame) }
        }
        installedTap = true
        observers.append(NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in guard let source = self else { return }; Task { @MainActor in source.pauseForHardwareEvent(.routeChanged) } })
        observers.append(NotificationCenter.default.addObserver(forName: .AVCaptureDeviceWasDisconnected, object: nil, queue: .main) { [weak self] _ in guard let source = self else { return }; Task { @MainActor in source.pauseForHardwareEvent(.hardwareUnavailable) } })
        engine.prepare()
        do { try engine.start(); isRunning = true }
        catch { stop(); onEvent(.hardwareUnavailable); throw error }
    }

    public func stop() {
        if installedTap { engine.inputNode.removeTap(onBus: 0); installedTap = false }
        if engine.isRunning { engine.stop() }
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
        isRunning = false
    }

    private func pauseForHardwareEvent(_ event: AudioFeatureSourceEvent) {
        let handler = eventHandler
        stop()
        handler?(event)
    }
}

@MainActor
public final class LocalClapListener {
    private let source: any AudioFeatureSourcing
    private var detector: DoubleClapDetector
    private var monitor = ClapReliabilityMonitor()
    private var calibration = ClapCalibrationSession()
    private var calibratedNoiseFloor: Double?
    private let onDoubleClap: () -> Void
    private let onStateChange: (ClapListenerState) -> Void
    private let onCalibration: (ClapCalibrationResult) -> Void
    private let onTestDetection: () -> Void
    public private(set) var state: ClapListenerState = .stopped
    public var isListening: Bool { state == .listening }

    public init(configuration: ClapConfiguration, audioSource: (any AudioFeatureSourcing)? = nil, onDoubleClap: @escaping () -> Void, onStateChange: @escaping (ClapListenerState) -> Void = { _ in }, onCalibration: @escaping (ClapCalibrationResult) -> Void = { _ in }, onTestDetection: @escaping () -> Void = {}) {
        detector = .init(configuration: configuration)
        source = audioSource ?? AVAudioFeatureSource()
        self.onDoubleClap = onDoubleClap
        self.onStateChange = onStateChange
        self.onCalibration = onCalibration
        self.onTestDetection = onTestDetection
    }

    public static func requestMicrophonePermission() async -> Bool { await AVAudioApplication.requestRecordPermission() }
    public static var microphonePermissionStatus: ActivationPermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) { case .authorized: .granted; case .denied: .denied; case .restricted: .restricted; case .notDetermined: .notDetermined; @unknown default: .restricted }
    }

    public func startExplicitly() throws {
        guard detector.configuration.enabled else { setState(.stopped); return }
        detector = .init(configuration: detector.configuration)
        monitor.reset()
        try startSource(state: .listening)
    }

    public func beginCalibration(duration: TimeInterval = 5) throws {
        calibration = .init(duration: duration)
        try startSource(state: .calibrating)
    }

    public func beginTest() throws {
        detector = .init(configuration: detector.configuration)
        try startSource(state: .testing)
    }

    public func resumeExplicitly() throws { try startExplicitly() }

    public func stop() { source.stop(); setState(.stopped) }

    private func startSource(state: ClapListenerState) throws {
        source.stop()
        setState(state)
        do { try source.start(onFrame: { [weak self] frame in self?.consume(frame) }, onEvent: { [weak self] event in self?.handle(event) }) }
        catch {
            if case .paused = self.state {} else { setState(.paused(.audioHardwareUnavailable)) }
            throw error
        }
    }

    private func consume(_ frame: AudioFeatureFrame) {
        switch state {
        case .calibrating:
            if let result = calibration.consume(frame) {
                calibratedNoiseFloor = result.ambientNoiseFloor
                source.stop()
                onCalibration(result)
                setState(result.isUsable ? .calibrated(result) : .paused(.unusableNoise))
            }
        case .listening, .testing:
            let event = detector.consume(frame)
            if state == .listening, let reason = monitor.observe(frame: frame, event: event, calibratedNoiseFloor: calibratedNoiseFloor) { pause(reason); return }
            if event == .doubleClap {
                if state == .testing { source.stop(); setState(.testSucceeded); onTestDetection() }
                else { onDoubleClap() }
            }
        default: break
        }
    }

    private func handle(_ event: AudioFeatureSourceEvent) {
        switch event {
        case .routeChanged: pause(.audioRouteChanged)
        case .interrupted: pause(.audioInterrupted)
        case .hardwareUnavailable: pause(.audioHardwareUnavailable)
        case .permissionRevoked: pause(.permissionRevoked)
        }
    }

    private func pause(_ reason: ClapPauseReason) { source.stop(); setState(.paused(reason)) }
    private func setState(_ value: ClapListenerState) { state = value; onStateChange(value) }
}

@MainActor
public final class OnDeviceVoiceRecognizer {
    private let audioEngine = AVAudioEngine(); private var task: SFSpeechRecognitionTask?
    public init() {}
    public static func requestAuthorization() async -> Bool { await withCheckedContinuation { continuation in SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) } } }
    public static var speechPermissionStatus: ActivationPermissionStatus {
        switch SFSpeechRecognizer.authorizationStatus() { case .authorized: .granted; case .denied: .denied; case .restricted: .restricted; case .notDetermined: .notDetermined; @unknown default: .restricted }
    }
    public func recognizeOnce(configuration: VoiceConfiguration, onTranscript: @escaping (String, Bool) -> Void, onError: @escaping (String) -> Void) throws {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: configuration.localeIdentifier)), recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else { throw VoiceError.onDeviceUnavailable }
        let request = SFSpeechAudioBufferRecognitionRequest(); request.requiresOnDeviceRecognition = true; request.shouldReportPartialResults = true
        let input = audioEngine.inputNode; let format = input.outputFormat(forBus: 0); input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in if let result { onTranscript(result.bestTranscription.formattedString, result.isFinal) }; if let error { onError(error.localizedDescription); Task { @MainActor in self?.stop() } } else if result?.isFinal == true { Task { @MainActor in self?.stop() } } }
        audioEngine.prepare(); try audioEngine.start(); Task { [weak self] in try? await Task.sleep(for: .seconds(configuration.timeoutSeconds)); self?.stop() }
    }
    public func stop() { task?.cancel(); task = nil; if audioEngine.isRunning { audioEngine.stop(); audioEngine.inputNode.removeTap(onBus: 0) } }
    public enum VoiceError: LocalizedError { case onDeviceUnavailable; public var errorDescription: String? { "On-device speech recognition is unavailable for the selected locale. Cloud recognition will not be used." } }
}
