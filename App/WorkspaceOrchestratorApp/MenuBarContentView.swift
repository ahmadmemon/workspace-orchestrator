import AppKit
import SceneCore
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @AppStorage("menuBarPrimaryAction") private var primaryAction = "openDashboard"
    @AppStorage("defaultSceneID") private var defaultSceneID = ""
    private var status: SceneRunStatus { model.currentRun?.status ?? .idle }
    private var progress: Double { guard let run = model.currentRun, !run.actionRecords.isEmpty else { return 0 }; return Double(run.completedActionCount) / Double(run.actionRecords.count) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { WorkspaceCoreView(status: status, progress: progress, compact: true); VStack(alignment: .leading) { Text(model.currentRun?.sceneName ?? "Workspace Orchestrator").font(.headline); Text(status.displayName).font(.caption).foregroundStyle(status.color) }; Spacer() }
            Divider()
            Button(primaryActionLabel) { performPrimaryAction() }.buttonStyle(.borderedProminent).disabled(primaryAction == "runDefaultScene" && !model.scenes.contains { $0.id == defaultSceneID })
            if !model.favoriteScenes.isEmpty { Text("Favorites").font(.caption.bold()).foregroundStyle(.secondary); ForEach(model.favoriteScenes.prefix(5)) { scene in Button { model.run(scene) } label: { Label(scene.name, systemImage: "play.fill") }.disabled(model.isRunning || scene.trustState == .importedUntrusted) } }
            if model.isRunning { Button("Cancel Current Run", role: .destructive) { model.cancelCurrentRun() } }
            else if model.currentRun != nil { Button("Stop Current Scene", role: .destructive) { model.stopCurrentScene() } }
            Divider()
            Button("Open Dashboard") { open(.dashboard) }
            Button("Open Command Palette") { openWindow(id: "dashboard"); model.commandPalettePresented = true; NSApp.activate(ignoringOtherApps: true) }
            Button("Run History") { open(.history) }
            Button("Permissions") { open(.permissions) }
            Button { Task { await model.beginVoiceCommand() } } label: { Label(model.voiceListening ? "Voice Listening…" : "Begin Voice Command", systemImage: "waveform") }.disabled(model.voiceListening)
            Toggle(isOn: Binding(get: { model.clapEnabled }, set: { enabled in Task { await model.setClapEnabled(enabled) } })) { Label("Double-Clap Detection", systemImage: model.clapListening ? "ear.fill" : "ear") }
            if model.clapEnabled, !model.clapListening { Button("Resume Double-Clap Listening") { Task { await model.resumeClapListening() } }; Text(model.clapState.displayName).font(.caption).foregroundStyle(.secondary) }
            Divider()
            SettingsLink { Text("Settings") }
            Button("Quit Workspace Orchestrator") { NSApp.terminate(nil) }
        }.padding(14).frame(width: 330).background(ObsidianTokens.elevated)
    }
    private func open(_ section: AppSection) { model.selectedSection = section; openWindow(id: "dashboard"); NSApp.activate(ignoringOtherApps: true) }
    private var primaryActionLabel: String {
        switch primaryAction {
        case "showCommandPalette": "Open Command Palette"
        case "runDefaultScene": model.scenes.first(where: { $0.id == defaultSceneID }).map { "Run \($0.name)" } ?? "Choose a Default Scene"
        default: "Open Dashboard"
        }
    }
    private func performPrimaryAction() {
        switch primaryAction {
        case "showCommandPalette": openWindow(id: "dashboard"); model.commandPalettePresented = true; NSApp.activate(ignoringOtherApps: true)
        case "runDefaultScene": if let scene = model.scenes.first(where: { $0.id == defaultSceneID }) { model.run(scene) }
        default: open(.dashboard)
        }
    }
}
