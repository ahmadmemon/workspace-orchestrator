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
    @AppStorage("defaultSceneID") private var defaultSceneID = ""
    @AppStorage("menuBarPrimaryAction") private var menuBarPrimaryAction = "openDashboard"
    @AppStorage("hotKeySelection") private var hotKeySelection = "optionCommandSpace"
    @AppStorage("hotKeyLabel") private var hotKeyLabel = "⌥⌘Space"
    @AppStorage("clapSensitivity") private var clapSensitivity = 0.65
    @AppStorage("clapAction") private var clapAction = "showCommandPalette"
    @AppStorage("clapRequiresConfirmation") private var clapRequiresConfirmation = true
    @AppStorage("clapTestSoundEnabled") private var clapTestSoundEnabled = true
    @AppStorage("voiceLocaleIdentifier") private var voiceLocale = Locale.current.identifier
    @AppStorage("voiceActivationPhrase") private var voicePhrase = "Workspace online"
    @AppStorage("executionDefaultConcurrency") private var defaultConcurrency = 3
    @AppStorage("executionDefaultTimeout") private var defaultTimeout = 0.0
    @AppStorage("executionRetryStrategy") private var retryStrategy = "none"
    @AppStorage("executionRetryAttempts") private var retryAttempts = 2
    @AppStorage("executionRetryDelay") private var retryDelay = 1.0
    @AppStorage("executionFailurePolicy") private var failurePolicy = "stopScene"
    @AppStorage("managedProcessGraceSeconds") private var managedGrace = 5.0
    @AppStorage("historyRetentionDays") private var historyDays = 30
    @AppStorage("historyMaximumRunCount") private var historyRunCount = 200
    @AppStorage("historyOutputEnabled") private var historyOutputEnabled = true
    @AppStorage("historyMaximumOutputBytes") private var historyOutputBytes = 32_768

    @State private var newReferenceID = ""
    @State private var newSecret = ""
    @State private var selectedReferenceID = ""
    @State private var replacementSecret = ""
    @State private var pendingSecretDeletion: String?
    @State private var importingSettings = false
    @State private var exportingSettings = false
    @State private var settingsDocument: SettingsDocument?
    @State private var confirmsSettingsReset = false
    @State private var confirmsHistoryClear = false
    @State private var confirmsFactoryReset = false

    var body: some View {
        TabView {
            generalTab.tabItem { Label("General", systemImage: "gear") }
            appearanceTab.tabItem { Label("Appearance", systemImage: "paintbrush") }
            activationTab.tabItem { Label("Activation", systemImage: "waveform") }
            executionTab.tabItem { Label("Execution", systemImage: "bolt") }
            privacyTab.tabItem { Label("Privacy", systemImage: "hand.raised") }
            permissionsTab.tabItem { Label("Permissions", systemImage: "lock.shield") }
            integrationsTab.tabItem { Label("Integrations", systemImage: "puzzlepiece.extension") }
            advancedTab.tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
            aboutTab.tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 760, height: 560)
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
        .confirmationDialog("Reset settings to defaults?", isPresented: $confirmsSettingsReset, titleVisibility: .visible) {
            Button("Reset Settings", role: .destructive) { Task { await model.resetSettings() } }
        } message: { Text("Resets General, Appearance, Activation, Execution, and Privacy preferences. Scenes, history, approvals, and Keychain references are retained.") }
        .confirmationDialog("Factory reset local application data?", isPresented: $confirmsFactoryReset, titleVisibility: .visible) {
            Button("Factory Reset", role: .destructive) { Task { await model.factoryReset() } }
        } message: { Text("Deletes valid scenes, valid run history, process approvals, and settings, then reopens onboarding. Corrupt history files and Keychain secrets are deliberately preserved for recovery and safety.") }
        .confirmationDialog("Clear valid run history?", isPresented: $confirmsHistoryClear, titleVisibility: .visible) {
            Button("Clear Valid Run History", role: .destructive) { Task { await model.clearRunHistory() } }
        } message: { Text("Scenes, settings, approvals, Keychain secrets, and corrupt history files are retained.") }
        .confirmationDialog("Delete Keychain reference?", isPresented: Binding(get: { pendingSecretDeletion != nil }, set: { if !$0 { pendingSecretDeletion = nil } }), titleVisibility: .visible, presenting: pendingSecretDeletion) { id in
            Button("Delete \(id)", role: .destructive) { Task { await model.deleteKeychainReference(id: id); pendingSecretDeletion = nil; selectedReferenceID = "" } }
        } message: { id in Text("The secret value for \(id) will be deleted from this app's Keychain service. Scene references are not rewritten.") }
        .alert("Workspace Orchestrator", isPresented: Binding(get: { model.presentedError != nil }, set: { if !$0 { model.presentedError = nil } })) { Button("OK") { model.presentedError = nil } } message: { Text(model.presentedError ?? "Unknown error") }
    }

    private var generalTab: some View {
        Form {
            Section("Startup and notifications") {
                Toggle("Launch at login", isOn: Binding(get: { model.launchAtLoginStatus == .enabled }, set: model.setLaunchAtLogin))
                LabeledContent("Launch status", value: model.launchAtLoginStatus.rawValue)
                Toggle("Local notifications", isOn: Binding(get: { notifications }, set: { enabled in notifications = enabled; Task { await model.setNotificationsEnabled(enabled) } }))
                LabeledContent("Notification permission", value: model.notificationPermissionStatus.rawValue)
            }
            Section("Default behavior") {
                Picker("Default scene", selection: $defaultSceneID) { Text("None").tag(""); ForEach(model.scenes) { Text($0.name).tag($0.id) } }
                Picker("Primary menu-bar action", selection: $menuBarPrimaryAction) { Text("Open Dashboard").tag("openDashboard"); Text("Open Command Palette").tag("showCommandPalette"); Text("Run Default Scene").tag("runDefaultScene") }
                if menuBarPrimaryAction == "runDefaultScene", defaultSceneID.isEmpty { Label("Choose a default scene before using this action.", systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
            }
            Text("Updates are checked only when requested and open the official GitHub Releases source.").foregroundStyle(.secondary)
        }.padding(24)
    }

    private var appearanceTab: some View {
        Form {
            Picker("Theme", selection: $appearanceMode) { Text("Obsidian").tag("Obsidian"); Text("Follow System").tag("System") }
            Toggle("Reduce custom glow and motion", isOn: $reduceEffects)
            Toggle("Compact list rows", isOn: $compactRows)
            Toggle("Completion sound effects", isOn: $soundEffects)
            Text("System Reduce Motion, Reduce Transparency, and Increase Contrast are always respected. Completion sounds never include scene or output content.").foregroundStyle(.secondary)
        }.padding(24)
    }

    private var activationTab: some View {
        Form {
            Section("Global shortcut") {
                Picker("Shortcut", selection: $hotKeySelection) { Text("⌥⌘Space").tag("optionCommandSpace"); Text("⌃⌥Space").tag("controlOptionSpace"); Text("⇧⌘Space").tag("shiftCommandSpace") }.onChange(of: hotKeySelection) { _, selection in applyHotKey(selection) }
                LabeledContent("Registered", value: hotKeyLabel)
            }
            Section("Double clap — opt in") {
                Toggle("Enable local double-clap detection", isOn: Binding(get: { model.clapEnabled }, set: { enabled in Task { await model.setClapEnabled(enabled) } }))
                LabeledContent("Detector state", value: model.clapState.displayName)
                Slider(value: $clapSensitivity, in: 0.1...1) { Text("Sensitivity") } minimumValueLabel: { Text("Low") } maximumValueLabel: { Text("High") }.onChange(of: clapSensitivity) { _, _ in model.pauseClapForConfigurationChange() }
                Picker("Action", selection: $clapAction) { Text("Show Command Palette").tag("showCommandPalette"); Text("Run Default Scene").tag("runDefaultScene") }.onChange(of: clapAction) { _, _ in model.pauseClapForConfigurationChange() }
                Toggle("Require confirmation before running a scene", isOn: $clapRequiresConfirmation).disabled(clapAction != "runDefaultScene")
                Toggle("Audible confirmation in test mode", isOn: $clapTestSoundEnabled)
                HStack { Button("Calibrate Ambient Noise (5s)") { Task { await model.beginClapCalibration() } }.disabled(model.clapState == .calibrating); Button("Test One Double Clap") { Task { await model.beginClapTest() } }.disabled(model.clapState == .testing); Button("Resume Listening") { Task { await model.resumeClapListening() } }.disabled(!model.clapEnabled || model.clapListening || model.clapState == .calibrating || model.clapState == .testing) }
                if let result = model.clapCalibrationResult {
                    LabeledContent("Calibration confidence", value: "\(Int(result.confidence * 100))%")
                    LabeledContent("Ambient noise", value: String(format: "%.4f RMS", result.ambientNoiseFloor))
                    LabeledContent("Recommended sensitivity", value: "\(Int(result.recommendedSensitivity * 100))%")
                    if !result.warnings.isEmpty { Text("Warnings: \(result.warnings.map(\.rawValue).joined(separator: ", "))").foregroundStyle(.orange) }
                    Button("Apply Recommendation") { Task { await model.applyRecommendedClapSensitivity() } }.disabled(!result.isUsable)
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
                LabeledContent("Speech recognition", value: model.speechPermissionStatus.rawValue)
            }
            Text("Audio features remain off until explicitly enabled and permitted. Clap audio is never stored; voice has no cloud fallback.").foregroundStyle(.secondary)
        }.padding(24)
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
            }
            Text("Defaults apply only when creating a new scene or adding a new action. Existing saved plans are never silently rewritten. Process-capable actions still require exact-configuration approval.").foregroundStyle(.secondary)
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
                Button("Prune Now") { Task { await model.pruneRunHistory() } }
            }
            Section("Keychain secret references") {
                Text("Values are written directly to macOS Keychain and are never displayed, exported, logged, or stored in scene JSON.").font(.callout).foregroundStyle(.secondary)
                TextField("New reference identifier", text: $newReferenceID)
                SecureField("Secret value", text: $newSecret)
                Button("Create Reference") { Task { if await model.createKeychainReference(id: newReferenceID, secret: newSecret) { newReferenceID = ""; newSecret = "" } } }.disabled(newReferenceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newSecret.isEmpty)
                if !model.keychainReferenceIDs.isEmpty {
                    Picker("Existing reference", selection: $selectedReferenceID) { Text("Select…").tag(""); ForEach(model.keychainReferenceIDs, id: \.self) { Text($0).tag($0) } }
                    SecureField("Replacement secret value", text: $replacementSecret)
                    HStack { Button("Update Without Revealing") { let id = selectedReferenceID; Task { if await model.updateKeychainReference(id: id, secret: replacementSecret) { replacementSecret = "" } } }.disabled(selectedReferenceID.isEmpty || replacementSecret.isEmpty); Button("Delete Reference…", role: .destructive) { pendingSecretDeletion = selectedReferenceID }.disabled(selectedReferenceID.isEmpty) }
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
            Section("Reset by scope") {
                Button("Reopen Onboarding") { model.resetOnboarding() }
                Button("Reset Settings to Defaults…", role: .destructive) { confirmsSettingsReset = true }
                Button("Clear Valid Run History…", role: .destructive) { confirmsHistoryClear = true }
                Button("Factory Reset Local App Data…", role: .destructive) { confirmsFactoryReset = true }
                Text("Factory reset scope: settings, valid scenes, valid history, and process approvals. Keychain secrets and corrupt history files are excluded and preserved.").font(.caption).foregroundStyle(.secondary)
            }
            Section { Button("Open Diagnostics") { model.selectedSection = .diagnostics }; Text("There is no global process-approval bypass. Release updates remain explicit downloads from the official source.").foregroundStyle(.secondary) }
        }.padding(24)
    }

    private var aboutTab: some View {
        Form { LabeledContent("Version", value: model.appVersion); LabeledContent("Build", value: model.buildNumber); Link("Check for Updates", destination: URL(string: "https://github.com/ahmadmemon/workspace-orchestrator/releases")!); Link("Documentation", destination: URL(string: "https://github.com/ahmadmemon/workspace-orchestrator/tree/main/docs")!) }.padding(24)
    }

    private func applyHotKey(_ selection: String) {
        switch selection {
        case "controlOptionSpace": hotKeyLabel = "⌃⌥Space"; model.updateGlobalHotKey(keyCode: 49, modifiers: 6_144, label: hotKeyLabel)
        case "shiftCommandSpace": hotKeyLabel = "⇧⌘Space"; model.updateGlobalHotKey(keyCode: 49, modifiers: 768, label: hotKeyLabel)
        default: hotKeyLabel = "⌥⌘Space"; model.updateGlobalHotKey(keyCode: 49, modifiers: 2_304, label: hotKeyLabel)
        }
    }
    private func applyRetention() { Task { await model.updateHistoryRetention(days: historyDays, maximumRunCount: historyRunCount, outputEnabled: historyOutputEnabled, maximumOutputBytes: historyOutputBytes) } }
}

private struct SettingsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { .init(regularFileWithContents: data) }
}
