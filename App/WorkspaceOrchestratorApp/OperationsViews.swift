import ActivationKit
import MacAutomation
import SceneCore
import SwiftUI

struct RunHistoryView: View {
    @ObservedObject var model: AppModel
    @State private var query = ""
    @State private var selectedStatus: SceneRunStatus?
    private var runs: [SceneRunResult] { model.runHistory.filter { (query.isEmpty || $0.sceneName.localizedCaseInsensitiveContains(query)) && (selectedStatus == nil || $0.status == selectedStatus) } }
    var body: some View { VStack(alignment: .leading, spacing: 16) { Text("Run History").font(.largeTitle.bold()); HStack { TextField("Search scenes", text: $query).textFieldStyle(.roundedBorder); Picker("Status", selection: $selectedStatus) { Text("All statuses").tag(SceneRunStatus?.none); ForEach(SceneRunStatus.allCases, id: \.self) { Text($0.displayName).tag(Optional($0)) } }.frame(width: 210) }; if runs.isEmpty { ContentUnavailableView("No Matching Runs", systemImage: "clock.arrow.circlepath", description: Text("Completed runs appear here with bounded redacted details.")) } else { List(runs) { run in HStack { WorkspaceCoreView(status: run.status, progress: run.actionRecords.isEmpty ? 0 : Double(run.completedActionCount) / Double(run.actionRecords.count), compact: true); VStack(alignment: .leading, spacing: 4) { Text(run.sceneName).font(.headline); Text(run.startedAt?.formatted() ?? "Unknown start").font(.caption).foregroundStyle(ObsidianTokens.mutedText); Text("\(run.completedActionCount) actions • \(run.warningCount) warnings • \(run.failureCount) failures").font(.caption.monospaced()) }; Spacer(); StatusBadge(text: run.status.displayName, color: run.status.color, symbol: run.status.symbol) }.padding(.vertical, 6).listRowBackground(ObsidianTokens.panel) }.scrollContentBackground(.hidden) } }.padding(28) }
}

struct IntegrationsView: View {
    @ObservedObject var model: AppModel
    var body: some View { VStack(alignment: .leading, spacing: 16) { Text("Integrations").font(.largeTitle.bold()); Text("Detected locally—no inventory leaves this Mac.").foregroundStyle(ObsidianTokens.secondaryText); List(model.integrations) { integration in HStack { Image(systemName: integration.installed ? "checkmark.circle.fill" : "circle.dashed").foregroundStyle(integration.installed ? ObsidianTokens.success : ObsidianTokens.mutedText); VStack(alignment: .leading, spacing: 3) { Text(integration.displayName).font(.headline); Text(integration.path ?? "Not found in a supported location").font(.caption.monospaced()).foregroundStyle(ObsidianTokens.secondaryText); Text(integration.privacyNote).font(.caption).foregroundStyle(ObsidianTokens.mutedText) }; Spacer(); if let version = integration.version { Text(version).font(.caption.monospaced()) }; StatusBadge(text: integration.installed ? "Installed" : "Missing", color: integration.installed ? ObsidianTokens.success : ObsidianTokens.warning, symbol: integration.installed ? "checkmark" : "questionmark") }.padding(.vertical, 7).listRowBackground(ObsidianTokens.panel) }.scrollContentBackground(.hidden) }.padding(28) }
}

struct PermissionsView: View {
    @ObservedObject var model: AppModel
    var body: some View { VStack(alignment: .leading, spacing: 18) { Text("Permissions").font(.largeTitle.bold()); Text("Optional capabilities ask only when you enable or use them.").foregroundStyle(ObsidianTokens.secondaryText); PermissionRow(title: "Accessibility", detail: "Reviewed window capture and layout restoration only", state: model.accessibilityPermission.status(), request: { _ = model.accessibilityPermission.requestExplicitly() }, settings: { Task { await model.accessibilityPermission.openSystemSettings() } }); PermissionRow(title: "Microphone", detail: "Opt-in local clap detection and explicit voice command sessions", state: permissionState(model.microphonePermissionStatus), request: { Task { await model.setClapEnabled(true) } }, settings: nil); PermissionRow(title: "Speech Recognition", detail: "On-device voice recognition only; no cloud fallback", state: permissionState(model.speechPermissionStatus), request: { Task { await model.beginVoiceCommand() } }, settings: nil); PermissionRow(title: "Notifications", detail: "Optional ready, warning, and failure notifications", state: .notDetermined, request: nil, settings: nil); Spacer() }.padding(28) }
    private func permissionState(_ state: ActivationPermissionStatus) -> PermissionState { switch state { case .notDetermined: .notDetermined; case .denied: .denied; case .granted: .granted; case .restricted: .unavailable } }
}
private struct PermissionRow: View { let title: String; let detail: String; let state: PermissionState; let request: (() -> Void)?; let settings: (() -> Void)?; var body: some View { HStack { Image(systemName: state == .granted ? "checkmark.shield.fill" : "shield.lefthalf.filled").font(.title2).foregroundStyle(state == .granted ? ObsidianTokens.success : ObsidianTokens.warning); VStack(alignment: .leading) { Text(title).font(.headline); Text(detail).foregroundStyle(ObsidianTokens.secondaryText) }; Spacer(); Text(state.rawValue.capitalized).font(.caption.monospaced()); if let request { Button("Request", action: request) }; if let settings { Button("Settings", action: settings) } }.obsidianPanel() } }

struct DiagnosticsView: View {
    @ObservedObject var model: AppModel
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 16) { Text("Diagnostics").font(.largeTitle.bold()); Group { LabeledContent("App version", value: model.appVersion); LabeledContent("Build", value: model.buildNumber); LabeledContent("macOS", value: ProcessInfo.processInfo.operatingSystemVersionString); LabeledContent("Architecture", value: architecture); LabeledContent("Scenes", value: "\(model.scenes.count)"); LabeledContent("Run history", value: "\(model.runHistory.count)"); LabeledContent("Accessibility", value: model.accessibilityPermission.status().rawValue); LabeledContent("Scene storage", value: "~/Library/Application Support/WorkspaceOrchestrator/scenes.json"); LabeledContent("Run history storage", value: "~/Library/Application Support/WorkspaceOrchestrator/RunHistory") }.obsidianPanel(); Text("Diagnostic exports redact common credentials and bounded output, but no detector can guarantee perfect secret detection.").font(.callout).foregroundStyle(ObsidianTokens.warning) }.padding(28) } }
    private var architecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}

struct WorkspaceCaptureView: View {
    @ObservedObject var model: AppModel
    @State private var selectedBundleIDs = Set<String>()
    @State private var name = "Captured Workspace"
    var body: some View { VStack(alignment: .leading, spacing: 16) { Text("Capture Current Workspace").font(.largeTitle.bold()); Text("Select applications. Window details are captured only with Accessibility permission and reviewed before save. Browser history, terminal history, clipboard, document contents, environment variables, and secrets are never captured.").foregroundStyle(ObsidianTokens.secondaryText); TextField("Scene name", text: $name).textFieldStyle(.roundedBorder); List(model.capturableApplications) { item in Toggle(isOn: Binding(get: { selectedBundleIDs.contains(item.id) }, set: { if $0 { selectedBundleIDs.insert(item.id) } else { selectedBundleIDs.remove(item.id) } })) { VStack(alignment: .leading) { Text(item.displayName); Text(item.id).font(.caption.monospaced()).foregroundStyle(ObsidianTokens.mutedText) } }.listRowBackground(ObsidianTokens.panel) }.scrollContentBackground(.hidden); HStack { Button("Refresh Applications") { model.refreshCapturableApplications() }; Button("Capture Reviewed Windows") { Task { await model.capture(bundleIdentifiers: selectedBundleIDs) } }.disabled(selectedBundleIDs.isEmpty); Text("\(model.capturedWindows.count) windows in review").foregroundStyle(ObsidianTokens.secondaryText); Spacer(); Button("Save Reviewed Scene") { Task { await model.sceneFromCapture(name: name) } }.buttonStyle(.borderedProminent).disabled(model.capturedWindows.isEmpty) } }.padding(28).task { model.refreshCapturableApplications() } }
}
