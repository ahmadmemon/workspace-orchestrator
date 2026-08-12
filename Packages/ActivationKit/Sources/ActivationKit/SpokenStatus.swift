import AppKit
import AVFoundation
import Foundation
import SceneCore

public enum SpokenStatusDetailLevel: String, CaseIterable, Sendable {
    case concise
    case detailed
}

@MainActor
public final class SpokenStatusController {
    private let synthesizer = AVSpeechSynthesizer(); public var enabled = false; public var detailLevel: SpokenStatusDetailLevel = .concise
    public init() {}
    public func speak(sceneName: String, status: SceneRunStatus, warningCount: Int = 0, failedAction: String? = nil) {
        guard enabled, !NSWorkspace.shared.isVoiceOverEnabled else { return }
        let safeName = sceneName.replacingOccurrences(of: "/", with: " ")
        let subject = detailLevel == .detailed ? safeName : "Workspace"
        let text: String
        switch status { case .preparing, .running: text = "Preparing \(subject)"; case .ready: text = "\(subject) is ready"; case .readyWithWarnings: text = detailLevel == .detailed ? "\(subject) is ready with \(warningCount) warning\(warningCount == 1 ? "" : "s")" : "Workspace is ready with warnings"; case .failed: text = detailLevel == .detailed ? (failedAction.map { "\(subject) failed while starting \($0)" } ?? "\(subject) failed") : "Workspace failed"; case .cancelled: text = "Current run cancelled"; default: return }
        synthesizer.speak(AVSpeechUtterance(string: text))
    }
}
