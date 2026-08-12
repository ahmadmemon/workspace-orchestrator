import AVFoundation
import Foundation
import Speech

@MainActor
public final class LocalClapListener {
    private let engine = AVAudioEngine(); private var detector: DoubleClapDetector; private let onDoubleClap: () -> Void
    public private(set) var isListening = false
    public init(configuration: ClapConfiguration, onDoubleClap: @escaping () -> Void) { detector = .init(configuration: configuration); self.onDoubleClap = onDoubleClap }
    public static func requestMicrophonePermission() async -> Bool { await AVAudioApplication.requestRecordPermission() }
    public func startExplicitly() throws {
        guard detector.configuration.enabled else { return }; let input = engine.inputNode; let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in guard let self, let channel = buffer.floatChannelData?.pointee else { return }; let count = Int(buffer.frameLength); guard count > 0 else { return }; var sum = 0.0, crossings = 0; var previous = channel[0]; for index in 0..<count { let sample = Double(channel[index]); sum += sample * sample; if (channel[index] >= 0) != (previous >= 0) { crossings += 1 }; previous = channel[index] }; let rms = sqrt(sum / Double(count)); let highRatio = Double(crossings) / Double(count); let frame = AudioFeatureFrame(timestamp: ProcessInfo.processInfo.systemUptime, rmsEnergy: rms, peakDuration: Double(count) / format.sampleRate, highFrequencyRatio: highRatio, spectralFlatness: min(1, highRatio * 4)); Task { @MainActor in if self.detector.consume(frame) == .doubleClap { self.onDoubleClap() } } }
        engine.prepare(); try engine.start(); isListening = true
    }
    public func stop() { engine.inputNode.removeTap(onBus: 0); engine.stop(); isListening = false }
}

@MainActor
public final class OnDeviceVoiceRecognizer {
    private let audioEngine = AVAudioEngine(); private var task: SFSpeechRecognitionTask?
    public init() {}
    public static func requestAuthorization() async -> Bool { await withCheckedContinuation { continuation in SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) } } }
    public func recognizeOnce(configuration: VoiceConfiguration, onTranscript: @escaping (String) -> Void, onError: @escaping (String) -> Void) throws {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: configuration.localeIdentifier)), recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else { throw VoiceError.onDeviceUnavailable }
        let request = SFSpeechAudioBufferRecognitionRequest(); request.requiresOnDeviceRecognition = true; request.shouldReportPartialResults = true
        let input = audioEngine.inputNode; let format = input.outputFormat(forBus: 0); input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in if let text = result?.bestTranscription.formattedString { onTranscript(text) }; if let error { onError(error.localizedDescription); Task { @MainActor in self?.stop() } } else if result?.isFinal == true { Task { @MainActor in self?.stop() } } }
        audioEngine.prepare(); try audioEngine.start(); Task { [weak self] in try? await Task.sleep(for: .seconds(configuration.timeoutSeconds)); self?.stop() }
    }
    public func stop() { task?.cancel(); task = nil; if audioEngine.isRunning { audioEngine.stop(); audioEngine.inputNode.removeTap(onBus: 0) } }
    public enum VoiceError: LocalizedError { case onDeviceUnavailable; public var errorDescription: String? { "On-device speech recognition is unavailable for the selected locale. Cloud recognition will not be used." } }
}
