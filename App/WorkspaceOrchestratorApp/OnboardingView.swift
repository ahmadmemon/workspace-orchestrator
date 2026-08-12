import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    @State private var page = 0

    private let pages: [(String, String, String)] = [
        ("Welcome", "square.grid.2x2.fill", "Restore a reviewed workspace and know when it is genuinely ready."),
        ("One command center", "point.3.connected.trianglepath.dotted", "Scenes coordinate applications, URLs, files, tools, services, health checks, and reviewed window layouts."),
        ("Local by design", "hand.raised.fill", "Scenes and redacted run history stay on this Mac. There is no account, telemetry, analytics, or cloud backend."),
        ("Create a safe starting point", "shippingbox.fill", "Create a scene yourself or install the inspectable demo. Nothing is executed by onboarding."),
        ("Global shortcut", "command", "Option–Command–Space opens the command palette. You can choose another supported shortcut later in Settings."),
        ("Window permission", "rectangle.on.rectangle", "Accessibility is optional and used only for reviewed window capture and restoration."),
        ("Microphone permission", "waveform", "Microphone access is optional. Double-clap processing is local, disabled by default, and never stores audio."),
        ("On-device speech", "quote.bubble.fill", "Voice commands are optional, use on-device recognition, and never fall back to cloud recognition."),
        ("Notifications", "bell.badge.fill", "Optional local notifications can report ready, warning, or failure state without including process output."),
        ("Launch at login", "power", "Optionally start the menu-bar app when you sign in. You can disable this at any time."),
        ("Ready", "checkmark.seal.fill", "Every permission and activation service remains under your control. Review a scene before the first activation.")
    ]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: pages[page].1)
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(ObsidianTokens.cyan)
                .accessibilityHidden(true)
            Text(pages[page].0).font(.largeTitle.bold())
            Text(pages[page].2)
                .multilineTextAlignment(.center)
                .foregroundStyle(ObsidianTokens.secondaryText)
                .frame(maxWidth: 520)
            pageAction
            Spacer()
            HStack {
                Button("Skip optional setup") { model.completeOnboarding() }
                Spacer()
                Text("\(page + 1) of \(pages.count)").font(.caption.monospacedDigit()).foregroundStyle(ObsidianTokens.mutedText)
                Spacer()
                if page > 0 { Button("Back") { page -= 1 } }
                Button(page == pages.count - 1 ? "Open Command Center" : "Continue") {
                    if page == pages.count - 1 { model.completeOnboarding() } else { page += 1 }
                }
                .buttonStyle(.borderedProminent)
                .tint(ObsidianTokens.activeCyan)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(36)
        .background(ObsidianTokens.base)
        .foregroundStyle(ObsidianTokens.primaryText)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var pageAction: some View {
        switch page {
        case 3:
            Button("Install Demo Scene") { Task { await model.installDemoScene() } }.buttonStyle(.bordered)
        case 5:
            HStack {
                Button("Request Accessibility") { _ = model.accessibilityPermission.requestExplicitly() }.buttonStyle(.bordered)
                Button("Not now") { page += 1 }.buttonStyle(.plain)
            }
        case 6:
            Button("Enable Double-Clap") { Task { await model.setClapEnabled(true) } }.buttonStyle(.bordered)
        case 7:
            Button("Try Voice Command") { Task { await model.beginVoiceCommand() } }.buttonStyle(.bordered)
        case 8:
            Button("Enable Notifications") { Task { await model.setNotificationsEnabled(true) } }.buttonStyle(.bordered)
        case 9:
            Toggle("Launch Workspace Orchestrator at login", isOn: Binding(get: { model.launchAtLoginStatus == .enabled }, set: model.setLaunchAtLogin))
                .toggleStyle(.switch)
                .frame(maxWidth: 360)
        default:
            EmptyView()
        }
    }
}
