import ActivationKit
import AppKit
import Foundation
import MacAutomation
import SceneCore
import WorkspaceIntegrations

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard, scenes, currentRun, history, capture, integrations, permissions, diagnostics
    var id: String { rawValue }
    var title: String { switch self { case .dashboard: "Dashboard"; case .scenes: "Scene Library"; case .currentRun: "Current Run"; case .history: "Run History"; case .capture: "Capture Workspace"; case .integrations: "Integrations"; case .permissions: "Permissions"; case .diagnostics: "Diagnostics" } }
    var symbol: String { switch self { case .dashboard: "square.grid.2x2"; case .scenes: "rectangle.stack"; case .currentRun: "waveform.path.ecg"; case .history: "clock.arrow.circlepath"; case .capture: "viewfinder"; case .integrations: "puzzlepiece.extension"; case .permissions: "lock.shield"; case .diagnostics: "stethoscope" } }
}

struct ProcessApprovalRequest: Identifiable {
    let id = UUID()
    let scene: SceneCore.Scene
    let actions: [SceneAction]
    let requiresImportTrustReview: Bool
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var scenes: [Scene] = []
    @Published private(set) var currentRun: SceneRunResult?
    @Published private(set) var runHistory: [SceneRunResult] = []
    @Published private(set) var integrations: [IntegrationDescriptor] = []
    @Published private(set) var capturableApplications: [RunningApplicationDescriptor] = []
    @Published private(set) var capturedWindows: [CapturedWindow] = []
    @Published var selectedSection: AppSection = .dashboard
    @Published var presentedError: String?
    @Published private(set) var isLoading = false
    @Published var commandPalettePresented = false
    @Published var overlayPresented = false
    @Published var onboardingPresented = !UserDefaults.standard.bool(forKey: "onboardingCompleted")
    @Published var processApprovalRequest: ProcessApprovalRequest?

    let accessibilityPermission: any AccessibilityPermissionManaging
    let hotKeyController = GlobalHotKeyController()
    private let store: any SceneStoring; private let historyStore: any RunHistoryStoring; private let executor: SceneExecutor
    private let managedProcesses: any ManagedProcessControlling; private let windowController: any WindowLayoutControlling; private let integrationDiscovery: any IntegrationDiscovering
    private let runningApplicationDiscovery: any RunningApplicationDiscovering
    private let approvalStore: any ProcessApprovalAuthorizing
    private var runTask: Task<Void, Never>?

    var isRunning: Bool { currentRun?.status.isActive == true }
    var favoriteScenes: [Scene] { scenes.filter(\.favorite) }
    var recentScenes: [Scene] { let ids = runHistory.map(\.sceneID); return scenes.sorted { (ids.firstIndex(of: $0.id) ?? .max) < (ids.firstIndex(of: $1.id) ?? .max) }.prefix(5).map { $0 } }

    init(store: (any SceneStoring)? = nil, executor: SceneExecutor? = nil, historyStore: (any RunHistoryStoring)? = nil) {
        let fallback = FileManager.default.temporaryDirectory.appendingPathComponent("WorkspaceOrchestrator", isDirectory: true)
        do { self.store = try store ?? JSONSceneStore.applicationSupportStore() } catch { self.store = JSONSceneStore(directoryURL: fallback); presentedError = error.localizedDescription }
        do { self.historyStore = try historyStore ?? JSONRunHistoryStore.applicationSupportStore() } catch { self.historyStore = JSONRunHistoryStore(directoryURL: fallback.appendingPathComponent("RunHistory")); presentedError = error.localizedDescription }
        let managed = ManagedProcessController(); managedProcesses = managed
        let permission = SystemAccessibilityPermissionManager(); accessibilityPermission = permission
        let windows = AXWindowLayoutController(permission: permission); windowController = windows
        integrationDiscovery = NativeIntegrationDiscovery()
        runningApplicationDiscovery = NSWorkspaceRunningApplicationDiscovery()
        let approvals: JSONProcessApprovalStore
        do { approvals = try JSONProcessApprovalStore.applicationSupportStore() }
        catch { approvals = JSONProcessApprovalStore(fileURL: fallback.appendingPathComponent("process-approvals.json")); presentedError = error.localizedDescription }
        approvalStore = approvals
        let runner = FoundationProcessRunner()
        self.executor = executor ?? SceneExecutor(applicationOpener: NSWorkspaceApplicationOpener(), urlOpener: NSWorkspaceURLOpener(), processRunner: runner, fileOpener: NSWorkspaceFileOpener(), managedProcesses: managed, keychain: SystemKeychainStore(), windowController: windows, approvalAuthorizer: approvals, additionalActionExecutor: WorkspaceIntegrationExecutor(processRunner: runner))
        Task { await refresh() }
    }

    func refresh() async { await loadScenes(); await loadHistory(); integrations = await integrationDiscovery.discover(); refreshCapturableApplications() }
    func refreshCapturableApplications() { capturableApplications = runningApplicationDiscovery.discoverCapturableApplications(excludingBundleIdentifier: Bundle.main.bundleIdentifier) }
    func loadScenes() async { isLoading = true; defer { isLoading = false }; do { scenes = try await store.loadScenes() } catch { presentedError = error.localizedDescription } }
    func loadHistory() async { do { runHistory = try await historyStore.loadRuns() } catch { presentedError = error.localizedDescription } }
    func save(_ scene: Scene) async -> Bool { var updated = scene; updated.updatedAt = Date(); do { try SceneValidator.validate(updated); try await store.save(updated); await loadScenes(); return true } catch { presentedError = error.localizedDescription; return false } }
    func delete(_ scene: Scene) async { do { try await store.deleteScene(id: scene.id); await loadScenes() } catch { presentedError = error.localizedDescription } }
    func installDemoScene() async { guard !scenes.contains(where: { $0.name == "Workspace Orchestrator Demo" }) else { presentedError = "The demo scene is already installed."; return }; _ = await save(.demo()) }
    func run(_ scene: Scene) {
        guard !isRunning, processApprovalRequest == nil else { return }
        Task { await prepareToRun(scene) }
    }
    func approvePendingRun(scope: ProcessApprovalScope, trustImportedScene: Bool) async {
        guard let request = processApprovalRequest else { return }
        do {
            for action in request.actions { try await approvalStore.approve(action, scope: scope) }
            var scene = request.scene
            if trustImportedScene {
                scene.trustState = .local
                scene.updatedAt = Date()
                try await store.save(scene)
                await loadScenes()
            }
            processApprovalRequest = nil
            startRun(scene)
        } catch { presentedError = error.localizedDescription }
    }
    func cancelPendingRun() { processApprovalRequest = nil }
    private func prepareToRun(_ scene: Scene) async {
        do {
            var unapproved: [SceneAction] = []
            for action in scene.actions where action.requiresProcessApproval {
                if !(try await approvalStore.isApproved(action)) { unapproved.append(action) }
            }
            if scene.trustState == .importedUntrusted || !unapproved.isEmpty {
                processApprovalRequest = .init(scene: scene, actions: unapproved, requiresImportTrustReview: scene.trustState == .importedUntrusted)
                return
            }
            startRun(scene)
        } catch { presentedError = error.localizedDescription }
    }
    private func startRun(_ scene: Scene) {
        guard !isRunning else { return }; selectedSection = .currentRun; overlayPresented = true
        runTask = Task { [executor] in
            let final = await executor.execute(scene: scene) { [weak self] update in await self?.accept(update) }
            currentRun = final; try? await historyStore.save(final); await loadHistory(); runTask = nil
        }
    }
    func cancelCurrentRun() { runTask?.cancel() }
    func stopManagedResources() async {
        guard let run = currentRun else { return }; for resource in run.resources where resource.kind == "managedProcess" && resource.ownership == .created { try? await managedProcesses.stop(identifier: resource.identifier, graceSeconds: 5) }
    }
    func capture(bundleIdentifiers: Set<String>) async { do { capturedWindows = try await windowController.capture(bundleIdentifiers: bundleIdentifiers) } catch { presentedError = error.localizedDescription } }
    func sceneFromCapture(name: String) async {
        guard !capturedWindows.isEmpty else { return }; let apps = Dictionary(grouping: capturedWindows, by: \.bundleIdentifier).keys.sorted().map { SceneAction.openApplication(.init(bundleIdentifier: $0)) }; let layout = SceneAction.windowLayout(.init(placements: capturedWindows.map(\.placement), configuration: .init(dependencies: apps.map(\.id), failurePolicy: .continueDegraded, idempotencyPolicy: .reapply))); _ = await save(Scene(name: name, description: "Reviewed workspace capture", actions: apps + [layout]))
    }
    func exportScenes(_ selected: [Scene], to url: URL) async { do { try SceneArchiveService.export(selected, appVersion: appVersion).write(to: url, options: .atomic) } catch { presentedError = error.localizedDescription } }
    func importArchive(from url: URL) async -> SceneImportPreview? { do { let preview = try SceneArchiveService.previewImport(Data(contentsOf: url)); for scene in preview.scenes { try await store.save(scene) }; await loadScenes(); return preview } catch { presentedError = error.localizedDescription; return nil } }
    func completeOnboarding() { UserDefaults.standard.set(true, forKey: "onboardingCompleted"); onboardingPresented = false }
    var appVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0-rc.1" }
    var buildNumber: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1" }
    private func accept(_ update: SceneRunResult) { currentRun = update }
}
