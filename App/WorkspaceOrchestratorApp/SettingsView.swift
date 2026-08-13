import AppKit
import SceneCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @AppStorage("appearanceMode") private var appearanceMode = "Obsidian"
    @AppStorage("notificationsEnabled") private var notifications = false
    @AppStorage("spokenStatusEnabled") private var spokenStatus = false
    @AppStorage("voiceEnabled") private var voiceEnabled = false
    @AppStorage("reduceCustomEffects") private var reduceEffects = false
    @AppStorage("compactRows") private var compactRows = false
    @AppStorage("soundEffectsEnabled") private var soundEffects = false
    @AppStorage("soundEffectsVolume") private var soundVolume = 0.5
    @AppStorage("effectIntensity") private var effectIntensity = 0.65
    @AppStorage("workspaceCoreAnimationIntensity") private var coreAnimationIntensity = 0.65
    @AppStorage("defaultSceneID") private var defaultSceneID = ""
    @AppStorage("menuBarPrimaryAction") private var menuBarPrimaryAction = "openDashboard"
    @AppStorage("menuBarFavoriteLimit") private var menuBarFavoriteLimit = 5
    @AppStorage("menuBarShowRecentScenes") private var menuBarShowRecent = true
    @AppStorage("menuBarShowCurrentRun") private var menuBarShowCurrentRun = true
    @AppStorage("openDashboardAtLaunch") private var openDashboardAtLaunch = true
    @AppStorage("reopenInterruptedRunAtLaunch") private var reopenInterruptedRunAtLaunch = true
    @AppStorage("checkForUpdatesAtLaunch") private var checkForUpdatesAtLaunch = false
    @AppStorage("hotKeySelection") private var hotKeySelection = "optionCommandSpace"
    @AppStorage("hotKeyLabel") private var hotKeyLabel = "⌥⌘Space"
    @AppStorage("globalShortcutTarget") private var globalShortcutTarget = "commandPalette"
    @AppStorage("globalShortcutFavoriteSceneID") private var globalShortcutFavoriteSceneID = ""
    @AppStorage("clapSensitivity") private var clapSensitivity = 0.65
    @AppStorage("clapMinimumInterval") private var clapMinimumInterval = 0.12
    @AppStorage("clapMaximumInterval") private var clapMaximumInterval = 0.65
    @AppStorage("clapAction") private var clapAction = "showCommandPalette"
    @AppStorage("clapRequiresConfirmation") private var clapRequiresConfirmation = true
    @AppStorage("clapCooldown") private var clapCooldown = 2.5
    @AppStorage("clapTestSoundEnabled") private var clapTestSoundEnabled = true
    @AppStorage("voiceLocaleIdentifier") private var voiceLocale = Locale.current.identifier
    @AppStorage("voiceActivationPhrase") private var voicePhrase = "Workspace online"
    @AppStorage("spokenStatusDetailLevel") private var spokenStatusDetailLevel = "concise"
    @AppStorage("voiceMatchConfirmationPolicy") private var voiceMatchConfirmationPolicy = "confirmFuzzyAndAmbiguous"
    @AppStorage("executionDefaultConcurrency") private var defaultConcurrency = 3
    @AppStorage("executionDefaultTimeout") private var defaultTimeout = 0.0
    @AppStorage("executionRetryStrategy") private var retryStrategy = "none"
    @AppStorage("executionRetryAttempts") private var retryAttempts = 2
    @AppStorage("executionRetryDelay") private var retryDelay = 1.0
    @AppStorage("executionFailurePolicy") private var failurePolicy = "stopScene"
    @AppStorage("managedProcessGraceSeconds") private var managedGrace = 5.0
    @AppStorage("managedProcessForcedStopSeconds") private var managedForcedStop = 2.0
    @AppStorage("executionDefaultOutputRetention") private var defaultOutputRetention = "summary"
    @AppStorage("executionDefaultHealthInterval") private var defaultHealthInterval = 1.0
    @AppStorage("executionDefaultHealthAttempts") private var defaultHealthAttempts = 10
    @AppStorage("executionDefaultOwnershipPolicy") private var defaultOwnershipPolicy = "createdOnly"
    @AppStorage("processApprovalBehavior") private var processApprovalBehavior = "rememberExact"
    @AppStorage("advancedDiagnosticLogging") private var advancedDiagnosticLogging = false
    @AppStorage("historyRetentionDays") private var historyDays = 30
    @AppStorage("historyMaximumRunCount") private var historyRunCount = 200
    @AppStorage("historyOutputEnabled") private var historyOutputEnabled = true
    @AppStorage("historyMaximumOutputBytes") private var historyOutputBytes = 32_768

    @State private var newReferenceID = ""
    @State private var newSecret = ""
    @State private var selectedReferenceID = ""
    @State private var replacementSecret = ""
    @State private var renamedReferenceID = ""
    @State private var pendingSecretDeletion: String?
    @State private var importingSettings = false
    @State private var exportingSettings = false
    @State private var settingsDocument: SettingsDocument?
    @State private var confirmsSettingsReset = false
    @State private var confirmsHistoryClear = false
    @State private var confirmsFactoryReset = false
    @State private var factoryResetScope = FactoryResetScope()
    @State private var confirmsWindowLayoutReset = false
    @State private var importingScenes = false
    @State private var exportingScenes = false
    @State private var sceneArchiveDocument: SceneArchiveDocument?
    @State private var calibrationSensitivityDraft = 0.65
    @State private var calibrationMinimumDraft = 0.12
    @State private var calibrationMaximumDraft = 0.65
    @State private var selectedTab = {
        let arguments = ProcessInfo.processInfo.arguments
        for tab in ["general", "appearance", "activation", "execution", "privacy", "permissions", "integrations", "advanced", "about"] where arguments.contains("--ui-settings-\(tab)") { return tab }
        return "general"
    }()

    var body: some View {
        TabView(selection: $selectedTab) {
            generalTab.tabItem { Label("General", systemImage: "gear") }.tag("general")
            appearanceTab.tabItem { Label("Appearance", systemImage: "paintbrush") }.tag("appearance")
            activationTab.tabItem { Label("Activation", systemImage: "waveform") }.tag("activation")
            executionTab.tabItem { Label("Execution", systemImage: "bolt") }.tag("execution")
            privacyTab.tabItem { Label("Privacy", systemImage: "hand.raised") }.tag("privacy")
            permissionsTab.tabItem { Label("Permissions", systemImage: "lock.shield") }.tag("permissions")
            integrationsTab.tabItem { Label("Integrations", systemImage: "puzzlepiece.extension") }.tag("integrations")
            advancedTab.tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }.tag("advanced")
            aboutTab.tabItem { Label("About", systemImage: "info.circle") }.tag("about")
        }
        .frame(width: 760, height: 560)
        .accessibilityIdentifier("screen.settings")
        .fileImporter(isPresented: $importingSettings, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { if case .failure(let error) = result { model.presentedError = error.localizedDescription }; return }
            Task {
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                do { await model.importSettings(try Data(contentsOf: url)) } catch { model.presentedError = error.localizedDescription }
            }
        }
        .fileExporter(isPresented: $exportingSettings, document: settingsDocument, contentType: .json, defaultFilename: "Workspace-Orchestrator-Settings.json") { result in
            if case .failure(let error) = result { model.presentedError = error.localizedDescription }
            settingsDocument = nil
        }
        .fileImporter(isPresented: $importingScenes, allowedContentTypes: [.workspaceOrchestratorArchive, .json], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { if case .failure(let error) = result { model.presentedError = error.localizedDescription }; return }
            Task {
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                await model.previewImport(from: url)
            }
        }
        .fileExporter(isPresented: $exportingScenes, document: sceneArchiveDocument, contentType: .workspaceOrchestratorArchive, defaultFilename: "Workspace-Orchestrator-Scenes.workspaceorchestrator") { result in
            if case .failure(let error) = result { model.presentedError = error.localizedDescription }
            sceneArchiveDocument = nil
        }
        .confirmationDialog("Reset settings to defaults?", isPresented: $confirmsSettingsReset, titleVisibility: .visible) {
            Button("Reset Settings", role: .destructive) { Task { await model.resetSettings() } }
        } message: { Text("Resets General, Appearance, Activation, Execution, and Privacy preferences. Scenes, history, approvals, and Keychain references are retained.") }
        .sheet(isPresented: $confirmsFactoryReset) { FactoryResetView(scope: $factoryResetScope) { scope in Task { await model.factoryReset(scope: scope); confirmsFactoryReset = false } }.frame(width: 560, height: 520) }
        .confirmationDialog("Remove all saved window-layout actions?", isPresented: $confirmsWindowLayoutReset, titleVisibility: .visible) {
            Button("Remove Window Layouts", role: .destructive) { Task { await model.resetWindowLayoutData() } }
        } message: { Text("Removes Window Layout actions from saved scenes and clears the current capture draft. Other actions, scenes, settings, history, approvals, and Keychain secrets remain.") }
        .confirmationDialog("Clear valid run history?", isPresented: $confirmsHistoryClear, titleVisibility: .visible) {
            Button("Clear Valid Run History", role: .destructive) { Task { await model.clearRunHistory() } }
        } message: { Text("Scenes, settings, approvals, Keychain secrets, and corrupt history files are retained.") }
        .confirmationDialog("Delete Keychain reference?", isPresented: Binding(get: { pendingSecretDeletion != nil }, set: { if !$0 { pendingSecretDeletion = nil } }), titleVisibility: .visible, presenting: pendingSecretDeletion) { id in
            Button("Delete \(id)", role: .destructive) { Task { await model.deleteKeychainReference(id: id); pendingSecretDeletion = nil; selectedReferenceID = "" } }
        } message: { id in
            let usages = model.secretReferenceUsages(id: id)
            Text(usages.isEmpty ? "The secret value for \(id) will be deleted from this app's Keychain service. No saved scene references it." : "The secret value for \(id) will be deleted. \(usages.count) scene action reference(s) will become missing: \(usages.map { "\($0.sceneName) › \($0.actionName)" }.joined(separator: ", ")). Scene references are deliberately not rewritten so they can be repaired.")
        }
        .alert("Workspace Orchestrator", isPresented: Binding(get: { model.presentedError != nil }, set: { if !$0 { model.presentedError = nil } })) { Button("OK") { model.presentedError = nil } } message: { Text(model.presentedError ?? "Unknown error") }
        .task { await model.refresh() }
    }

    private var generalTab: some View {
        Form {
            Section("Startup and notifications") {
                Toggle("Launch at login", isOn: Binding(get: { model.launchAtLoginStatus == .enabled }, set: model.setLaunchAtLogin))
                LabeledContent("Launch status", value: model.launchAtLoginStatus.rawValue)
                Toggle("Open Dashboard at launch", isOn: $openDashboardAtLaunch)
                Toggle("Reopen interrupted-run recovery at launch", isOn: $reopenInterruptedRunAtLaunch)
                Toggle("Check official releases for updates at launch", isOn: $checkForUpdatesAtLaunch)
                Toggle("Local notifications", isOn: Binding(get: { notifications }, set: { enabled in notifications = enabled; Task { await model.setNotificationsEnabled(enabled) } }))
                LabeledContent("Notification permission", value: model.notificationPermissionStatus.rawValue)
                LabeledContent("Update status", value: model.updateCheckStatus)
                Button("Check for Updates Now") { Task { await model.checkForUpdates() } }
            }
            Section("Default behavior") {
                Picker("Default scene", selection: $defaultSceneID) { Text("None").tag(""); ForEach(model.scenes) { Text($0.name).tag($0.id) } }
                Picker("Primary menu-bar action", selection: $menuBarPrimaryAction) { Text("Open Dashboard").tag("openDashboard"); Text("Open Command Palette").tag("showCommandPalette"); Text("Run Default Scene").tag("runDefaultScene") }
                if menuBarPrimaryAction == "runDefaultScene", defaultSceneID.isEmpty { Label("Choose a default scene before using this action.", systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                Stepper("Menu-bar favorite limit: \(menuBarFavoriteLimit)", value: $menuBarFavoriteLimit, in: 1...10)
                Toggle("Show recent scenes in menu bar", isOn: $menuBarShowRecent)
                Toggle("Show current run in menu bar", isOn: $menuBarShowCurrentRun)
            }
            Text("Update checks contact only the official GitHub Releases API and never send scene or run data.").foregroundStyle(.secondary)
        }.padding(24)
    }

    private var appearanceTab: some View {
        Form {
            Picker("Theme", selection: $appearanceMode) { Text("Obsidian").tag("Obsidian"); Text("Follow System").tag("System") }
            Slider(value: $effectIntensity, in: 0...1) { Text("Effect intensity") } minimumValueLabel: { Text("None") } maximumValueLabel: { Text("Full") }
            Slider(value: $coreAnimationIntensity, in: 0...1) { Text("Workspace Core animation") } minimumValueLabel: { Text("Still") } maximumValueLabel: { Text("Full") }
            Toggle("Reduce custom glow and motion", isOn: $reduceEffects)
            Toggle("Compact list rows", isOn: $compactRows)
            Toggle("Completion sound effects", isOn: $soundEffects)
            if soundEffects { Slider(value: $soundVolume, in: 0...1) { Text("Interface sound volume") } minimumValueLabel: { Image(systemName: "speaker") } maximumValueLabel: { Image(systemName: "speaker.wave.3") } }
            Button("Reset Appearance Defaults") { model.resetAppearanceSettings() }
            Text("System Reduce Motion, Reduce Transparency, and Increase Contrast are always respected. Completion sounds never include scene or output content.").foregroundStyle(.secondary)
        }.padding(24)
    }

    private var activationTab: some View {
        Form {
            Section("Global shortcut") {
                HotKeyRecorder(label: hotKeyLabel) { keyCode, modifiers, label in hotKeySelection = "custom"; hotKeyLabel = label; model.updateGlobalHotKey(keyCode: keyCode, modifiers: modifiers, label: label) }
                LabeledContent("Registered", value: hotKeyLabel)
                Picker("Shortcut target", selection: $globalShortcutTarget) { Text("Open command palette").tag("commandPalette"); Text("Open scene picker").tag("scenePicker"); Text("Run selected favorite scene").tag("favoriteScene") }
                if globalShortcutTarget == "favoriteScene" { Picker("Favorite scene", selection: $globalShortcutFavoriteSceneID) { Text("Choose…").tag(""); ForEach(model.favoriteScenes) { Text($0.name).tag($0.id) } } }
            }
            Section("Double clap — opt in") {
                Toggle("Enable local double-clap detection", isOn: Binding(get: { model.clapEnabled }, set: { enabled in Task { await model.setClapEnabled(enabled) } }))
                LabeledContent("Detector state", value: model.clapState.displayName).accessibilityIdentifier("settings.clapState")
                Text("Guided calibration analyzes only bounded energy, duration, spectrum, timing, and noise features on this Mac. It never stores or transmits audio.").font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("settings.clapPrivacy")
                HStack {
                    Button("Start Guided Calibration") { Task { await model.beginClapCalibration() } }.disabled(model.clapState.isCalibrating || model.clapState == .testing).accessibilityIdentifier("settings.clapCalibration.start")
                    if model.clapState.isCalibrating { Button("Cancel Calibration") { model.cancelClapCalibration() }.accessibilityIdentifier("settings.clapCalibration.cancel") }
                    Button("Start Nonexecuting Test") { Task { await model.beginClapTest() } }.disabled(model.clapState == .testing || model.clapState.isCalibrating).accessibilityIdentifier("settings.clapTest.start")
                    if model.clapState == .testing { Button("Stop Test") { model.stopClapTest() }.accessibilityIdentifier("settings.clapTest.stop") }
                }
                Slider(value: $clapSensitivity, in: 0.1...1) { Text("Sensitivity") } minimumValueLabel: { Text("Low") } maximumValueLabel: { Text("High") }.onChange(of: clapSensitivity) { _, _ in model.pauseClapForConfigurationChange() }
                LabeledContent("Accepted clap interval", value: String(format: "%.2f–%.2f seconds", clapMinimumInterval, clapMaximumInterval))
                Picker("Action", selection: $clapAction) { Text("Show Command Palette").tag("showCommandPalette"); Text("Run Default Scene").tag("runDefaultScene") }.onChange(of: clapAction) { _, _ in model.pauseClapForConfigurationChange() }
                Toggle("Require confirmation before running a scene", isOn: $clapRequiresConfirmation).disabled(clapAction != "runDefaultScene")
                Stepper("Cooldown: \(clapCooldown, specifier: "%.1f") seconds", value: $clapCooldown, in: 0.5...30, step: 0.5).onChange(of: clapCooldown) { _, _ in model.pauseClapForConfigurationChange() }
                Toggle("Audible confirmation in test mode", isOn: $clapTestSoundEnabled)
                HStack {
                    Button("Pause Listening") { model.pauseClapListeningManually() }.disabled(!model.clapListening)
                    Button("Resume Listening") { Task { await model.resumeClapListening() } }.disabled(!model.clapEnabled || model.clapListening || model.clapState.isCalibrating || model.clapState == .testing)
                    Button("Reset Calibration") { model.resetClapCalibration() }
                }
                if let result = model.clapCalibrationResult {
                    LabeledContent("Calibration confidence", value: "\(Int(result.confidence * 100))%")
                    LabeledContent("Ambient noise", value: String(format: "%.4f RMS", result.ambientNoiseFloor))
                    if let energy = result.representativePeakEnergy { LabeledContent("Representative peak", value: String(format: "%.3f RMS", energy)) }
                    if let interval = result.representativeInterval { LabeledContent("Representative interval", value: String(format: "%.2f seconds", interval)) }
                    Slider(value: $calibrationSensitivityDraft, in: 0.1...1) { Text("Recommended sensitivity") } minimumValueLabel: { Text("Low") } maximumValueLabel: { Text("High") }
                    Stepper("Minimum interval: \(calibrationMinimumDraft, specifier: "%.2f") seconds", value: $calibrationMinimumDraft, in: 0.08...1.1, step: 0.01)
                    Stepper("Maximum interval: \(calibrationMaximumDraft, specifier: "%.2f") seconds", value: $calibrationMaximumDraft, in: max(0.16, calibrationMinimumDraft + 0.08)...1.2, step: 0.01)
                    if !result.warnings.isEmpty { Text("Warnings: \(result.warnings.map(\.rawValue).joined(separator: ", "))").foregroundStyle(.orange) }
                    Button("Accept Calibrated Settings") { model.acceptClapCalibration(sensitivity: calibrationSensitivityDraft, minimumInterval: calibrationMinimumDraft, maximumInterval: calibrationMaximumDraft) }.disabled(!result.isUsable).accessibilityIdentifier("settings.clapCalibration.accept")
                }
                if !model.clapTestStatuses.isEmpty {
                    VStack(alignment: .leading, spacing: 3) { ForEach(Array(model.clapTestStatuses.enumerated()), id: \.offset) { _, status in Text(status.displayName).font(.caption).foregroundStyle(.secondary) } }
                }
                if let message = model.clapTestMessage { Text(message).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
                LabeledContent("Microphone", value: model.microphonePermissionStatus.rawValue)
            }
            Section("Voice and spoken status") {
                Toggle("On-device voice commands", isOn: $voiceEnabled)
                TextField("Voice locale", text: $voiceLocale)
                TextField("Activation phrase", text: $voicePhrase)
                Button("Begin Voice Command") { Task { await model.beginVoiceCommand() } }.disabled(!voiceEnabled || model.voiceListening)
                Toggle("Spoken status", isOn: Binding(get: { spokenStatus }, set: { spokenStatus = $0; model.setSpokenStatusEnabled($0) }))
                Picker("Spoken detail", selection: $spokenStatusDetailLevel) { Text("Concise, no scene names").tag("concise"); Text("Detailed").tag("detailed") }.onChange(of: spokenStatusDetailLevel) { _, value in model.setSpokenStatusDetailLevel(value) }
                Picker("Fuzzy or ambiguous matches", selection: $voiceMatchConfirmationPolicy) { Text("Confirm fuzzy and ambiguous").tag("confirmFuzzyAndAmbiguous"); Text("Confirm ambiguous only").tag("confirmAmbiguousOnly") }
                LabeledContent("Speech recognition", value: model.speechPermissionStatus.rawValue)
            }
            Button("Reset Activation Settings") { Task { await model.resetActivationSettings() } }
            Text("Audio features remain off until explicitly enabled and permitted. Clap audio is never stored; voice has no cloud fallback.").foregroundStyle(.secondary)
        }.padding(24)
        .onChange(of: model.clapCalibrationResult) { _, result in
            guard let result else { return }
            calibrationSensitivityDraft = result.recommendedSensitivity
            calibrationMinimumDraft = result.recommendedMinimumInterval
            calibrationMaximumDraft = result.recommendedMaximumInterval
        }
    }

    private var executionTab: some View {
        Form {
            Section("Defaults for newly authored scenes and actions") {
                Stepper("Maximum concurrency: \(defaultConcurrency)", value: $defaultConcurrency, in: 1...16)
                HStack { Text("Action timeout"); Spacer(); TextField("Seconds", value: $defaultTimeout, format: .number).frame(width: 100); Text("seconds") }
                Text("Use 0 for no default timeout.").font(.caption).foregroundStyle(.secondary)
                Picker("Retry strategy", selection: $retryStrategy) { Text("None").tag("none"); Text("Fixed").tag("fixed"); Text("Exponential").tag("exponential") }.onChange(of: retryStrategy) { _, value in if value == "none" { retryAttempts = 1 } else if retryAttempts < 2 { retryAttempts = 2 } }
                Stepper("Maximum attempts: \(retryStrategy == "none" ? 1 : retryAttempts)", value: $retryAttempts, in: retryStrategy == "none" ? 1...1 : 2...20)
                HStack { Text("Initial retry delay"); Spacer(); TextField("Seconds", value: $retryDelay, format: .number).frame(width: 100); Text("seconds") }
                Picker("Failure policy", selection: $failurePolicy) { Text("Stop scene").tag("stopScene"); Text("Continue degraded").tag("continueDegraded"); Text("Continue optional").tag("continueOptional"); Text("Skip dependents").tag("skipDependents") }
                HStack { Text("Managed-process grace"); Spacer(); TextField("Seconds", value: $managedGrace, format: .number).frame(width: 100); Text("seconds") }
                HStack { Text("Terminate before force kill"); Spacer(); TextField("Seconds", value: $managedForcedStop, format: .number).frame(width: 100); Text("seconds") }
                Picker("Output retention", selection: $defaultOutputRetention) { Text("None").tag("none"); Text("Summary").tag("summary"); Text("Bounded").tag("bounded") }
                HStack { Text("Health-check interval"); Spacer(); TextField("Seconds", value: $defaultHealthInterval, format: .number).frame(width: 100); Text("seconds") }
                Stepper("Health-check attempt limit: \(defaultHealthAttempts)", value: $defaultHealthAttempts, in: 1...100)
                Picker("Resource ownership", selection: $defaultOwnershipPolicy) { Text("Stop only resources this run created").tag("createdOnly"); Text("Also stop explicitly adopted resources").tag("includeAdopted") }
                Picker("Process approvals", selection: $processApprovalBehavior) { Text("Remember exact approvals").tag("rememberExact"); Text("Ask every run").tag("askEveryRun") }
            }
            Text("Defaults apply only when creating a new scene or adding a new action. Existing saved plans are never silently rewritten. Including adopted resources can stop a process the app did not launch and therefore requires this explicit choice.").foregroundStyle(.secondary)
        }.padding(24)
    }

    private var privacyTab: some View {
        Form {
            Section("Run history") {
                Stepper("Retention: \(historyDays) days", value: $historyDays, in: 1...365).onChange(of: historyDays) { _, _ in applyRetention() }
                Stepper("Maximum records: \(historyRunCount)", value: $historyRunCount, in: 10...5_000, step: 10).onChange(of: historyRunCount) { _, _ in applyRetention() }
                Toggle("Store bounded redacted output", isOn: $historyOutputEnabled).onChange(of: historyOutputEnabled) { _, _ in applyRetention() }
                if historyOutputEnabled { Picker("Maximum output per action", selection: $historyOutputBytes) { Text("8 KB").tag(8_192); Text("32 KB").tag(32_768); Text("128 KB").tag(131_072); Text("512 KB").tag(524_288) }.onChange(of: historyOutputBytes) { _, _ in applyRetention() } }
                LabeledContent("Current storage", value: ByteCountFormatter.string(fromByteCount: model.historyStorageBytes, countStyle: .file))
                HStack { Button("Prune Now") { Task { await model.pruneRunHistory() } }; Button("Clear Valid History…", role: .destructive) { confirmsHistoryClear = true }; Button("Open Run-History Folder") { model.openRunHistoryLocation() } }
                Text("Diagnostic exports are bounded and redacted, but may contain scene names, action names, paths, and error summaries. Review every export before sharing.").font(.caption).foregroundStyle(.secondary)
                LabeledContent("Voice transcript retention", value: "Not retained after the explicit session")
                LabeledContent("Clap audio retention", value: "Never recorded or stored")
            }
            Section("Keychain secret references") {
                Text("Values are written directly to macOS Keychain and are never displayed, exported, logged, or stored in scene JSON.").font(.callout).foregroundStyle(.secondary)
                TextField("New reference identifier", text: $newReferenceID)
                SecureField("Secret value", text: $newSecret)
                Button("Create Reference") { Task { if await model.createKeychainReference(id: newReferenceID, secret: newSecret) { newReferenceID = ""; newSecret = "" } } }.disabled(newReferenceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newSecret.isEmpty).accessibilityIdentifier("settings.keychain.create")
                if !model.allKnownSecretReferenceIDs.isEmpty {
                    Picker("Secret reference label", selection: $selectedReferenceID) { Text("Select…").tag(""); ForEach(model.allKnownSecretReferenceIDs, id: \.self) { Text($0).tag($0) } }
                    if !selectedReferenceID.isEmpty {
                        LabeledContent("Keychain status", value: model.keychainReferenceExists(id: selectedReferenceID) ? "Present" : "Missing — repair required")
                        let usages = model.secretReferenceUsages(id: selectedReferenceID)
                        if usages.isEmpty { Text("No saved scene references this secret.").font(.caption).foregroundStyle(.secondary) }
                        else { ForEach(usages) { usage in Text("\(usage.sceneName) › \(usage.actionName) › \(usage.environmentName)").font(.caption.monospaced()) } }
                    }
                    SecureField("Replacement secret value", text: $replacementSecret)
                    HStack {
                        Button("Replace Without Revealing") { let id = selectedReferenceID; Task { if await model.updateKeychainReference(id: id, secret: replacementSecret) { replacementSecret = "" } } }.disabled(selectedReferenceID.isEmpty || replacementSecret.isEmpty || !model.keychainReferenceExists(id: selectedReferenceID))
                        Button("Repair Missing Reference") { let id = selectedReferenceID; Task { if await model.repairKeychainReference(id: id, secret: replacementSecret) { replacementSecret = "" } } }.disabled(selectedReferenceID.isEmpty || replacementSecret.isEmpty || model.keychainReferenceExists(id: selectedReferenceID))
                    }
                    TextField("Rename label", text: $renamedReferenceID)
                    HStack { Button("Rename Without Revealing") { let oldID = selectedReferenceID; let newID = renamedReferenceID; Task { if await model.renameKeychainReference(from: oldID, to: newID) { selectedReferenceID = newID.trimmingCharacters(in: .whitespacesAndNewlines); renamedReferenceID = "" } } }.disabled(selectedReferenceID.isEmpty || renamedReferenceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !model.keychainReferenceExists(id: selectedReferenceID)); Button("Delete Reference…", role: .destructive) { pendingSecretDeletion = selectedReferenceID }.disabled(selectedReferenceID.isEmpty || !model.keychainReferenceExists(id: selectedReferenceID)) }
                }
            }
            Text("No account, telemetry, analytics, cloud sync, or hosted backend. Redaction is defense in depth; review diagnostic files before sharing.").foregroundStyle(.secondary)
        }.padding(24)
    }

    private var permissionsTab: some View {
        Form {
            Button("Open Permission Center") { model.selectedSection = .permissions }
            LabeledContent("Accessibility", value: model.accessibilityPermission.status().rawValue)
            Button("Open Accessibility Settings") { Task { await model.accessibilityPermission.openSystemSettings() } }
            LabeledContent("Microphone", value: model.microphonePermissionStatus.rawValue)
            LabeledContent("Speech", value: model.speechPermissionStatus.rawValue)
            LabeledContent("Notifications", value: model.notificationPermissionStatus.rawValue)
            LabeledContent("Launch at login", value: model.launchAtLoginStatus.rawValue)
            Button("Refresh Current Permission State") { Task { await model.refresh() } }
            Text("Permission Center contains explicit request buttons and the relevant System Settings links. Permissions are requested only when their feature is enabled or used.").foregroundStyle(.secondary)
        }.padding(24)
    }

    private var integrationsTab: some View {
        Form {
            Button("Open Integration Center") { model.selectedSection = .integrations }
            LabeledContent("Detected", value: "\(model.integrations.filter(\.installed).count) of \(model.integrations.count)")
            ForEach(model.integrations) { integration in LabeledContent(integration.displayName, value: integration.installed ? "Installed" : "Missing") }
            Text("Tool discovery is local. Workspace Orchestrator does not install tools or manage their credentials.").foregroundStyle(.secondary)
        }.padding(24)
    }

    private var advancedTab: some View {
        Form {
            Section("Portable settings") {
                Button("Export Settings…") { do { settingsDocument = .init(data: try model.exportSettings()); exportingSettings = true } catch { model.presentedError = error.localizedDescription } }
                Button("Import Settings…") { importingSettings = true }
                Text("Settings exports contain only the allow-listed preferences shown here. They never contain scenes, history, approvals, Keychain values, or diagnostic output.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Scenes and local data") {
                Button("Import Scenes…") { importingScenes = true }
                Button("Export All Scenes…") { prepareSceneExport() }.disabled(model.scenes.isEmpty)
                Button("Open Application Support") { model.openApplicationSupport() }
                Button("Open Run-History Location") { model.openRunHistoryLocation() }
                Button("Reset Window-Layout Data…", role: .destructive) { confirmsWindowLayoutReset = true }
            }
            Section("Diagnostics") {
                Toggle("Advanced diagnostic logging", isOn: $advancedDiagnosticLogging)
                Text("When enabled, unified logging records only state names and aggregate counts—never scene content, paths, command arguments, output, transcripts, or secret values.").font(.caption).foregroundStyle(.secondary)
                Button("Open Diagnostics") { model.selectedSection = .diagnostics }
            }
            Section("Reset by scope") {
                Button("Reopen Onboarding") { model.resetOnboarding() }
                Button("Reset Settings to Defaults…", role: .destructive) { confirmsSettingsReset = true }
                Button("Clear Valid Run History…", role: .destructive) { confirmsHistoryClear = true }
                Button("Factory Reset by Explicit Scope…", role: .destructive) { factoryResetScope = .init(); confirmsFactoryReset = true }.accessibilityIdentifier("settings.factoryReset.open")
                Text("Factory reset presents separate choices for settings, scenes, valid history, Keychain secrets, window layouts, and approvals, followed by a typed confirmation. Corrupt history files remain preserved.").font(.caption).foregroundStyle(.secondary)
            }
            Section { Text("There is no global process-approval bypass. Release updates remain explicit downloads from the official source.").foregroundStyle(.secondary) }
        }.padding(24)
    }

    private var aboutTab: some View {
        Form { LabeledContent("Version", value: model.appVersion); LabeledContent("Build", value: model.buildNumber); Link("Check for Updates", destination: URL(string: "https://github.com/ahmadmemon/workspace-orchestrator/releases")!); Link("Documentation", destination: URL(string: "https://github.com/ahmadmemon/workspace-orchestrator/tree/main/docs")!) }.padding(24)
    }

    private func applyRetention() { Task { await model.updateHistoryRetention(days: historyDays, maximumRunCount: historyRunCount, outputEnabled: historyOutputEnabled, maximumOutputBytes: historyOutputBytes) } }
    private func prepareSceneExport() { do { sceneArchiveDocument = .init(data: try SceneArchiveService.export(model.scenes, appVersion: model.appVersion)); exportingScenes = true } catch { model.presentedError = error.localizedDescription } }
}

private struct SettingsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { .init(regularFileWithContents: data) }
}

private struct FactoryResetView: View {
    @Binding var scope: FactoryResetScope
    let confirm: (FactoryResetScope) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmation = ""

    var body: some View {
        Form {
            Section("Choose exact reset scope") {
                Toggle("Settings and onboarding state", isOn: $scope.settings)
                Toggle("Valid saved scenes", isOn: $scope.scenes)
                Toggle("Valid run history", isOn: $scope.history)
                Toggle("Keychain secrets", isOn: $scope.keychainSecrets)
                Toggle("Window-layout actions only", isOn: $scope.windowLayouts).disabled(scope.scenes)
                Toggle("Stored process approvals", isOn: $scope.approvals)
            }
            Section("Scope preview") {
                Text(scopeSummary).font(.callout).textSelection(.enabled)
                if scope.keychainSecrets { Label("Deleting Keychain secrets can break scene environment references until repaired.", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
                Text("Corrupt history files are always preserved. Unselected categories remain untouched.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Strong confirmation") {
                TextField("Type RESET", text: $confirmation)
                HStack { Button("Cancel") { dismiss() }; Spacer(); Button("Reset Selected Categories", role: .destructive) { confirm(scope) }.disabled(!scope.hasSelection || confirmation != "RESET") }
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .accessibilityIdentifier("settings.factoryResetScope")
    }

    private var scopeSummary: String {
        var labels: [String] = []
        if scope.settings { labels.append("settings") }; if scope.scenes { labels.append("scenes") }; if scope.history { labels.append("valid history") }; if scope.keychainSecrets { labels.append("Keychain secrets") }; if scope.windowLayouts && !scope.scenes { labels.append("window layouts") }; if scope.approvals { labels.append("approvals") }
        return labels.isEmpty ? "Nothing selected." : "Will delete: \(labels.joined(separator: ", "))."
    }
}

private struct HotKeyRecorder: NSViewRepresentable {
    let label: String
    let onRecord: (UInt32, UInt32, String) -> Void

    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.onRecord = onRecord
        button.title = "Record Shortcut…  \(label)"
        button.bezelStyle = .rounded
        button.setAccessibilityLabel("Global shortcut recorder")
        return button
    }

    func updateNSView(_ button: RecorderButton, context: Context) { if !button.recording { button.title = "Record Shortcut…  \(label)" }; button.onRecord = onRecord }

    final class RecorderButton: NSButton {
        var onRecord: ((UInt32, UInt32, String) -> Void)?
        var recording = false
        override var acceptsFirstResponder: Bool { true }

        override func mouseDown(with event: NSEvent) {
            recording = true
            title = "Type a shortcut (Esc cancels)…"
            window?.makeFirstResponder(self)
        }

        override func keyDown(with event: NSEvent) {
            if event.keyCode == 53 { finishRecording(); return }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags.contains(.command) || flags.contains(.control) || flags.contains(.option) else { NSSound.beep(); return }
            var carbonModifiers: UInt32 = 0
            if flags.contains(.command) { carbonModifiers |= 256 }
            if flags.contains(.shift) { carbonModifiers |= 512 }
            if flags.contains(.option) { carbonModifiers |= 2_048 }
            if flags.contains(.control) { carbonModifiers |= 4_096 }
            let key = event.keyCode == 49 ? "Space" : (event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)")
            let label = "\(flags.contains(.control) ? "⌃" : "")\(flags.contains(.option) ? "⌥" : "")\(flags.contains(.shift) ? "⇧" : "")\(flags.contains(.command) ? "⌘" : "")\(key)"
            onRecord?(UInt32(event.keyCode), carbonModifiers, label)
            finishRecording()
        }

        private func finishRecording() { recording = false; window?.makeFirstResponder(nil) }
    }
}
