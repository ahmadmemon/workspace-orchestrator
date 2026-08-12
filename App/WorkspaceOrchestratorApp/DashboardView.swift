import AppKit
import SceneCore
import SwiftUI

struct DashboardView: View {
    @ObservedObject var model: AppModel
    @State private var editingScene: SceneCore.Scene?
    @State private var scenePendingDeletion: SceneCore.Scene?
    var body: some View {
        NavigationSplitView {
            List(selection: $model.selectedSection) {
                Section("Command Center") { ForEach(AppSection.allCases) { section in Label(section.title, systemImage: section.symbol).tag(section) } }
                Section("Favorites") { ForEach(model.favoriteScenes) { scene in Button { model.run(scene) } label: { Label(scene.name, systemImage: scene.iconName ?? "bolt") }.buttonStyle(.plain).disabled(model.isRunning) } }
            }.navigationSplitViewColumnWidth(min: 210, ideal: 240).scrollContentBackground(.hidden).background(ObsidianTokens.elevated)
        } detail: {
            Group {
                switch model.selectedSection {
                case .dashboard: CommandCenterDashboard(model: model)
                case .scenes: SceneLibraryView(model: model, editingScene: $editingScene, pendingDeletion: $scenePendingDeletion)
                case .currentRun: if let run = model.currentRun { RunDetailView(run: run, cancel: model.cancelCurrentRun) } else { EmptySection(title: "No Current Run", symbol: "waveform.path.ecg", detail: "Run a scene to see its live execution state.") }
                case .history: RunHistoryView(model: model)
                case .capture: WorkspaceCaptureView(model: model)
                case .integrations: IntegrationsView(model: model)
                case .permissions: PermissionsView(model: model)
                case .diagnostics: DiagnosticsView(model: model)
                }
            }.background(ObsidianTokens.base).foregroundStyle(ObsidianTokens.primaryText)
        }
        .toolbar {
                ToolbarItemGroup { Button { editingScene = SceneCore.Scene(name: "New Scene") } label: { Label("New Scene", systemImage: "plus") }; Button { model.commandPalettePresented = true } label: { Label("Command Palette", systemImage: "command") }.keyboardShortcut(.space, modifiers: [.option, .command]) }
        }
        .sheet(item: $editingScene) { scene in SceneEditorView(scene: scene) { saved in if await model.save(saved) { editingScene = nil } }.frame(minWidth: 820, minHeight: 680) }
        .sheet(isPresented: $model.commandPalettePresented) { CommandPaletteView(model: model).frame(width: 620, height: 460) }
        .sheet(isPresented: $model.onboardingPresented) { OnboardingView(model: model).interactiveDismissDisabled(false).frame(width: 700, height: 560) }
        .sheet(item: $model.processApprovalRequest) { request in ProcessApprovalView(model: model, request: request) }
        .sheet(isPresented: $model.voicePanelPresented) { VoiceCommandView(model: model) }
        .confirmationDialog("Delete this scene?", isPresented: Binding(get: { scenePendingDeletion != nil }, set: { if !$0 { scenePendingDeletion = nil } }), titleVisibility: .visible, presenting: scenePendingDeletion) { scene in Button("Delete “\(scene.name)”", role: .destructive) { Task { await model.delete(scene) } }; Button("Cancel", role: .cancel) {} } message: { _ in Text("The scene definition will be removed. Historical run snapshots remain until their retention date.") }
        .alert("Workspace Orchestrator", isPresented: Binding(get: { model.presentedError != nil }, set: { if !$0 { model.presentedError = nil } })) { Button("OK") { model.presentedError = nil } } message: { Text(model.presentedError ?? "Unknown error") }
        .overlay(alignment: .center) { if model.overlayPresented, let run = model.currentRun { ActivationOverlay(run: run, cancel: model.cancelCurrentRun) { model.overlayPresented = false }.transition(.opacity) } }
        .task { if UserDefaults.standard.object(forKey: "onboardingCompleted") == nil { model.onboardingPresented = true } }
    }
}

private struct CommandCenterDashboard: View {
    @ObservedObject var model: AppModel
    private var run: SceneRunResult? { model.currentRun }
    private var status: SceneRunStatus { run?.status ?? .idle }
    private var progress: Double { guard let run, !run.actionRecords.isEmpty else { return 0 }; return Double(run.completedActionCount) / Double(run.actionRecords.count) }
    var body: some View {
        ScrollView { VStack(spacing: 24) {
            if let interrupted = model.interruptedRun { InterruptedRunBanner(model: model, run: interrupted) }
            HStack(alignment: .center, spacing: 36) {
                WorkspaceCoreView(status: status, progress: progress)
                VStack(alignment: .leading, spacing: 12) {
                    Text("WORKSPACE COMMAND").font(.caption.weight(.bold)).tracking(2).foregroundStyle(ObsidianTokens.cyan)
                    Text(run?.sceneName ?? "Workspace Offline").font(.system(size: 34, weight: .bold, design: .rounded))
                    StatusBadge(text: status.displayName, color: status.color, symbol: status.symbol)
                    if let action = run?.currentAction { Text(action.name).foregroundStyle(ObsidianTokens.secondaryText) }
                    HStack { if model.isRunning { Button("Cancel Run", role: .destructive) { model.cancelCurrentRun() } } else if let scene = model.recentScenes.first { Button("Run \(scene.name)") { model.run(scene) }.buttonStyle(.borderedProminent).tint(ObsidianTokens.activeCyan) } }
                }; Spacer()
            }.obsidianPanel()
            HStack(spacing: 16) { MetricCard(title: "Actions", value: run.map { "\($0.completedActionCount)/\($0.actionRecords.count)" } ?? "—", symbol: "list.bullet.rectangle"); MetricCard(title: "Warnings", value: "\(run?.warningCount ?? 0)", symbol: "exclamationmark.triangle"); MetricCard(title: "Failures", value: "\(run?.failureCount ?? 0)", symbol: "xmark.octagon"); MetricCard(title: "Elapsed", value: run?.duration.map { String(format: "%.1fs", $0) } ?? "—", symbol: "timer") }
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) { Text("Recent Scenes").font(.title3.bold()); if model.recentScenes.isEmpty { Text("Create or install a scene to begin.").foregroundStyle(ObsidianTokens.secondaryText) } else { ForEach(model.recentScenes) { scene in HStack { Image(systemName: scene.iconName ?? "square.grid.2x2").foregroundStyle(ObsidianTokens.cyan); VStack(alignment: .leading) { Text(scene.name).fontWeight(.semibold); Text("\(scene.actions.count) actions").font(.caption).foregroundStyle(ObsidianTokens.mutedText) }; Spacer(); Button("Run") { model.run(scene) }.disabled(model.isRunning) } } } }.obsidianPanel().frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 12) { Text("Recent Runs").font(.title3.bold()); if model.runHistory.isEmpty { Text("Run history is stored locally and redacted.").foregroundStyle(ObsidianTokens.secondaryText) } else { ForEach(model.runHistory.prefix(5)) { run in HStack { Image(systemName: run.status.symbol).foregroundStyle(run.status.color); VStack(alignment: .leading) { Text(run.sceneName); Text(run.status.displayName).font(.caption).foregroundStyle(ObsidianTokens.mutedText) }; Spacer(); Text(run.startedAt?.formatted(date: .omitted, time: .shortened) ?? "") } } } }.obsidianPanel().frame(maxWidth: .infinity)
            }
        }.padding(28) }
    }
}

private struct InterruptedRunBanner: View {
    @ObservedObject var model: AppModel
    let run: SceneRunResult
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "exclamationmark.arrow.triangle.2.circlepath").font(.title2).foregroundStyle(ObsidianTokens.warning).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text("Interrupted workspace detected").font(.headline)
                Text("\(run.sceneName) did not reach a terminal state. Workspace Orchestrator left all resources untouched.").foregroundStyle(ObsidianTokens.secondaryText)
                Text("Only managed resources recorded as created by this run are eligible for Stop Owned Resources.").font(.caption).foregroundStyle(ObsidianTokens.mutedText)
            }
            Spacer()
            Button("Dismiss") { model.dismissInterruptedRun() }
            Button("Stop Owned Resources", role: .destructive) { Task { await model.stopInterruptedResources() } }
                .disabled(!run.resources.contains { $0.kind == "managedProcess" && $0.ownership == .created })
            Button("Retry Scene") { model.retryInterruptedRun() }.buttonStyle(.borderedProminent)
        }
        .obsidianPanel()
        .accessibilityIdentifier("interruptedRunBanner")
    }
}

private struct MetricCard: View { let title: String; let value: String; let symbol: String; var body: some View { VStack(alignment: .leading, spacing: 8) { Image(systemName: symbol).foregroundStyle(ObsidianTokens.cyan); Text(value).font(.title2.monospacedDigit().bold()); Text(title).font(.caption).foregroundStyle(ObsidianTokens.secondaryText) }.frame(maxWidth: .infinity, alignment: .leading).obsidianPanel() } }
private struct EmptySection: View { let title: String; let symbol: String; let detail: String; var body: some View { ContentUnavailableView(title, systemImage: symbol, description: Text(detail)).frame(maxWidth: .infinity, maxHeight: .infinity) } }

private struct SceneLibraryView: View {
    @ObservedObject var model: AppModel; @Binding var editingScene: SceneCore.Scene?; @Binding var pendingDeletion: SceneCore.Scene?
    var body: some View { VStack(alignment: .leading, spacing: 16) { HStack { VStack(alignment: .leading) { Text("Scene Library").font(.largeTitle.bold()); Text("Inspectable, local workspace definitions").foregroundStyle(ObsidianTokens.secondaryText) }; Spacer(); Button("Install Demo") { Task { await model.installDemoScene() } } }; if model.scenes.isEmpty { EmptySection(title: "No Scenes", symbol: "rectangle.stack.badge.plus", detail: "Create a blank scene, capture a workspace, or install the inspectable demo.") } else { List(model.scenes) { scene in HStack { Image(systemName: scene.iconName ?? "square.grid.2x2").font(.title2).foregroundStyle(scene.favorite ? ObsidianTokens.warning : ObsidianTokens.cyan).frame(width: 34); VStack(alignment: .leading, spacing: 4) { HStack { Text(scene.name).font(.headline); if scene.trustState == .importedUntrusted { StatusBadge(text: "Untrusted import", color: ObsidianTokens.warning, symbol: "shield.lefthalf.filled") } }; Text(scene.description ?? "No description").foregroundStyle(ObsidianTokens.secondaryText).lineLimit(2); Text("\(scene.actions.count) start • \(scene.deactivationActions.count) stop • concurrency \(scene.maximumConcurrency)").font(.caption.monospaced()).foregroundStyle(ObsidianTokens.mutedText) }; Spacer(); Button("Run") { model.run(scene) }.buttonStyle(.borderedProminent).disabled(model.isRunning || scene.trustState == .importedUntrusted); Button("Edit") { editingScene = scene }; Button(role: .destructive) { pendingDeletion = scene } label: { Image(systemName: "trash") } }.padding(.vertical, 7).listRowBackground(ObsidianTokens.panel) }.scrollContentBackground(.hidden) } }.padding(28) }
}
