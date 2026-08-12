import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @AppStorage("appearanceMode") private var appearanceMode = "Obsidian"
    @AppStorage("notificationsEnabled") private var notifications = false
    @AppStorage("spokenStatusEnabled") private var spokenStatus = false
    @AppStorage("voiceEnabled") private var voiceEnabled = false
    @AppStorage("reduceCustomEffects") private var reduceEffects = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    var body: some View {
        TabView {
            Form { Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: updateLogin)); Toggle("Local notifications", isOn: $notifications); LabeledContent("Default dashboard", value: "Command Center"); Text("Updates are checked only when requested and open the official GitHub Releases source.").foregroundStyle(.secondary) }.padding(24).tabItem { Label("General", systemImage: "gear") }
            Form { Picker("Theme", selection: $appearanceMode) { Text("Obsidian").tag("Obsidian"); Text("Follow System").tag("System") }; Toggle("Reduce custom effects", isOn: $reduceEffects); Text("System Reduce Motion, Reduce Transparency, and Increase Contrast are always respected.").foregroundStyle(.secondary) }.padding(24).tabItem { Label("Appearance", systemImage: "paintbrush") }
            Form { LabeledContent("Command palette", value: "⌥⌘Space"); Toggle("Double-clap detection", isOn: Binding(get: { model.clapListening }, set: { enabled in Task { await model.setClapEnabled(enabled) } })); Toggle("On-device voice commands", isOn: $voiceEnabled); Button("Begin Voice Command") { Task { await model.beginVoiceCommand() } }.disabled(!voiceEnabled || model.voiceListening); Toggle("Spoken status", isOn: Binding(get: { spokenStatus }, set: { spokenStatus = $0; model.setSpokenStatusEnabled($0) })); LabeledContent("Microphone", value: model.microphonePermissionStatus.rawValue); LabeledContent("Speech recognition", value: model.speechPermissionStatus.rawValue); Text("Audio features remain off until explicitly enabled and permitted. Clap audio is never stored; voice does not fall back to cloud recognition.").foregroundStyle(.secondary) }.padding(24).tabItem { Label("Activation", systemImage: "waveform") }
            Form { LabeledContent("Default concurrency", value: "3"); LabeledContent("Managed process grace", value: "5 seconds"); Text("Process-capable actions require exact-configuration approval. There is no global approve-everything option.").foregroundStyle(.secondary) }.padding(24).tabItem { Label("Execution", systemImage: "bolt") }
            Form { LabeledContent("History retention", value: "30 days / 200 runs"); LabeledContent("Secrets", value: "macOS Keychain references"); Button("Open Permissions") { model.selectedSection = .permissions }; Button("Reopen Onboarding") { model.onboardingPresented = true }; Text("No account, telemetry, analytics, cloud sync, or hosted backend.").foregroundStyle(.secondary) }.padding(24).tabItem { Label("Privacy", systemImage: "hand.raised") }
            Form { LabeledContent("Version", value: model.appVersion); LabeledContent("Build", value: model.buildNumber); Link("Check for Updates", destination: URL(string: "https://github.com/ahmadmemon/workspace-orchestrator/releases")!); Button("Open Diagnostics") { model.selectedSection = .diagnostics } }.padding(24).tabItem { Label("About", systemImage: "info.circle") }
        }.frame(width: 620, height: 420)
    }
    private func updateLogin(_ enabled: Bool) { do { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; launchAtLogin = SMAppService.mainApp.status == .enabled } catch { model.presentedError = error.localizedDescription; launchAtLogin = SMAppService.mainApp.status == .enabled } }
}
