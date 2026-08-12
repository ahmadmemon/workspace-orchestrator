import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @AppStorage("appearanceMode") private var appearanceMode = "Obsidian"
    @AppStorage("notificationsEnabled") private var notifications = false
    @AppStorage("spokenStatusEnabled") private var spokenStatus = false
    @AppStorage("voiceEnabled") private var voiceEnabled = false
    @AppStorage("reduceCustomEffects") private var reduceEffects = false
    @AppStorage("hotKeySelection") private var hotKeySelection = "optionCommandSpace"
    @AppStorage("hotKeyLabel") private var hotKeyLabel = "⌥⌘Space"
    @AppStorage("clapSensitivity") private var clapSensitivity = 0.65
    @AppStorage("voiceLocaleIdentifier") private var voiceLocale = Locale.current.identifier
    @AppStorage("voiceActivationPhrase") private var voicePhrase = "Workspace online"
    var body: some View {
        TabView {
            Form { Toggle("Launch at login", isOn: Binding(get: { model.launchAtLoginStatus == .enabled }, set: model.setLaunchAtLogin)); LabeledContent("Launch status", value: model.launchAtLoginStatus.rawValue); Toggle("Local notifications", isOn: Binding(get: { notifications }, set: { enabled in notifications = enabled; Task { await model.setNotificationsEnabled(enabled) } })); LabeledContent("Notification permission", value: model.notificationPermissionStatus.rawValue); LabeledContent("Default dashboard", value: "Command Center"); Text("Updates are checked only when requested and open the official GitHub Releases source.").foregroundStyle(.secondary) }.padding(24).tabItem { Label("General", systemImage: "gear") }
            Form { Picker("Theme", selection: $appearanceMode) { Text("Obsidian").tag("Obsidian"); Text("Follow System").tag("System") }; Toggle("Reduce custom effects", isOn: $reduceEffects); Text("System Reduce Motion, Reduce Transparency, and Increase Contrast are always respected.").foregroundStyle(.secondary) }.padding(24).tabItem { Label("Appearance", systemImage: "paintbrush") }
            Form { Picker("Global shortcut", selection: $hotKeySelection) { Text("⌥⌘Space").tag("optionCommandSpace"); Text("⌃⌥Space").tag("controlOptionSpace"); Text("⇧⌘Space").tag("shiftCommandSpace") }.onChange(of: hotKeySelection) { _, selection in applyHotKey(selection) }; LabeledContent("Registered shortcut", value: hotKeyLabel); Toggle("Double-clap detection", isOn: Binding(get: { model.clapListening }, set: { enabled in Task { await model.setClapEnabled(enabled) } })); Slider(value: $clapSensitivity, in: 0.1...1) { Text("Clap sensitivity") } minimumValueLabel: { Text("Low") } maximumValueLabel: { Text("High") }.onChange(of: clapSensitivity) { _, _ in if model.clapListening { Task { await model.setClapEnabled(false); await model.setClapEnabled(true) } } }; Toggle("On-device voice commands", isOn: $voiceEnabled); TextField("Voice locale", text: $voiceLocale); TextField("Activation phrase", text: $voicePhrase); Button("Begin Voice Command") { Task { await model.beginVoiceCommand() } }.disabled(!voiceEnabled || model.voiceListening); Toggle("Spoken status", isOn: Binding(get: { spokenStatus }, set: { spokenStatus = $0; model.setSpokenStatusEnabled($0) })); LabeledContent("Microphone", value: model.microphonePermissionStatus.rawValue); LabeledContent("Speech recognition", value: model.speechPermissionStatus.rawValue); Text("Audio features remain off until explicitly enabled and permitted. Clap audio is never stored; voice does not fall back to cloud recognition.").foregroundStyle(.secondary) }.padding(24).tabItem { Label("Activation", systemImage: "waveform") }
            Form { LabeledContent("Default concurrency", value: "3"); LabeledContent("Managed process grace", value: "5 seconds"); Text("Process-capable actions require exact-configuration approval. There is no global approve-everything option.").foregroundStyle(.secondary) }.padding(24).tabItem { Label("Execution", systemImage: "bolt") }
            Form { LabeledContent("History retention", value: "30 days / 200 runs"); LabeledContent("Secrets", value: "macOS Keychain references"); Text("No account, telemetry, analytics, cloud sync, or hosted backend.").foregroundStyle(.secondary) }.padding(24).tabItem { Label("Privacy", systemImage: "hand.raised") }
            Form { Button("Open Permission Center") { model.selectedSection = .permissions }; LabeledContent("Accessibility", value: model.accessibilityPermission.status().rawValue); LabeledContent("Microphone", value: model.microphonePermissionStatus.rawValue); LabeledContent("Speech", value: model.speechPermissionStatus.rawValue); LabeledContent("Notifications", value: model.notificationPermissionStatus.rawValue) }.padding(24).tabItem { Label("Permissions", systemImage: "lock.shield") }
            Form { Button("Open Integration Center") { model.selectedSection = .integrations }; LabeledContent("Detected", value: "\(model.integrations.filter(\.installed).count) of \(model.integrations.count)"); Text("Tool discovery is local. Workspace Orchestrator does not install tools or manage their credentials.").foregroundStyle(.secondary) }.padding(24).tabItem { Label("Integrations", systemImage: "puzzlepiece.extension") }
            Form { Button("Reopen Onboarding") { model.resetOnboarding() }; Button("Open Diagnostics") { model.selectedSection = .diagnostics }; Button("Clear Run History", role: .destructive) { Task { await model.clearRunHistory() } }; Text("Process approval has no global bypass. Release updates remain explicit downloads from the official source.").foregroundStyle(.secondary) }.padding(24).tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
            Form { LabeledContent("Version", value: model.appVersion); LabeledContent("Build", value: model.buildNumber); Link("Check for Updates", destination: URL(string: "https://github.com/ahmadmemon/workspace-orchestrator/releases")!); Link("Documentation", destination: URL(string: "https://github.com/ahmadmemon/workspace-orchestrator/tree/main/docs")!) }.padding(24).tabItem { Label("About", systemImage: "info.circle") }
        }.frame(width: 620, height: 420)
    }

    private func applyHotKey(_ selection: String) {
        switch selection {
        case "controlOptionSpace": hotKeyLabel = "⌃⌥Space"; model.updateGlobalHotKey(keyCode: 49, modifiers: 6_144, label: hotKeyLabel)
        case "shiftCommandSpace": hotKeyLabel = "⇧⌘Space"; model.updateGlobalHotKey(keyCode: 49, modifiers: 768, label: hotKeyLabel)
        default: hotKeyLabel = "⌥⌘Space"; model.updateGlobalHotKey(keyCode: 49, modifiers: 2_304, label: hotKeyLabel)
        }
    }
}
