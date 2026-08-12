import AppKit
import AVFoundation
import Foundation
import SceneCore

@MainActor
public final class SpokenStatusController {
    private let synthesizer = AVSpeechSynthesizer(); public var enabled = false
    public init() {}
    public func speak(sceneName: String, status: SceneRunStatus, warningCount: Int = 0, failedAction: String? = nil) {
        guard enabled, !NSWorkspace.shared.isVoiceOverEnabled else { return }
        let safeName = sceneName.replacingOccurrences(of: "/", with: " ")
        let text: String
        switch status { case .preparing, .running: text = "Preparing \(safeName)"; case .ready: text = "\(safeName) is ready"; case .readyWithWarnings: text = "\(safeName) is ready with \(warningCount) warning\(warningCount == 1 ? "" : "s")"; case .failed: text = failedAction.map { "\(safeName) failed while starting \($0)" } ?? "\(safeName) failed"; case .cancelled: text = "Current run cancelled"; default: return }
        synthesizer.speak(AVSpeechUtterance(string: text))
    }
}
