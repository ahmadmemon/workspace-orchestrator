import ActivationKit
import AppKit
import MacAutomation
import SceneCore
import SwiftUI
import UniformTypeIdentifiers

struct RunHistoryView: View {
    @ObservedObject var model: AppModel
    @AppStorage("compactRows") private var compactRows = false
    @State private var query = ""
    @State private var selectedSceneID: String?
    @State private var selectedStatus: SceneRunStatus?
    @State private var datePreset: RunHistoryDatePreset = .all
    @State private var customStart = Date()
    @State private var customEnd = Date()
    @State private var selectedRun: SceneRunResult?
    @State private var retryPreview: HistoricalRunPreview?
    @State private var confirmsClear = false
    @State private var confirmsDeleteFiltered = false
    @State private var exporting = false
    @State private var exportDocument: RunDiagnosticDocument?

    private var filter: RunHistoryFilter { .init(query: query, sceneID: selectedSceneID, status: selectedStatus, datePreset: datePreset, customStart: customStart, customEnd: customEnd) }
    private var runs: [SceneRunResult] { RunHistoryFiltering.filter(model.runHistory, using: filter) }
    private var historicalScenes: [(id: String, name: String)] {
        Dictionary(grouping: model.runHistory, by: \.sceneID).compactMap { id, runs in runs.first.map { (id, $0.sceneName) } }.sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Run History").font(.largeTitle.bold())
                    Text("Local, bounded, and redacted execution records").foregroundStyle(ObsidianTokens.secondaryText)
                }
                Spacer()
                Button("Prune Now") { Task { await model.pruneRunHistory() } }
                Button("Clear All", role: .destructive) { confirmsClear = true }.disabled(model.runHistory.isEmpty)
            }
            HStack {
                TextField("Search scenes", text: $query).textFieldStyle(.roundedBorder).accessibilityLabel("Search run history")
                Picker("Scene", selection: $selectedSceneID) {
                    Text("All scenes").tag(String?.none)
                    ForEach(historicalScenes, id: \.id) { Text($0.name).tag(Optional($0.id)) }
                }.frame(width: 210)
                Picker("Status", selection: $selectedStatus) {
                    Text("All statuses").tag(SceneRunStatus?.none)
                    ForEach(SceneRunStatus.allCases, id: \.self) { Text($0.displayName).tag(Optional($0)) }
                }.frame(width: 210)
                Picker("Date", selection: $datePreset) {
                    ForEach(RunHistoryDatePreset.allCases, id: \.self) { Text($0.label).tag($0) }
                }.frame(width: 150).accessibilityIdentifier("history.datePreset")
            }
            if datePreset == .custom {
                HStack { DatePicker("From", selection: $customStart, displayedComponents: .date); DatePicker("Through", selection: $customEnd, displayedComponents: .date); Spacer() }
            }
            if !model.corruptHistoryFiles.isEmpty {
                Label("\(model.corruptHistoryFiles.count) corrupt history file(s) were preserved for recovery: \(model.corruptHistoryFiles.joined(separator: ", "))", systemImage: "exclamationmark.shield")
                    .font(.callout).foregroundStyle(ObsidianTokens.warning).textSelection(.enabled)
            }
            if runs.isEmpty {
                ContentUnavailableView("No Matching Runs", systemImage: "clock.arrow.circlepath", description: Text("Adjust the search, scene, status, or local-calendar date filter."))
            } else {
                List(runs) { run in
                    Button { selectedRun = run } label: {
                        HStack {
                            WorkspaceCoreView(status: run.status, progress: run.actionRecords.isEmpty ? 0 : Double(run.completedActionCount) / Double(run.actionRecords.count), compact: true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(run.sceneName).font(.headline).foregroundStyle(ObsidianTokens.primaryText)
                                Text(run.startedAt?.formatted() ?? "Unknown start").font(.caption).foregroundStyle(ObsidianTokens.mutedText)
                                Text("\(run.completedActionCount) actions • \(run.warningCount) warnings • \(run.failureCount) failures").font(.caption.monospaced()).foregroundStyle(ObsidianTokens.secondaryText)
                            }
                            Spacer()
                            StatusBadge(text: run.status.displayName, color: run.status.color, symbol: run.status.symbol)
                            Image(systemName: "chevron.right").foregroundStyle(ObsidianTokens.mutedText)
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain).padding(.vertical, compactRows ? 1 : 6).listRowBackground(ObsidianTokens.panel)
                        .accessibilityIdentifier("history.run.\(run.id)")
                        .contextMenu { Button("Delete Run", role: .destructive) { Task { await model.deleteRun(run) } } }
                }.scrollContentBackground(.hidden)
            }
            HStack {
                Text("\(runs.count) filtered of \(model.runHistory.count) • \(ByteCountFormatter.string(fromByteCount: model.historyStorageBytes, countStyle: .file)) on disk").font(.caption.monospaced()).foregroundStyle(ObsidianTokens.mutedText)
                Spacer()
                Button("Delete Filtered…", role: .destructive) { confirmsDeleteFiltered = true }.disabled(runs.isEmpty)
            }
        }
        .padding(28)
        .accessibilityIdentifier("screen.history")
        .sheet(item: $selectedRun) { run in
            HistoricalRunDetailView(run: run, model: model, retry: { scope in
                Task { if let preview = await model.historicalRetryPreview(for: run, scope: scope) { retryPreview = preview } }
            }, export: {
                exportDocument = .init(text: RunDiagnosticExport.text(for: run)); exporting = true
            }).frame(minWidth: 820, minHeight: 680)
        }
        .sheet(item: $retryPreview) { preview in HistoricalRetryPreviewView(preview: preview, model: model) }
        .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .plainText, defaultFilename: "Workspace-Orchestrator-Run-Diagnostic.txt") { result in
            if case .failure(let error) = result { model.presentedError = error.localizedDescription }
            exportDocument = nil
        }
        .confirmationDialog("Clear all valid run history?", isPresented: $confirmsClear, titleVisibility: .visible) {
            Button("Clear Valid History", role: .destructive) { Task { await model.clearRunHistory() } }
        } message: { Text("Scene definitions are not affected. Corrupt entries are preserved rather than silently destroyed.") }
        .confirmationDialog("Delete \(runs.count) filtered run(s)?", isPresented: $confirmsDeleteFiltered, titleVisibility: .visible) {
            Button("Delete Filtered Runs", role: .destructive) { let selected = runs; Task { await model.deleteRuns(selected) } }
        } message: { Text("Only the runs visible under the current filters will be removed.") }
    }
}

private extension RunHistoryDatePreset {
    var label: String { switch self { case .all: "All dates"; case .today: "Today"; case .last7Days: "Last 7 days"; case .last30Days: "Last 30 days"; case .custom: "Custom" } }
}

private struct HistoricalRunDetailView: View {
    let run: SceneRunResult
    @ObservedObject var model: AppModel
    let retry: (HistoricalRetryScope) -> Void
    let export: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) { Text(run.sceneName).font(.title.bold()); Text("Historical snapshot • \(run.id)").font(.caption.monospaced()).foregroundStyle(ObsidianTokens.mutedText) }
                Spacer()
                Menu("Retry") { Button("Retry Full Snapshot") { retry(.fullSnapshot); dismiss() }; Button("Retry Failed Actions + Dependents") { retry(.failedAndDependents); dismiss() }.disabled(run.failureCount == 0) }.accessibilityIdentifier("history.retryMenu")
                Button("Open Snapshot as New Scene") { Task { await model.saveHistoricalSceneCopy(from: run); dismiss() } }.disabled(run.sceneSnapshot == nil)
                Button("Export Diagnostic") { export() }.accessibilityIdentifier("history.exportDiagnostic")
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding()
            Divider()
            RunDetailView(run: run, cancel: {})
        }.accessibilityIdentifier("history.runDetail")
    }
}

private struct HistoricalRetryPreviewView: View {
    let preview: HistoricalRunPreview
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Historical Retry Preview").font(.largeTitle.bold())
            Text(preview.plan.scope == .fullSnapshot ? "Full historical snapshot" : "Failed actions and their dependents").foregroundStyle(ObsidianTokens.secondaryText)
            Text("The following actions will execute in this exact order:").font(.headline)
            List(Array(preview.plan.scene.actions.enumerated()), id: \.element.id) { index, action in
                HStack { Text("\(index + 1)").font(.caption.monospaced()).frame(width: 24); VStack(alignment: .leading) { Text(action.displayName).font(.headline); Text(action.id).font(.caption.monospaced()).foregroundStyle(ObsidianTokens.mutedText) }; Spacer(); if action.requiresProcessApproval { Label("Approval checked", systemImage: "checkmark.shield") } }.padding(.vertical, 4)
            }.frame(minHeight: 220)
            if !preview.blockingIssues.isEmpty {
                VStack(alignment: .leading, spacing: 6) { Label("Resolve before retrying", systemImage: "xmark.octagon.fill").font(.headline).foregroundStyle(ObsidianTokens.failure); ForEach(preview.blockingIssues, id: \.self) { Text("• \($0)") } }.obsidianPanel()
            }
            if !preview.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 6) { Label("Current preflight", systemImage: "exclamationmark.triangle.fill").font(.headline).foregroundStyle(ObsidianTokens.warning); ForEach(preview.warnings, id: \.self) { Text("• \($0)") } }.obsidianPanel()
            }
            HStack { Spacer(); Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction); Button("Run Reviewed Snapshot") { model.runHistoricalPreview(preview); dismiss() }.buttonStyle(.borderedProminent).disabled(!preview.blockingIssues.isEmpty || model.isRunning) }
        }.padding(24).frame(minWidth: 760, minHeight: 600).accessibilityIdentifier("history.retryPreview")
    }
}

private struct RunDiagnosticDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws { text = configuration.file.regularFileContents.map { String(decoding: $0, as: UTF8.self) } ?? "" }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { .init(regularFileWithContents: Data(text.utf8)) }
}

struct IntegrationsView: View {
    @ObservedObject var model: AppModel
    var body: some View { VStack(alignment: .leading, spacing: 16) { Text("Integrations").font(.largeTitle.bold()); Text("Detected locally—no inventory leaves this Mac.").foregroundStyle(ObsidianTokens.secondaryText); List(model.integrations) { integration in HStack { Image(systemName: integration.installed ? "checkmark.circle.fill" : "circle.dashed").foregroundStyle(integration.installed ? ObsidianTokens.success : ObsidianTokens.mutedText); VStack(alignment: .leading, spacing: 3) { Text(integration.displayName).font(.headline); Text(integration.path ?? "Not found in a supported location").font(.caption.monospaced()).foregroundStyle(ObsidianTokens.secondaryText); Text(integration.privacyNote).font(.caption).foregroundStyle(ObsidianTokens.mutedText) }; Spacer(); if let version = integration.version { Text(version).font(.caption.monospaced()) }; StatusBadge(text: integration.installed ? "Installed" : "Missing", color: integration.installed ? ObsidianTokens.success : ObsidianTokens.warning, symbol: integration.installed ? "checkmark" : "questionmark") }.padding(.vertical, 7).listRowBackground(ObsidianTokens.panel) }.scrollContentBackground(.hidden) }.padding(28).accessibilityIdentifier("screen.integrations") }
}

struct PermissionsView: View {
    @ObservedObject var model: AppModel
    var body: some View { VStack(alignment: .leading, spacing: 18) { Text("Permissions").font(.largeTitle.bold()); Text("Optional capabilities ask only when you enable or use them.").foregroundStyle(ObsidianTokens.secondaryText); PermissionRow(title: "Accessibility", detail: "Reviewed window capture and layout restoration only", state: model.accessibilityPermission.status(), request: { _ = model.accessibilityPermission.requestExplicitly() }, settings: { Task { await model.accessibilityPermission.openSystemSettings() } }); PermissionRow(title: "Microphone", detail: "Opt-in local clap detection and explicit voice command sessions", state: permissionState(model.microphonePermissionStatus), request: { Task { await model.setClapEnabled(true) } }, settings: { openPrivacySettings("Privacy_Microphone") }); PermissionRow(title: "Speech Recognition", detail: "On-device voice recognition only; no cloud fallback", state: permissionState(model.speechPermissionStatus), request: { Task { await model.beginVoiceCommand() } }, settings: { openPrivacySettings("Privacy_SpeechRecognition") }); PermissionRow(title: "Notifications", detail: "Optional ready, warning, and failure notifications", state: model.notificationPermissionStatus, request: { Task { await model.setNotificationsEnabled(true) } }, settings: { openPrivacySettings("Notifications") }); Spacer() }.padding(28).accessibilityIdentifier("screen.permissions") }
    private func permissionState(_ state: ActivationPermissionStatus) -> PermissionState { switch state { case .notDetermined: .notDetermined; case .denied: .denied; case .granted: .granted; case .restricted: .unavailable } }
    private func openPrivacySettings(_ pane: String) { if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") { NSWorkspace.shared.open(url) } }
}
private struct PermissionRow: View { let title: String; let detail: String; let state: PermissionState; let request: (() -> Void)?; let settings: (() -> Void)?; var body: some View { HStack { Image(systemName: state == .granted ? "checkmark.shield.fill" : "shield.lefthalf.filled").font(.title2).foregroundStyle(state == .granted ? ObsidianTokens.success : ObsidianTokens.warning); VStack(alignment: .leading) { Text(title).font(.headline); Text(detail).foregroundStyle(ObsidianTokens.secondaryText) }; Spacer(); Text(state.rawValue.capitalized).font(.caption.monospaced()); if let request { Button("Request", action: request) }; if let settings { Button("Settings", action: settings) } }.obsidianPanel() } }

struct DiagnosticsView: View {
    @ObservedObject var model: AppModel
    @State private var copied = false
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 16) { HStack { Text("Diagnostics").font(.largeTitle.bold()); Spacer(); Button(copied ? "Copied" : "Copy Summary") { model.copyDiagnostics(); copied = true }.accessibilityHint("Copies a bounded summary without scene content or process output") }; Group { LabeledContent("App version", value: model.appVersion); LabeledContent("Build", value: model.buildNumber); LabeledContent("macOS", value: ProcessInfo.processInfo.operatingSystemVersionString); LabeledContent("Architecture", value: architecture); LabeledContent("Scenes", value: "\(model.scenes.count)"); LabeledContent("Run history", value: "\(model.runHistory.count)"); LabeledContent("Accessibility", value: model.accessibilityPermission.status().rawValue); LabeledContent("Microphone", value: model.microphonePermissionStatus.rawValue); LabeledContent("Speech", value: model.speechPermissionStatus.rawValue); LabeledContent("Notifications", value: model.notificationPermissionStatus.rawValue); LabeledContent("Launch at login", value: model.launchAtLoginStatus.rawValue); LabeledContent("Scene storage", value: "~/Library/Application Support/WorkspaceOrchestrator/scenes.json"); LabeledContent("Run history storage", value: "~/Library/Application Support/WorkspaceOrchestrator/RunHistory") }.obsidianPanel(); HStack { Button("Refresh Self-Check") { Task { await model.refresh() } }; Text("Self-check reports actual discovery and permission state; it does not contact a support service.").foregroundStyle(ObsidianTokens.secondaryText) }; Text("Copied diagnostics omit scene definitions and output. Other diagnostic exports may still contain private data; review before sharing.").font(.callout).foregroundStyle(ObsidianTokens.warning) }.padding(28) }.accessibilityIdentifier("screen.diagnostics") }
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
    @State private var manualURLs = ""
    private var urls: [String] { manualURLs.split(whereSeparator: \.isNewline).map(String.init) }
    var body: some View { VStack(alignment: .leading, spacing: 16) { Text("Capture Current Workspace").font(.largeTitle.bold()); Text("Select applications and optionally add reviewed URLs. Window details require Accessibility. Browser/terminal history, clipboard, document contents, environment variables, Docker projects, and secrets are never inferred.").foregroundStyle(ObsidianTokens.secondaryText); HStack { TextField("Scene name", text: $name).textFieldStyle(.roundedBorder); TextField("HTTP(S) URLs, one per line", text: $manualURLs, axis: .vertical).lineLimit(1...3).textFieldStyle(.roundedBorder) }; List(model.capturableApplications) { item in Toggle(isOn: Binding(get: { selectedBundleIDs.contains(item.id) }, set: { if $0 { selectedBundleIDs.insert(item.id) } else { selectedBundleIDs.remove(item.id) }; model.selectCaptureApplications(selectedBundleIDs) })) { VStack(alignment: .leading) { Text(item.displayName); Text(item.id).font(.caption.monospaced()).foregroundStyle(ObsidianTokens.mutedText) } }.listRowBackground(ObsidianTokens.panel) }.scrollContentBackground(.hidden); HStack { Button("Refresh Applications") { model.refreshCapturableApplications() }; Button("Review Window Capture") { Task { await model.capture(bundleIdentifiers: selectedBundleIDs) } }.disabled(selectedBundleIDs.isEmpty); Text("\(selectedBundleIDs.count) apps • \(model.capturedWindows.count) reviewed windows • \(urls.count) URLs").foregroundStyle(ObsidianTokens.secondaryText); Spacer(); Button("Save Reviewed Scene") { model.selectCaptureApplications(selectedBundleIDs); Task { await model.sceneFromCapture(name: name, manualURLs: urls) } }.buttonStyle(.borderedProminent).disabled(selectedBundleIDs.isEmpty && urls.isEmpty) } }.padding(28).task { model.refreshCapturableApplications() } }
}
