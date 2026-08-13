import SwiftUI

struct VoiceCommandView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 22) {
            WorkspaceCoreView(status: model.voiceListening ? .checking : .idle, progress: model.voiceListening ? 0.5 : 0, compact: true)
            Text(model.voiceListening ? "Listening on this Mac" : "Confirm Voice Command").font(.title2.bold())
            Text(model.voiceTranscript.isEmpty ? "Say “\(model.voiceActivationPhrase), run” followed by an exact scene name, or ask to show Dashboard, Scenes, or History." : model.voiceTranscript)
                .font(model.voiceTranscript.isEmpty ? .body : .title3)
                .foregroundStyle(model.voiceTranscript.isEmpty ? ObsidianTokens.secondaryText : ObsidianTokens.primaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
            Text("On-device recognition is required. Transcripts are not retained in scene history.")
                .font(.caption)
                .foregroundStyle(ObsidianTokens.mutedText)

            if let suggested = model.voiceSuggestedScene {
                VStack(spacing: 10) {
                    Text("Did you mean “\(suggested)”?" ).font(.headline)
                    Button("Run \(suggested)") { model.confirmVoiceScene(named: suggested) }.buttonStyle(.borderedProminent)
                }.obsidianPanel()
            }
            if !model.voiceAmbiguousScenes.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Choose a scene").font(.headline)
                    ForEach(model.voiceAmbiguousScenes, id: \.self) { name in Button("Run \(name)") { model.confirmVoiceScene(named: name) } }
                }.obsidianPanel()
            }
            Spacer()
            Button(model.voiceListening ? "Cancel Listening" : "Close", role: .cancel) { model.cancelVoiceCommand() }
        }
        .padding(28)
        .frame(width: 580, height: 460)
        .background(ObsidianTokens.base)
        .foregroundStyle(ObsidianTokens.primaryText)
        .accessibilityIdentifier("voiceCommandPanel")
    }
}
