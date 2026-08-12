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
    let deactivating: Bool
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var scenes: [Scene] = []
    @Published private(set) var currentRun: SceneRunResult?
    @Published private(set) var runHistory: [SceneRunResult] = []
    @Published private(set) var interruptedRun: SceneRunResult?
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
    @Published private(set) var clapListening = false
    @Published private(set) var voiceListening = false
    @Published var voicePanelPresented = false
    @Published private(set) var voiceTranscript = ""
    @Published private(set) var voiceSuggestedScene: String?
    @Published private(set) var voiceAmbiguousScenes: [String] = []
    @Published private(set) var launchAtLoginStatus: LaunchAtLoginStatus = .disabled
    @Published private(set) var notificationPermissionStatus: PermissionState = .notDetermined

    let accessibilityPermission: any AccessibilityPermissionManaging
    let hotKeyController = GlobalHotKeyController()
    private let voiceRecognizer = OnDeviceVoiceRecognizer()
    private let spokenStatus = SpokenStatusController()
    private let store: any SceneStoring; private let historyStore: any RunHistoryStoring; private let executor: SceneExecutor
    private let managedProcesses: any ManagedProcessControlling; private let windowController: any WindowLayoutControlling; private let integrationDiscovery: any IntegrationDiscovering
    private let runningApplicationDiscovery: any RunningApplicationDiscovering
    private let approvalStore: any ProcessApprovalAuthorizing
    private let launchAtLoginManager: any LaunchAtLoginManaging
    private let notificationManager: any LocalNotificationManaging
    private var runTask: Task<Void, Never>?
    private var clapListener: LocalClapListener?
    private var voiceSessionID: UUID?

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
        launchAtLoginManager = SystemLaunchAtLoginManager()
        notificationManager = SystemLocalNotificationManager()
        let runner = FoundationProcessRunner()
        self.executor = executor ?? SceneExecutor(applicationOpener: NSWorkspaceApplicationOpener(), urlOpener: NSWorkspaceURLOpener(), processRunner: runner, fileOpener: NSWorkspaceFileOpener(), managedProcesses: managed, keychain: SystemKeychainStore(), windowController: windows, approvalAuthorizer: approvals, additionalActionExecutor: WorkspaceIntegrationExecutor(processRunner: runner))
        spokenStatus.enabled = UserDefaults.standard.bool(forKey: "spokenStatusEnabled")
        configureGlobalHotKey()
        Task { await refresh() }
    }

    func refresh() async { await loadScenes(); await loadHistory(); integrations = await integrationDiscovery.discover(); refreshCapturableApplications(); launchAtLoginStatus = launchAtLoginManager.status(); notificationPermissionStatus = await notificationManager.permissionStatus() }
    func refreshCapturableApplications() { capturableApplications = runningApplicationDiscovery.discoverCapturableApplications(excludingBundleIdentifier: Bundle.main.bundleIdentifier) }
    func loadScenes() async { isLoading = true; defer { isLoading = false }; do { scenes = try await store.loadScenes() } catch { presentedError = error.localizedDescription } }
    func loadHistory() async {
        do {
            let loaded = try await historyStore.loadRuns()
            var recovered: [SceneRunResult] = []
            for run in loaded {
                if run.status.isActive, run.id != currentRun?.id {
                    let interrupted = run.interruptedAfterRelaunch()
                    try await historyStore.save(interrupted)
                    recovered.append(interrupted)
                } else { recovered.append(run) }
            }
            runHistory = recovered.sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
            let dismissed = Set(UserDefaults.standard.stringArray(forKey: "dismissedInterruptedRunIDs") ?? [])
            interruptedRun = runHistory.first { $0.status == .interrupted && !dismissed.contains($0.id) }
        } catch { presentedError = error.localizedDescription }
    }
    func save(_ scene: Scene) async -> Bool { var updated = scene; updated.updatedAt = Date(); do { try SceneValidator.validate(updated); try await store.save(updated); await loadScenes(); return true } catch { presentedError = error.localizedDescription; return false } }
    func delete(_ scene: Scene) async { do { try await store.deleteScene(id: scene.id); await loadScenes() } catch { presentedError = error.localizedDescription } }
    func installDemoScene() async { guard !scenes.contains(where: { $0.name == "Workspace Orchestrator Demo" }) else { presentedError = "The demo scene is already installed."; return }; _ = await save(.demo()) }
    func run(_ scene: Scene) {
        guard !isRunning, processApprovalRequest == nil else { return }
        Task { await prepareToRun(scene, deactivating: false) }
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
            startRun(scene, deactivating: request.deactivating)
        } catch { presentedError = error.localizedDescription }
    }
    func cancelPendingRun() { processApprovalRequest = nil }
    private func prepareToRun(_ scene: Scene, deactivating: Bool) async {
        do {
            var unapproved: [SceneAction] = []
            let actions = deactivating ? scene.deactivationActions : scene.actions
            for action in actions where action.requiresProcessApproval {
                if !(try await approvalStore.isApproved(action)) { unapproved.append(action) }
            }
            if scene.trustState == .importedUntrusted || !unapproved.isEmpty {
                processApprovalRequest = .init(scene: scene, actions: unapproved, requiresImportTrustReview: scene.trustState == .importedUntrusted, deactivating: deactivating)
                return
            }
            startRun(scene, deactivating: deactivating)
        } catch { presentedError = error.localizedDescription }
    }
    private func startRun(_ scene: Scene, deactivating: Bool) {
        guard !isRunning else { return }; selectedSection = .currentRun; overlayPresented = true
        runTask = Task { [executor] in
            let final: SceneRunResult
            if deactivating { final = await executor.deactivate(scene: scene) { [weak self] update in await self?.accept(update) } }
            else { final = await executor.execute(scene: scene) { [weak self] update in await self?.accept(update) } }
            currentRun = final; try? await historyStore.save(final); await loadHistory(); runTask = nil
        }
    }
    func cancelCurrentRun() { runTask?.cancel() }
    func stopCurrentScene() {
        if isRunning { cancelCurrentRun(); return }
        guard let run = currentRun, let scene = scenes.first(where: { $0.id == run.sceneID }) else { presentedError = "There is no current scene to stop."; return }
        Task { await prepareToRun(scene, deactivating: true) }
    }
    func stopManagedResources() async {
        guard let run = currentRun else { return }; for resource in run.resources where resource.kind == "managedProcess" && resource.ownership == .created { try? await managedProcesses.stop(identifier: resource.identifier, graceSeconds: 5) }
    }
    func stopInterruptedResources() async {
        guard let run = interruptedRun else { return }
        for resource in run.resources where resource.kind == "managedProcess" && resource.ownership == .created {
            do { try await managedProcesses.stop(identifier: resource.identifier, graceSeconds: 5) }
            catch { presentedError = error.localizedDescription; return }
        }
        dismissInterruptedRun()
    }
    func retryInterruptedRun() {
        guard let interruptedRun, let scene = scenes.first(where: { $0.id == interruptedRun.sceneID }) else { presentedError = "The interrupted run's scene is no longer available."; return }
        dismissInterruptedRun()
        run(scene)
    }
    func dismissInterruptedRun() {
        guard let id = interruptedRun?.id else { return }
        var dismissed = Set(UserDefaults.standard.stringArray(forKey: "dismissedInterruptedRunIDs") ?? [])
        dismissed.insert(id)
        UserDefaults.standard.set(Array(dismissed), forKey: "dismissedInterruptedRunIDs")
        interruptedRun = nil
    }
    func capture(bundleIdentifiers: Set<String>) async { do { capturedWindows = try await windowController.capture(bundleIdentifiers: bundleIdentifiers) } catch { presentedError = error.localizedDescription } }
    func sceneFromCapture(name: String) async {
        guard !capturedWindows.isEmpty else { return }; let apps = Dictionary(grouping: capturedWindows, by: \.bundleIdentifier).keys.sorted().map { SceneAction.openApplication(.init(bundleIdentifier: $0)) }; let layout = SceneAction.windowLayout(.init(placements: capturedWindows.map(\.placement), configuration: .init(dependencies: apps.map(\.id), failurePolicy: .continueDegraded, idempotencyPolicy: .reapply))); _ = await save(Scene(name: name, description: "Reviewed workspace capture", actions: apps + [layout]))
    }
    func exportScenes(_ selected: [Scene], to url: URL) async { do { try SceneArchiveService.export(selected, appVersion: appVersion).write(to: url, options: .atomic) } catch { presentedError = error.localizedDescription } }
    func importArchive(from url: URL) async -> SceneImportPreview? { do { let preview = try SceneArchiveService.previewImport(Data(contentsOf: url)); for scene in preview.scenes { try await store.save(scene) }; await loadScenes(); return preview } catch { presentedError = error.localizedDescription; return nil } }
    func completeOnboarding() { UserDefaults.standard.set(true, forKey: "onboardingCompleted"); onboardingPresented = false }
    var microphonePermissionStatus: ActivationPermissionStatus { LocalClapListener.microphonePermissionStatus }
    var speechPermissionStatus: ActivationPermissionStatus { OnDeviceVoiceRecognizer.speechPermissionStatus }
    func setClapEnabled(_ enabled: Bool) async {
        if !enabled {
            clapListener?.stop(); clapListener = nil; clapListening = false
            UserDefaults.standard.set(false, forKey: "clapEnabled")
            return
        }
        var permitted = microphonePermissionStatus == .granted
        if !permitted { permitted = await LocalClapListener.requestMicrophonePermission() }
        guard permitted else { presentedError = "Microphone permission was not granted. Double-clap detection remains off."; return }
        let configuration = ClapConfiguration(enabled: true)
        let listener = LocalClapListener(configuration: configuration) { [weak self] in self?.commandPalettePresented = true }
        do { try listener.startExplicitly(); clapListener = listener; clapListening = true; UserDefaults.standard.set(true, forKey: "clapEnabled") }
        catch { presentedError = error.localizedDescription; clapListening = false }
    }
    func beginVoiceCommand() async {
        guard !voiceListening else { return }
        var microphoneAllowed = microphonePermissionStatus == .granted
        if !microphoneAllowed { microphoneAllowed = await LocalClapListener.requestMicrophonePermission() }
        guard microphoneAllowed else { presentedError = "Microphone permission is required for an explicit voice command session."; return }
        var speechAllowed = speechPermissionStatus == .granted
        if !speechAllowed { speechAllowed = await OnDeviceVoiceRecognizer.requestAuthorization() }
        guard speechAllowed else { presentedError = "Speech Recognition permission was not granted. No cloud fallback will be used."; return }
        let configuration = VoiceConfiguration(enabled: true)
        let sessionID = UUID(); voiceSessionID = sessionID; voiceListening = true; voicePanelPresented = true; voiceTranscript = ""; voiceSuggestedScene = nil; voiceAmbiguousScenes = []
        do {
            try voiceRecognizer.recognizeOnce(configuration: configuration) { [weak self] transcript, isFinal in
                Task { @MainActor in guard let self, self.voiceSessionID == sessionID else { return }; self.voiceTranscript = transcript; if isFinal { self.finishVoiceCommand(transcript) } }
            } onError: { [weak self] message in Task { @MainActor in self?.voiceListening = false; self?.presentedError = message } }
            Task { [weak self] in try? await Task.sleep(for: .seconds(configuration.timeoutSeconds)); guard let self, self.voiceSessionID == sessionID, self.voiceListening else { return }; self.finishVoiceCommand(self.voiceTranscript) }
        } catch { voiceListening = false; presentedError = error.localizedDescription }
    }
    func cancelVoiceCommand() { voiceRecognizer.stop(); voiceSessionID = nil; voiceListening = false; voicePanelPresented = false }
    func confirmVoiceScene(named name: String) { voiceRecognizer.stop(); voiceSessionID = nil; voiceListening = false; voicePanelPresented = false; if let scene = scenes.first(where: { $0.name == name }) { run(scene) } }
    func setSpokenStatusEnabled(_ enabled: Bool) { spokenStatus.enabled = enabled; UserDefaults.standard.set(enabled, forKey: "spokenStatusEnabled") }
    func setLaunchAtLogin(_ enabled: Bool) {
        do { try launchAtLoginManager.setEnabled(enabled); launchAtLoginStatus = launchAtLoginManager.status() }
        catch { presentedError = error.localizedDescription; launchAtLoginStatus = launchAtLoginManager.status() }
    }
    func setNotificationsEnabled(_ enabled: Bool) async {
        if !enabled { UserDefaults.standard.set(false, forKey: "notificationsEnabled"); return }
        do {
            var allowed = notificationPermissionStatus == .granted
            if !allowed { allowed = try await notificationManager.requestPermission() }
            notificationPermissionStatus = await notificationManager.permissionStatus()
            UserDefaults.standard.set(allowed, forKey: "notificationsEnabled")
            if !allowed { presentedError = "Notification permission was not granted." }
        } catch { presentedError = error.localizedDescription }
    }
    var appVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0-rc.1" }
    var buildNumber: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1" }
    private func accept(_ update: SceneRunResult) async {
        let previousStatus = currentRun?.status
        currentRun = update
        do { try await historyStore.save(update) }
        catch { presentedError = error.localizedDescription }
        if previousStatus != update.status { spokenStatus.speak(sceneName: update.sceneName, status: update.status, warningCount: update.warningCount, failedAction: update.failedActionID.flatMap { id in update.actionRecords.first(where: { $0.id == id })?.name }) }
        if previousStatus != update.status, UserDefaults.standard.bool(forKey: "notificationsEnabled"), [.ready, .readyWithWarnings, .failed].contains(update.status) {
            do { try await notificationManager.notify(run: update) }
            catch { presentedError = error.localizedDescription }
        }
    }
    private func configureGlobalHotKey() {
        do { try hotKeyController.register(.init()) { [weak self] in self?.commandPalettePresented = true } }
        catch { presentedError = error.localizedDescription }
    }
    private func finishVoiceCommand(_ transcript: String) {
        voiceRecognizer.stop(); voiceSessionID = nil; voiceListening = false
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { presentedError = "No voice command was recognized."; return }
        switch VoiceCommandParser.parse(transcript) {
        case .runScene(let query):
            switch VoiceCommandParser.match(sceneQuery: query, sceneNames: scenes.map(\.name)) {
            case .exact(let name): confirmVoiceScene(named: name)
            case .suggested(let name, _): voiceSuggestedScene = name
            case .ambiguous(let names): voiceAmbiguousScenes = names
            case .none: presentedError = "No scene matched “\(query)”."
            }
        case .stopCurrent: voicePanelPresented = false; stopCurrentScene()
        case .cancelCurrent: voicePanelPresented = false; cancelCurrentRun()
        case .showDashboard: voicePanelPresented = false; selectedSection = .dashboard
        case .showScenes: voicePanelPresented = false; selectedSection = .scenes
        case .showHistory: voicePanelPresented = false; selectedSection = .history
        case .unknown: presentedError = "The voice command was not recognized."
        }
    }
}
