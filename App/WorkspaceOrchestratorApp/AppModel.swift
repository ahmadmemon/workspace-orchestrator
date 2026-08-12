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

enum ImportDuplicatePolicy: String, CaseIterable { case replaceExisting, createCopy, skipExisting }
struct ImportReviewRequest: Identifiable { let id = UUID(); let preview: SceneImportPreview; let sourceURL: URL }

struct HistoricalRunPreview: Identifiable {
    let id = UUID()
    let plan: HistoricalRetryPlan
    let warnings: [String]
    let blockingIssues: [String]
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var scenes: [Scene] = []
    @Published private(set) var currentRun: SceneRunResult?
    @Published private(set) var runHistory: [SceneRunResult] = []
    @Published private(set) var historyStorageBytes: Int64 = 0
    @Published private(set) var corruptHistoryFiles: [String] = []
    @Published private(set) var interruptedRun: SceneRunResult?
    @Published private(set) var integrations: [IntegrationDescriptor] = []
    @Published private(set) var capturableApplications: [RunningApplicationDescriptor] = []
    @Published private(set) var capturedBundleIdentifiers = Set<String>()
    @Published private(set) var capturedWindows: [CapturedWindow] = []
    @Published var selectedSection: AppSection = .dashboard
    @Published var presentedError: String?
    @Published private(set) var isLoading = false
    @Published var commandPalettePresented = false
    @Published var overlayPresented = false
    @Published var onboardingPresented = !UserDefaults.standard.bool(forKey: "onboardingCompleted")
    @Published var processApprovalRequest: ProcessApprovalRequest?
    @Published var importReviewRequest: ImportReviewRequest?
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
    private let keychainStore: any KeychainStoring
    private let launchAtLoginManager: any LaunchAtLoginManaging
    private let notificationManager: any LocalNotificationManaging
    private let uiTesting: Bool
    private var runTask: Task<Void, Never>?
    private var clapListener: LocalClapListener?
    private var voiceSessionID: UUID?

    var isRunning: Bool { currentRun?.status.isActive == true }
    var favoriteScenes: [Scene] { scenes.filter(\.favorite) }
    var recentScenes: [Scene] { let ids = runHistory.map(\.sceneID); return scenes.sorted { (ids.firstIndex(of: $0.id) ?? .max) < (ids.firstIndex(of: $1.id) ?? .max) }.prefix(5).map { $0 } }

    init(store: (any SceneStoring)? = nil, executor: SceneExecutor? = nil, historyStore: (any RunHistoryStoring)? = nil, keychain: (any KeychainStoring)? = nil) {
        let arguments = ProcessInfo.processInfo.arguments
        let uiTesting = arguments.contains("--ui-testing")
        self.uiTesting = uiTesting
        let fallback = FileManager.default.temporaryDirectory.appendingPathComponent("WorkspaceOrchestrator-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)
        if uiTesting { self.store = store ?? JSONSceneStore(directoryURL: fallback); self.historyStore = historyStore ?? JSONRunHistoryStore(directoryURL: fallback.appendingPathComponent("RunHistory")); onboardingPresented = arguments.contains("--reset-onboarding") }
        else {
            do { self.store = try store ?? JSONSceneStore.applicationSupportStore() } catch { self.store = JSONSceneStore(directoryURL: fallback); presentedError = error.localizedDescription }
            do { self.historyStore = try historyStore ?? JSONRunHistoryStore.applicationSupportStore() } catch { self.historyStore = JSONRunHistoryStore(directoryURL: fallback.appendingPathComponent("RunHistory")); presentedError = error.localizedDescription }
        }
        if uiTesting {
            let managed = UITestManagedProcessController(); managedProcesses = managed
            let permission = UITestAccessibilityPermissionManager(); accessibilityPermission = permission
            let windows = UITestWindowLayoutController(); windowController = windows
            integrationDiscovery = UITestIntegrationDiscovery()
            runningApplicationDiscovery = UITestRunningApplicationDiscovery()
            let approvals = UITestProcessApprovalAuthorizer(); approvalStore = approvals
            let secrets = keychain ?? UITestKeychainStore(); keychainStore = secrets
            launchAtLoginManager = UITestLaunchAtLoginManager()
            notificationManager = UITestNotificationManager()
            let runner = UITestProcessRunner()
            self.executor = executor ?? SceneExecutor(applicationOpener: UITestApplicationOpener(), urlOpener: UITestURLOpener(), processRunner: runner, fileOpener: UITestFileOpener(), managedProcesses: managed, keychain: secrets, windowController: windows, approvalAuthorizer: approvals)
        } else {
            let managed = ManagedProcessController(); managedProcesses = managed
            let permission = SystemAccessibilityPermissionManager(); accessibilityPermission = permission
            let windows = AXWindowLayoutController(permission: permission); windowController = windows
            integrationDiscovery = NativeIntegrationDiscovery()
            runningApplicationDiscovery = NSWorkspaceRunningApplicationDiscovery()
            let approvals: JSONProcessApprovalStore
            do { approvals = try JSONProcessApprovalStore.applicationSupportStore() }
            catch { approvals = JSONProcessApprovalStore(fileURL: fallback.appendingPathComponent("process-approvals.json")); presentedError = error.localizedDescription }
            approvalStore = approvals
            let secrets = keychain ?? SystemKeychainStore(); keychainStore = secrets
            launchAtLoginManager = SystemLaunchAtLoginManager()
            notificationManager = SystemLocalNotificationManager()
            let runner = FoundationProcessRunner()
            self.executor = executor ?? SceneExecutor(applicationOpener: NSWorkspaceApplicationOpener(), urlOpener: NSWorkspaceURLOpener(), processRunner: runner, fileOpener: NSWorkspaceFileOpener(), managedProcesses: managed, keychain: secrets, windowController: windows, approvalAuthorizer: approvals, additionalActionExecutor: WorkspaceIntegrationExecutor(processRunner: runner), additionalHealthChecker: DockerIntegrationHealthChecker(processRunner: runner))
        }
        spokenStatus.enabled = UserDefaults.standard.bool(forKey: "spokenStatusEnabled")
        if !uiTesting { configureGlobalHotKey() }
        Task { await refresh() }
    }

    func refresh() async { if uiTesting, ProcessInfo.processInfo.arguments.contains("--seed-ui-fixtures") { await seedUITestFixtures() }; await loadScenes(); await loadHistory(); integrations = await integrationDiscovery.discover(); refreshCapturableApplications(); launchAtLoginStatus = launchAtLoginManager.status(); notificationPermissionStatus = await notificationManager.permissionStatus() }
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
            corruptHistoryFiles = try await historyStore.corruptFileNames()
            historyStorageBytes = try await historyStore.storageUsageBytes()
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
    func capture(bundleIdentifiers: Set<String>) async {
        capturedBundleIdentifiers = bundleIdentifiers
        do { capturedWindows = try await windowController.capture(bundleIdentifiers: bundleIdentifiers) }
        catch { capturedWindows = []; presentedError = error.localizedDescription }
    }
    func selectCaptureApplications(_ bundleIdentifiers: Set<String>) { capturedBundleIdentifiers = bundleIdentifiers; capturedWindows = capturedWindows.filter { bundleIdentifiers.contains($0.bundleIdentifier) } }
    func sceneFromCapture(name: String, manualURLs: [String] = []) async {
        let bundleIDs = capturedBundleIdentifiers.union(capturedWindows.map(\.bundleIdentifier))
        guard !bundleIDs.isEmpty || !manualURLs.isEmpty else { presentedError = "Select at least one application or add an HTTP(S) URL."; return }
        let apps = bundleIDs.sorted().map { SceneAction.openApplication(.init(bundleIdentifier: $0)) }
        let urls = manualURLs.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.map { SceneAction.openURL(.init(url: $0.trimmingCharacters(in: .whitespacesAndNewlines))) }
        var actions = apps + urls
        if !capturedWindows.isEmpty { actions.append(.windowLayout(.init(placements: capturedWindows.map(\.placement), configuration: .init(dependencies: apps.map(\.id), failurePolicy: .continueDegraded, idempotencyPolicy: .reapply)))) }
        if await save(Scene(name: name, description: "Reviewed workspace capture", actions: actions)) { capturedWindows = []; capturedBundleIdentifiers = [] }
    }
    func exportScenes(_ selected: [Scene], to url: URL) async { do { try SceneArchiveService.export(selected, appVersion: appVersion).write(to: url, options: .atomic) } catch { presentedError = error.localizedDescription } }
    func previewImport(from url: URL) async {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do { importReviewRequest = .init(preview: try SceneArchiveService.previewImport(Data(contentsOf: url)), sourceURL: url) }
        catch { presentedError = error.localizedDescription }
    }
    func confirmImport(duplicatePolicy: ImportDuplicatePolicy) async {
        guard let request = importReviewRequest else { return }
        do {
            for original in request.preview.scenes {
                var scene = original
                let duplicate = scenes.contains { $0.id == scene.id }
                if duplicate {
                    switch duplicatePolicy {
                    case .replaceExisting: break
                    case .createCopy: scene.id = UUID().uuidString; scene.name += " (Imported)"
                    case .skipExisting: continue
                    }
                }
                scene.trustState = .importedUntrusted
                try await store.save(scene)
            }
            importReviewRequest = nil
            await loadScenes()
        } catch { presentedError = error.localizedDescription }
    }
    func cancelImport() { importReviewRequest = nil }
    func completeOnboarding() { UserDefaults.standard.set(true, forKey: "onboardingCompleted"); onboardingPresented = false }
    func resetOnboarding() { UserDefaults.standard.set(false, forKey: "onboardingCompleted"); onboardingPresented = true }
    var microphonePermissionStatus: ActivationPermissionStatus { LocalClapListener.microphonePermissionStatus }
    var speechPermissionStatus: ActivationPermissionStatus { OnDeviceVoiceRecognizer.speechPermissionStatus }
    var voiceActivationPhrase: String { UserDefaults.standard.string(forKey: "voiceActivationPhrase") ?? "Workspace online" }
    func setClapEnabled(_ enabled: Bool) async {
        if !enabled {
            clapListener?.stop(); clapListener = nil; clapListening = false
            UserDefaults.standard.set(false, forKey: "clapEnabled")
            return
        }
        var permitted = microphonePermissionStatus == .granted
        if !permitted { permitted = await LocalClapListener.requestMicrophonePermission() }
        guard permitted else { presentedError = "Microphone permission was not granted. Double-clap detection remains off."; return }
        let sensitivity = UserDefaults.standard.object(forKey: "clapSensitivity") as? Double ?? 0.65
        let configuration = ClapConfiguration(enabled: true, sensitivity: sensitivity)
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
        let locale = UserDefaults.standard.string(forKey: "voiceLocaleIdentifier") ?? Locale.current.identifier
        let phrase = voiceActivationPhrase
        let configuration = VoiceConfiguration(enabled: true, localeIdentifier: locale, activationPhrase: phrase)
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
    func deleteRun(_ run: SceneRunResult) async { do { try await historyStore.delete(id: run.id); await loadHistory() } catch { presentedError = error.localizedDescription } }
    func deleteRuns(_ runs: [SceneRunResult]) async { do { try await historyStore.delete(ids: runs.map(\.id)); await loadHistory() } catch { presentedError = error.localizedDescription } }
    func clearRunHistory() async { do { try await historyStore.clear(); interruptedRun = nil; await loadHistory() } catch { presentedError = error.localizedDescription } }
    func pruneRunHistory() async {
        do {
            let result = try await historyStore.prune(referenceDate: Date())
            await loadHistory()
            if !result.corruptFileNames.isEmpty { presentedError = "Pruning completed. Corrupt files were preserved: \(result.corruptFileNames.joined(separator: ", "))." }
        } catch { presentedError = error.localizedDescription }
    }
    func historicalRetryPreview(for run: SceneRunResult, scope: HistoricalRetryScope) async -> HistoricalRunPreview? {
        do {
            let plan = try HistoricalRunPlanner.retryPlan(for: run, scope: scope)
            try SceneValidator.validate(plan.scene)
            var warnings: [String] = []
            var blocking: [String] = []
            let installed = Set(integrations.filter(\.installed).map(\.id))
            for action in plan.scene.actions {
                switch action {
                case .openFile(let value):
                    if !FileManager.default.fileExists(atPath: value.path) { warnings.append("\(action.displayName): path is currently missing: \(value.path)") }
                case .runProcess(let value):
                    if !FileManager.default.isExecutableFile(atPath: value.executable) { warnings.append("\(action.displayName): executable is not currently available at \(value.executable)") }
                    blocking += await missingSecretIssues(actionName: action.displayName, environment: value.environment)
                case .managedProcess(let value):
                    if !FileManager.default.isExecutableFile(atPath: value.executable) { warnings.append("\(action.displayName): executable is not currently available at \(value.executable)") }
                    blocking += await missingSecretIssues(actionName: action.displayName, environment: value.environment)
                case .windowLayout:
                    if accessibilityPermission.status() != .granted { warnings.append("\(action.displayName): Accessibility permission is not currently granted.") }
                case .dockerCompose:
                    if !installed.contains(.docker) { warnings.append("\(action.displayName): Docker was not detected during the latest integration check.") }
                case .editorWorkspace:
                    if !installed.contains(.visualStudioCode) && !installed.contains(.cursor) && !installed.contains(.vscodium) { warnings.append("\(action.displayName): a supported editor was not detected during the latest integration check.") }
                default: break
                }
            }
            if !plan.assumedSuccessfulDependencyIDs.isEmpty {
                warnings.append("Previously successful dependencies are assumed satisfied and will not execute: \(plan.assumedSuccessfulDependencyIDs.joined(separator: ", ")).")
            }
            warnings.append("Process approvals are checked again against the current executable, arguments, working directory, environment names and references, timeout, retry, and managed-process settings.")
            return .init(plan: plan, warnings: warnings, blockingIssues: blocking)
        } catch { presentedError = error.localizedDescription; return nil }
    }
    func runHistoricalPreview(_ preview: HistoricalRunPreview) {
        guard preview.blockingIssues.isEmpty else { presentedError = preview.blockingIssues.joined(separator: "\n"); return }
        run(preview.plan.scene)
    }
    func saveHistoricalSceneCopy(from run: SceneRunResult) async {
        do {
            let scene = try HistoricalRunPlanner.sceneCopy(from: run)
            if await save(scene) { selectedSection = .scenes }
        } catch { presentedError = error.localizedDescription }
    }
    func updateGlobalHotKey(keyCode: UInt32, modifiers: UInt32, label: String) {
        let configuration = HotKeyConfiguration(keyCode: keyCode, modifiers: modifiers)
        do { try hotKeyController.register(configuration) { [weak self] in self?.commandPalettePresented = true }; UserDefaults.standard.set(Int(keyCode), forKey: "hotKeyCode"); UserDefaults.standard.set(Int(modifiers), forKey: "hotKeyModifiers"); UserDefaults.standard.set(label, forKey: "hotKeyLabel") }
        catch { presentedError = error.localizedDescription }
    }
    var diagnosticsReport: String {
        let installed = integrations.filter(\.installed).map(\.displayName).joined(separator: ", ")
        return """
        Workspace Orchestrator diagnostics
        Version: \(appVersion) (\(buildNumber))
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Scenes: \(scenes.count)
        Run history: \(runHistory.count)
        Current status: \(currentRun?.status.rawValue ?? "idle")
        Accessibility: \(accessibilityPermission.status().rawValue)
        Microphone: \(microphonePermissionStatus.rawValue)
        Speech: \(speechPermissionStatus.rawValue)
        Notifications: \(notificationPermissionStatus.rawValue)
        Launch at login: \(launchAtLoginStatus.rawValue)
        Installed integrations: \(installed.isEmpty ? "none detected" : installed)
        """
    }
    func copyDiagnostics() { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(diagnosticsReport, forType: .string) }
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
        let keyCode = UInt32(UserDefaults.standard.object(forKey: "hotKeyCode") as? Int ?? 49)
        let modifiers = UInt32(UserDefaults.standard.object(forKey: "hotKeyModifiers") as? Int ?? 2_304)
        do { try hotKeyController.register(.init(keyCode: keyCode, modifiers: modifiers)) { [weak self] in self?.commandPalettePresented = true } }
        catch { presentedError = error.localizedDescription }
    }
    private func finishVoiceCommand(_ transcript: String) {
        voiceRecognizer.stop(); voiceSessionID = nil; voiceListening = false
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { presentedError = "No voice command was recognized."; return }
        switch VoiceCommandParser.parse(transcript, activationPhrase: voiceActivationPhrase) {
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

    private func missingSecretIssues(actionName: String, environment: [String: EnvironmentValue]) async -> [String] {
        var issues: [String] = []
        for (name, value) in environment.sorted(by: { $0.key < $1.key }) {
            guard case .secretReference(let reference) = value else { continue }
            do { _ = try await keychainStore.read(id: reference) }
            catch { issues.append("\(actionName): secret reference \(reference) for \(name) is missing from Keychain.") }
        }
        return issues
    }

    private func seedUITestFixtures() async {
        do {
            guard try await store.loadScenes().isEmpty else { return }
            let scene = Scene(id: "ui-seeded-scene", name: "Seeded Workspace", description: "Deterministic local UI fixture", favorite: true, actions: [.wait(.init(id: "ui-wait", durationSeconds: 0.01, message: "Safe fixture"))])
            try await store.save(scene)
            var ready = SceneRunResult(scene: scene, id: "ui-ready-run", appVersion: appVersion)
            ready.status = .ready
            ready.startedAt = Date(timeIntervalSince1970: 1_700_000_000)
            ready.endedAt = Date(timeIntervalSince1970: 1_700_000_001)
            if !ready.actionRecords.isEmpty { ready.actionRecords[0].status = .succeeded; ready.actionRecords[0].startedAt = ready.startedAt; ready.actionRecords[0].endedAt = ready.endedAt }
            try await historyStore.save(ready)
            if let requested = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--ui-run-status=") })?.split(separator: "=", maxSplits: 1).last {
                var fixture = ready
                switch requested {
                case "readyWithWarnings":
                    fixture.status = .readyWithWarnings
                    if !fixture.actionRecords.isEmpty { fixture.actionRecords[0].status = .succeededWithWarning }
                case "failed":
                    fixture.status = .failed
                    fixture.failedActionID = fixture.actionRecords.first?.id
                    fixture.errorCategory = .healthCheck
                    fixture.errorMessage = "Deterministic UI fixture failure."
                    if !fixture.actionRecords.isEmpty { fixture.actionRecords[0].status = .failed; fixture.actionRecords[0].errorCategory = .healthCheck; fixture.actionRecords[0].errorMessage = fixture.errorMessage }
                default: fixture.status = .ready
                }
                currentRun = fixture
            }
        } catch { presentedError = error.localizedDescription }
    }
}

private struct UITestApplicationOpener: ApplicationOpening { func openApplication(bundleIdentifier: String) async throws {} }
private struct UITestURLOpener: URLOpening { func openURL(_ url: URL) async throws {} }
private struct UITestFileOpener: FileOpening { func openFile(at url: URL, applicationBundleIdentifier: String?, revealInFinder: Bool) async throws {} }
private struct UITestProcessRunner: ProcessRunning {
    func run(_ request: ProcessRequest) async throws -> ProcessExecutionResult { let now = Date(); return .init(stdout: "UI test process output", stderr: "", exitCode: 0, startedAt: now, endedAt: now, timedOut: false, cancelled: false) }
}
private actor UITestManagedProcessController: ManagedProcessControlling {
    func start(_ action: ManagedProcessAction, environment: [String: String]) async throws -> ResourceRecord { .init(actionID: action.id, kind: "managedProcess", identifier: action.singleInstanceKey, ownership: .created) }
    func stop(identifier: String, graceSeconds: Double) async throws {}
    func snapshot(identifier: String) async -> ManagedProcessSnapshot? { nil }
}
private struct UITestAccessibilityPermissionManager: AccessibilityPermissionManaging {
    func status() -> PermissionState { .notDetermined }
    func requestExplicitly() -> PermissionState { .notDetermined }
    func openSystemSettings() async {}
}
private struct UITestWindowLayoutController: WindowLayoutControlling {
    func displays() -> [DisplayGeometry] { [.init(id: "ui-display", frame: .init(x: 0, y: 0, width: 1_440, height: 900), visibleFrame: .init(x: 0, y: 0, width: 1_440, height: 860), isMain: true)] }
    func capture(bundleIdentifiers: Set<String>) async throws -> [CapturedWindow] { [] }
    func apply(_ action: WindowLayoutAction) async throws -> WindowRestorationResult { .init(applied: action.placements.map(\.id), unmatched: [], warnings: []) }
}
private struct UITestIntegrationDiscovery: IntegrationDiscovering {
    func discover() async -> [IntegrationDescriptor] { [.init(id: .terminal, displayName: "Terminal", installed: true, version: "UI Test", path: "/Applications/Utilities/Terminal.app", privacyNote: "Deterministic UI fixture."), .init(id: .docker, displayName: "Docker CLI", installed: false, privacyNote: "Deterministic UI fixture.")] }
}
private struct UITestRunningApplicationDiscovery: RunningApplicationDiscovering {
    func discoverCapturableApplications(excludingBundleIdentifier: String?) -> [RunningApplicationDescriptor] { [.init(id: "com.apple.TextEdit", displayName: "TextEdit")] }
}
@MainActor private struct UITestLaunchAtLoginManager: LaunchAtLoginManaging {
    func status() -> LaunchAtLoginStatus { .disabled }
    func setEnabled(_ enabled: Bool) throws {}
}
private struct UITestNotificationManager: LocalNotificationManaging {
    func permissionStatus() async -> PermissionState { .notDetermined }
    func requestPermission() async throws -> Bool { false }
    func notify(run: SceneRunResult) async throws {}
}
private actor UITestProcessApprovalAuthorizer: ProcessApprovalAuthorizing {
    func isApproved(_ action: SceneAction) async throws -> Bool { true }
    func approve(_ action: SceneAction, scope: ProcessApprovalScope) async throws {}
    func consumeApproval(for action: SceneAction) async throws -> Bool { true }
    func revoke(actionID: String) async throws {}
}
private actor UITestKeychainStore: KeychainStoring {
    private var values: [String: Data] = [:]
    func create(id: String, value: Data) async throws { values[id] = value }
    func update(id: String, value: Data) async throws { values[id] = value }
    func read(id: String) async throws -> Data { guard let value = values[id] else { throw KeychainStoreError.notFound }; return value }
    func delete(id: String) async throws { values[id] = nil }
}
