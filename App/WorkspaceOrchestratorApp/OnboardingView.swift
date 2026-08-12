import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    @State private var page = 0
    private let pages: [(String, String, String)] = [
        ("Welcome", "square.grid.2x2.fill", "Restore a reviewed workspace and know when it is genuinely ready."),
        ("Local by design", "hand.raised.fill", "Scenes and redacted run history stay on this Mac. There is no account, telemetry, analytics, or cloud backend."),
        ("Start safely", "shippingbox.fill", "Create a scene or install the inspectable demo. Nothing is installed or executed without your action."),
        ("Fast activation", "command", "The command palette uses Option–Command–Space. Global shortcuts, clap detection, and voice remain optional."),
        ("Window layouts", "rectangle.on.rectangle", "Accessibility is requested only when you choose capture or restoration. Every other feature remains available without it."),
        ("Audio privacy", "waveform", "Clap and voice modes are disabled by default. Clap audio is processed locally and never stored; voice requires on-device recognition."),
        ("Ready", "checkmark.seal.fill", "You can reopen onboarding and review every permission from Settings at any time.")
    ]
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: pages[page].1).font(.system(size: 64, weight: .semibold)).foregroundStyle(ObsidianTokens.cyan).accessibilityHidden(true)
            Text(pages[page].0).font(.largeTitle.bold())
            Text(pages[page].2).multilineTextAlignment(.center).foregroundStyle(ObsidianTokens.secondaryText).frame(maxWidth: 480)
            if page == 2 { Button("Install Demo Scene") { Task { await model.installDemoScene() } }.buttonStyle(.bordered) }
            if page == 4 { Button("Check Accessibility Permission") { _ = model.accessibilityPermission.requestExplicitly() }.buttonStyle(.bordered) }
            Spacer()
            HStack { Button("Skip") { model.completeOnboarding() }; Spacer(); Text("\(page + 1) of \(pages.count)").font(.caption.monospacedDigit()).foregroundStyle(ObsidianTokens.mutedText); Spacer(); Button(page == pages.count - 1 ? "Open Command Center" : "Continue") { if page == pages.count - 1 { model.completeOnboarding() } else { page += 1 } }.buttonStyle(.borderedProminent).tint(ObsidianTokens.activeCyan) }
        }.padding(36).background(ObsidianTokens.base).foregroundStyle(ObsidianTokens.primaryText)
    }
}
