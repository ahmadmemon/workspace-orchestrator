import AppKit
import SceneCore
import SwiftUI

struct SceneEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SceneCore.Scene
    @State private var selection: ActionSelection?
    @State private var validationMessage: String?
    let executionDefaults: WorkspaceExecutionDefaults
    let save: (SceneCore.Scene) async -> Void

    init(scene: SceneCore.Scene, executionDefaults: WorkspaceExecutionDefaults = .init(), save: @escaping (SceneCore.Scene) async -> Void) { _draft = State(initialValue: scene); self.executionDefaults = executionDefaults; self.save = save }
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Start Workspace") { ForEach(draft.actions) { action in Label(action.displayName, systemImage: actionSymbol(action)).tag(ActionSelection.start(action.id)) }.onMove { draft.actions.move(fromOffsets: $0, toOffset: $1) }.onDelete { draft.actions.remove(atOffsets: $0) }; addMenu(deactivation: false) }
                Section("Stop Workspace") { ForEach(draft.deactivationActions) { action in Label(action.displayName, systemImage: actionSymbol(action)).tag(ActionSelection.stop(action.id)) }.onMove { draft.deactivationActions.move(fromOffsets: $0, toOffset: $1) }.onDelete { draft.deactivationActions.remove(atOffsets: $0) }; addMenu(deactivation: true) }
            }.navigationSplitViewColumnWidth(min: 240, ideal: 280)
        } detail: {
            Form {
                Section("Scene") { TextField("Name", text: $draft.name); TextField("Description", text: Binding(get: { draft.description ?? "" }, set: { draft.description = $0.isEmpty ? nil : $0 }), axis: .vertical); TextField("SF Symbol", text: Binding(get: { draft.iconName ?? "" }, set: { draft.iconName = $0.isEmpty ? nil : $0 })); Toggle("Favorite", isOn: $draft.favorite); TextField("Tags, comma separated", text: Binding(get: { draft.tags.joined(separator: ", ") }, set: { draft.tags = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } })); Stepper("Maximum concurrency: \(draft.maximumConcurrency)", value: $draft.maximumConcurrency, in: 1...16) }
                if let selected = selectedAction {
                    Section("Selected Action") {
                        LabeledContent("Stable action ID") { Text(action(for: selected)?.id ?? "").font(.caption.monospaced()).textSelection(.enabled) }
                        TextField("Action name", text: actionNameBinding(selected))
                        Toggle("Enabled", isOn: enabledBinding(selected))
                        Picker("Failure policy", selection: failureBinding(selected)) { Text("Stop scene").tag(FailurePolicy.stopScene); Text("Continue degraded").tag(FailurePolicy.continueDegraded); Text("Continue optional").tag(FailurePolicy.continueOptional); Text("Skip dependents").tag(FailurePolicy.skipDependents) }
                        Picker("Idempotency", selection: idempotencyBinding(selected)) { ForEach(IdempotencyPolicy.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                        Picker("Output retention", selection: outputBinding(selected)) { ForEach(OutputRetentionPolicy.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                        TextField("Action timeout seconds (optional)", text: timeoutBinding(selected))
                        Picker("Retry strategy", selection: retryStrategyBinding(selected)) { ForEach(RetryStrategy.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                        Stepper("Maximum attempts: \(action(for: selected)?.configuration.retryPolicy.maximumAttempts ?? 1)", value: retryAttemptsBinding(selected), in: 1...20)
                        TextField("Dependencies (IDs, comma separated)", text: dependencyBinding(selected))
                        payloadEditor(selected)
                    }
                    conditionSection(selected)
                    healthCheckSection(selected)
                }
                if let validationMessage { Section { Text(validationMessage).foregroundStyle(ObsidianTokens.failure).textSelection(.enabled).accessibilityIdentifier("sceneEditor.validation") } }
            }.formStyle(.grouped)
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { validateAndSave() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("s", modifiers: .command)
                    .accessibilityIdentifier("sceneEditor.save")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .navigationTitle(draft.name)
        .accessibilityIdentifier("screen.sceneEditor")
    }

    private var selectedAction: ActionSelection? { selection }
    private func validateAndSave() { do { try SceneValidator.validate(draft); validationMessage = nil; Task { await save(draft) } } catch { validationMessage = error.localizedDescription } }
    private func action(for selection: ActionSelection) -> SceneAction? { switch selection { case .start(let id): draft.actions.first { $0.id == id }; case .stop(let id): draft.deactivationActions.first { $0.id == id } } }
    private func replace(_ selection: ActionSelection, with action: SceneAction) { switch selection { case .start(let id): if let index = draft.actions.firstIndex(where: { $0.id == id }) { draft.actions[index] = action }; case .stop(let id): if let index = draft.deactivationActions.firstIndex(where: { $0.id == id }) { draft.deactivationActions[index] = action } } }
    private func updateConfiguration(_ selection: ActionSelection, _ body: (inout ActionConfiguration) -> Void) { guard let action = action(for: selection) else { return }; var configuration = action.configuration; body(&configuration); replace(selection, with: action.replacingConfiguration(configuration)) }
    private func actionNameBinding(_ selection: ActionSelection) -> Binding<String> { .init(get: { action(for: selection)?.configuration.name ?? "" }, set: { value in updateConfiguration(selection) { $0.name = value.isEmpty ? nil : value } }) }
    private func enabledBinding(_ selection: ActionSelection) -> Binding<Bool> { .init(get: { action(for: selection)?.configuration.enabled ?? true }, set: { value in updateConfiguration(selection) { $0.enabled = value } }) }
    private func failureBinding(_ selection: ActionSelection) -> Binding<FailurePolicy> { .init(get: { action(for: selection)?.configuration.failurePolicy ?? .stopScene }, set: { value in updateConfiguration(selection) { $0.failurePolicy = value } }) }
    private func idempotencyBinding(_ selection: ActionSelection) -> Binding<IdempotencyPolicy> { .init(get: { action(for: selection)?.configuration.idempotencyPolicy ?? .alwaysRun }, set: { value in updateConfiguration(selection) { $0.idempotencyPolicy = value } }) }
    private func outputBinding(_ selection: ActionSelection) -> Binding<OutputRetentionPolicy> { .init(get: { action(for: selection)?.configuration.outputRetention ?? .summary }, set: { value in updateConfiguration(selection) { $0.outputRetention = value } }) }
    private func timeoutBinding(_ selection: ActionSelection) -> Binding<String> { .init(get: { action(for: selection)?.configuration.timeoutSeconds.map { String($0) } ?? "" }, set: { value in updateConfiguration(selection) { $0.timeoutSeconds = Double(value) } }) }
    private func retryStrategyBinding(_ selection: ActionSelection) -> Binding<RetryStrategy> { .init(get: { action(for: selection)?.configuration.retryPolicy.strategy ?? .none }, set: { value in updateConfiguration(selection) { $0.retryPolicy.strategy = value; if value == .none { $0.retryPolicy.maximumAttempts = 1 } else if $0.retryPolicy.maximumAttempts < 2 { $0.retryPolicy.maximumAttempts = 2 } } }) }
    private func retryAttemptsBinding(_ selection: ActionSelection) -> Binding<Int> { .init(get: { action(for: selection)?.configuration.retryPolicy.maximumAttempts ?? 1 }, set: { value in updateConfiguration(selection) { $0.retryPolicy.maximumAttempts = value; if value == 1 { $0.retryPolicy.strategy = .none } } }) }
    private func dependencyBinding(_ selection: ActionSelection) -> Binding<String> { .init(get: { action(for: selection)?.configuration.dependencies.joined(separator: ", ") ?? "" }, set: { value in updateConfiguration(selection) { $0.dependencies = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } } }) }

    @ViewBuilder private func conditionSection(_ selection: ActionSelection) -> some View {
        Section("Conditions") {
            let configuration = action(for: selection)?.configuration ?? .init()
            Picker("Evaluation", selection: Binding(get: { action(for: selection)?.configuration.conditionEvaluationMode ?? .all }, set: { mode in updateConfiguration(selection) { $0.conditionEvaluationMode = mode } })) {
                Text("All enabled conditions").tag(ConditionEvaluationMode.all)
                Text("Any enabled condition").tag(ConditionEvaluationMode.any)
            }
            .pickerStyle(.segmented)
            ForEach(configuration.conditions.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Toggle("Condition \(index + 1) enabled", isOn: conditionEnabledBinding(selection, index: index))
                        Spacer()
                        Button("Remove", role: .destructive) { removeCondition(selection, index: index) }
                    }
                    conditionFields(selection, index: index)
                }
                .padding(.vertical, 4)
                .accessibilityIdentifier("sceneEditor.condition.\(index)")
            }
            Menu("Add Condition", systemImage: "plus") {
                Button("Path Exists") { updateConfiguration(selection) { $0.conditions.append(.pathExists("/")) } }
                Button("Environment Equals") { updateConfiguration(selection) { $0.conditions.append(.environmentEquals(name: "NAME", value: "value")) } }
            }
            Text(conditionSummary(configuration)).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("sceneEditor.conditionSummary")
        }
    }

    @ViewBuilder private func conditionFields(_ selection: ActionSelection, index: Int) -> some View {
        if let configuration = action(for: selection)?.configuration, configuration.conditions.indices.contains(index) {
            switch configuration.conditions[index] {
            case .pathExists:
                TextField("Absolute path that must exist", text: conditionStringBinding(selection, index: index, field: .path))
            case .environmentEquals:
                TextField("Environment name", text: conditionStringBinding(selection, index: index, field: .environmentName))
                TextField("Expected value", text: conditionStringBinding(selection, index: index, field: .environmentValue))
            }
        }
    }

    private enum ConditionStringField { case path, environmentName, environmentValue }
    private func conditionStringBinding(_ selection: ActionSelection, index: Int, field: ConditionStringField) -> Binding<String> { .init(get: { guard let configuration = action(for: selection)?.configuration, configuration.conditions.indices.contains(index) else { return "" }; switch (configuration.conditions[index], field) { case (.pathExists(let path), .path): return path; case (.environmentEquals(let name, _), .environmentName): return name; case (.environmentEquals(_, let value), .environmentValue): return value; default: return "" } }, set: { newValue in updateConfiguration(selection) { configuration in guard configuration.conditions.indices.contains(index) else { return }; switch (configuration.conditions[index], field) { case (.pathExists, .path): configuration.conditions[index] = .pathExists(newValue); case (.environmentEquals(_, let value), .environmentName): configuration.conditions[index] = .environmentEquals(name: newValue, value: value); case (.environmentEquals(let name, _), .environmentValue): configuration.conditions[index] = .environmentEquals(name: name, value: newValue); default: break } } }) }
    private func conditionEnabledBinding(_ selection: ActionSelection, index: Int) -> Binding<Bool> { .init(get: { !(action(for: selection)?.configuration.disabledConditionIndexes.contains(index) ?? false) }, set: { enabled in updateConfiguration(selection) { if enabled { $0.disabledConditionIndexes.remove(index) } else { $0.disabledConditionIndexes.insert(index) } } }) }
    private func removeCondition(_ selection: ActionSelection, index: Int) { updateConfiguration(selection) { configuration in guard configuration.conditions.indices.contains(index) else { return }; configuration.conditions.remove(at: index); configuration.disabledConditionIndexes = Set(configuration.disabledConditionIndexes.compactMap { disabled in disabled == index ? nil : (disabled > index ? disabled - 1 : disabled) }) } }
    private func conditionSummary(_ configuration: ActionConfiguration) -> String { let enabled = configuration.conditions.indices.filter { !configuration.disabledConditionIndexes.contains($0) }.count; guard enabled > 0 else { return "No enabled conditions; the action is eligible to run." }; return "Runs when \(configuration.conditionEvaluationMode == .all ? "all" : "at least one") of \(enabled) enabled condition\(enabled == 1 ? "" : "s") succeeds." }

    @ViewBuilder private func healthCheckSection(_ selection: ActionSelection) -> some View {
        Section("Health Checks") {
            let checks = action(for: selection)?.configuration.healthChecks ?? []
            ForEach(checks.indices, id: \.self) { index in
                HealthCheckEditor(check: healthCheckBinding(selection, index: index), remove: { updateConfiguration(selection) { guard $0.healthChecks.indices.contains(index) else { return }; $0.healthChecks.remove(at: index) } })
                    .accessibilityIdentifier("sceneEditor.healthCheck.\(index)")
            }
            Menu("Add Health Check", systemImage: "plus") {
                Button("HTTP") { appendHealth(.http(.init(url: "http://127.0.0.1:8080/health")), to: selection) }
                Button("TCP") { appendHealth(.tcp(.init(port: 8080)), to: selection) }
                Button("File or Directory") { appendHealth(.file(.init(path: "/tmp")), to: selection) }
                Button("Managed Process") { appendHealth(.process(.init(actionID: action(for: selection)?.id ?? "action-id")), to: selection) }
                Button("Application") { appendHealth(.application(.init(bundleIdentifier: "com.apple.TextEdit")), to: selection) }
                Button("Docker Service") { appendHealth(.docker(.init(composeActionID: action(for: selection)?.id ?? "compose-action", service: "service")), to: selection) }
            }
            Text(checks.isEmpty ? "No readiness checks. Successful execution marks this action ready immediately." : "\(checks.count) readiness check\(checks.count == 1 ? "" : "s"); optional failures produce a visible warning instead of failing the action.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func appendHealth(_ check: HealthCheck, to selection: ActionSelection) { updateConfiguration(selection) { $0.healthChecks.append(check) } }
    private func healthCheckBinding(_ selection: ActionSelection, index: Int) -> Binding<HealthCheck> { .init(get: { let checks = action(for: selection)?.configuration.healthChecks ?? []; return checks.indices.contains(index) ? checks[index] : .file(.init(path: "/")) }, set: { check in updateConfiguration(selection) { guard $0.healthChecks.indices.contains(index) else { return }; $0.healthChecks[index] = check } }) }

    @ViewBuilder private func payloadEditor(_ selection: ActionSelection) -> some View {
        if let action = action(for: selection) {
            switch action {
            case .openApplication(let value): TextField("Bundle identifier", text: payload(selection, value.bundleIdentifier) { var copy = value; copy.bundleIdentifier = $0; return .openApplication(copy) }); TextField("Application path fallback", text: payload(selection, value.applicationPathFallback ?? "") { var copy = value; copy.applicationPathFallback = $0.isEmpty ? nil : $0; return .openApplication(copy) }); Picker("Launch policy", selection: Binding(get: { value.launchPolicy }, set: { var copy = value; copy.launchPolicy = $0; replace(selection, with: .openApplication(copy)) })) { Text("Reuse running app").tag(ApplicationLaunchPolicy.reuse); Text("Always launch").tag(ApplicationLaunchPolicy.alwaysLaunch) }; Toggle("Bring app forward", isOn: Binding(get: { value.activate }, set: { var copy = value; copy.activate = $0; replace(selection, with: .openApplication(copy)) })); Toggle("Wait until running", isOn: Binding(get: { value.waitForRunning }, set: { var copy = value; copy.waitForRunning = $0; replace(selection, with: .openApplication(copy)) }))
            case .openURL(let value): TextField("Primary HTTP(S) URL", text: payload(selection, value.url) { var copy = value; copy.url = $0; return .openURL(copy) }); TextField("Additional URLs, one per line", text: payload(selection, value.additionalURLs.joined(separator: "\n")) { var copy = value; copy.additionalURLs = $0.split(whereSeparator: \.isNewline).map(String.init); return .openURL(copy) }, axis: .vertical); TextField("Browser bundle identifier", text: payload(selection, value.browserBundleIdentifier ?? "") { var copy = value; copy.browserBundleIdentifier = $0.isEmpty ? nil : $0; return .openURL(copy) }); Picker("Window", selection: Binding(get: { value.windowPolicy }, set: { var copy = value; copy.windowPolicy = $0; replace(selection, with: .openURL(copy)) })) { Text("Existing window").tag(BrowserWindowPolicy.existing); Text("New window").tag(BrowserWindowPolicy.newWindow) }; Toggle("Deduplicate during run", isOn: Binding(get: { value.deduplicateWithinRun }, set: { var copy = value; copy.deduplicateWithinRun = $0; replace(selection, with: .openURL(copy)) }))
            case .openFile(let value): TextField("Absolute file or folder path", text: payload(selection, value.path) { var copy = value; copy.path = $0; return .openFile(copy) }); TextField("Open with bundle identifier", text: payload(selection, value.applicationBundleIdentifier ?? "") { var copy = value; copy.applicationBundleIdentifier = $0.isEmpty ? nil : $0; return .openFile(copy) }); Picker("Open policy", selection: Binding(get: { value.openPolicy }, set: { var copy = value; copy.openPolicy = $0; replace(selection, with: .openFile(copy)) })) { Text("Open").tag(FileOpenPolicy.open); Text("Reveal in Finder").tag(FileOpenPolicy.revealInFinder) }; Picker("If missing", selection: Binding(get: { value.missingPathPolicy }, set: { var copy = value; copy.missingPathPolicy = $0; replace(selection, with: .openFile(copy)) })) { ForEach(MissingPathPolicy.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            case .runProcess(let value): processFields(selection, value: value)
            case .managedProcess(let value): TextField("Absolute executable", text: payload(selection, value.executable) { var copy = value; copy.executable = $0; return .managedProcess(copy) }); StructuredArgumentEditor(executable: value.executable, arguments: argumentsBinding(selection)); TextField("Working directory", text: payload(selection, value.workingDirectory ?? "") { var copy = value; copy.workingDirectory = $0.isEmpty ? nil : $0; return .managedProcess(copy) }); TextField("Single-instance key", text: payload(selection, value.singleInstanceKey) { var copy = value; copy.singleInstanceKey = $0; return .managedProcess(copy) }); Picker("Restart policy", selection: Binding(get: { value.restartPolicy }, set: { var copy = value; copy.restartPolicy = $0; replace(selection, with: .managedProcess(copy)) })) { Text("Never").tag(RestartPolicy.never); Text("On failure").tag(RestartPolicy.onFailure) }; Text("Environment entries are stored as typed plain/inherited/Keychain-reference values. Existing entries are preserved; use import JSON review for advanced environment editing.").font(.caption).foregroundStyle(.secondary)
            case .wait(let value): TextField("Message", text: payload(selection, value.message) { var copy = value; copy.message = $0; return .wait(copy) }); TextField("Duration seconds", value: Binding(get: { value.durationSeconds }, set: { var copy = value; copy.durationSeconds = $0; replace(selection, with: .wait(copy)) }), format: .number)
            case .editorWorkspace(let value): Picker("Editor", selection: Binding(get: { value.editor }, set: { var copy = value; copy.editor = $0; replace(selection, with: .editorWorkspace(copy)) })) { ForEach(EditorChoice.allCases, id: \.self) { Text($0.rawValue).tag($0) } }; TextField("Project or workspace path", text: payload(selection, value.projectPath) { var copy = value; copy.projectPath = $0; return .editorWorkspace(copy) }); TextField("Profile", text: payload(selection, value.profile ?? "") { var copy = value; copy.profile = $0.isEmpty ? nil : $0; return .editorWorkspace(copy) }); Toggle("Open new window", isOn: Binding(get: { value.newWindow }, set: { var copy = value; copy.newWindow = $0; replace(selection, with: .editorWorkspace(copy)) })); Toggle("Wait for editor", isOn: Binding(get: { value.waitForApplication }, set: { var copy = value; copy.waitForApplication = $0; replace(selection, with: .editorWorkspace(copy)) }))
            case .terminalWorkspace(let value): Picker("Terminal", selection: Binding(get: { value.terminal }, set: { var copy = value; copy.terminal = $0; replace(selection, with: .terminalWorkspace(copy)) })) { Text("Terminal").tag(TerminalChoice.terminal); Text("iTerm2").tag(TerminalChoice.iTerm2) }; TextField("Working directory", text: payload(selection, value.workingDirectory) { var copy = value; copy.workingDirectory = $0; return .terminalWorkspace(copy) }); TextField("tmux session (optional)", text: payload(selection, value.tmuxSessionName ?? "") { var copy = value; copy.tmuxSessionName = $0.isEmpty ? nil : $0; return .terminalWorkspace(copy) }); Toggle("Stop tmux on deactivation", isOn: Binding(get: { value.stopTmuxOnDeactivate }, set: { var copy = value; copy.stopTmuxOnDeactivate = $0; replace(selection, with: .terminalWorkspace(copy)) }))
            case .dockerCompose(let value): TextField("Compose project directory", text: payload(selection, value.projectDirectory) { var copy = value; copy.projectDirectory = $0; return .dockerCompose(copy) }); TextField("Compose file", text: payload(selection, value.composeFile ?? "") { var copy = value; copy.composeFile = $0.isEmpty ? nil : $0; return .dockerCompose(copy) }); TextField("Services, comma separated", text: payload(selection, value.services.joined(separator: ", ")) { var copy = value; copy.services = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }; return .dockerCompose(copy) }); TextField("Profiles, comma separated", text: payload(selection, value.profiles.joined(separator: ", ")) { var copy = value; copy.profiles = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }; return .dockerCompose(copy) }); Toggle("Build images", isOn: Binding(get: { value.build }, set: { var copy = value; copy.build = $0; replace(selection, with: .dockerCompose(copy)) })); Picker("Pull policy", selection: Binding(get: { value.pullPolicy }, set: { var copy = value; copy.pullPolicy = $0; replace(selection, with: .dockerCompose(copy)) })) { ForEach(DockerPullPolicy.allCases, id: \.self) { Text($0.rawValue).tag($0) } }; Picker("Stop policy", selection: Binding(get: { value.stopPolicy }, set: { var copy = value; copy.stopPolicy = $0; replace(selection, with: .dockerCompose(copy)) })) { Text("Stop services").tag(DockerStopPolicy.stop); Text("Compose down").tag(DockerStopPolicy.down) }; Toggle("Remove volumes (destructive)", isOn: Binding(get: { value.removeVolumes }, set: { var copy = value; copy.removeVolumes = $0; replace(selection, with: .dockerCompose(copy)) })).tint(ObsidianTokens.failure)
            case .shortcut(let value): TextField("Shortcut name", text: payload(selection, value.name) { var copy = value; copy.name = $0; return .shortcut(copy) }); TextField("Input file", text: payload(selection, value.inputFile ?? "") { var copy = value; copy.inputFile = $0.isEmpty ? nil : $0; return .shortcut(copy) })
            case .windowLayout(let value): LabeledContent("Reviewed placements", value: "\(value.placements.count)"); Text("Window layouts are edited through Capture Workspace to preserve matching confidence and display mapping.").foregroundStyle(.secondary)
            }
        }
    }
    @ViewBuilder private func processFields(_ selection: ActionSelection, value: RunProcessAction) -> some View { TextField("Absolute executable", text: payload(selection, value.executable) { var copy = value; copy.executable = $0; return .runProcess(copy) }); StructuredArgumentEditor(executable: value.executable, arguments: argumentsBinding(selection)); TextField("Working directory", text: payload(selection, value.workingDirectory ?? "") { var copy = value; copy.workingDirectory = $0.isEmpty ? nil : $0; return .runProcess(copy) }) }
    private func argumentsBinding(_ selection: ActionSelection) -> Binding<[String]> { .init(get: { guard let action = action(for: selection) else { return [] }; switch action { case .runProcess(let value): return value.arguments; case .managedProcess(let value): return value.arguments; default: return [] } }, set: { arguments in guard let action = action(for: selection) else { return }; switch action { case .runProcess(var value): value.arguments = arguments; replace(selection, with: .runProcess(value)); case .managedProcess(var value): value.arguments = arguments; replace(selection, with: .managedProcess(value)); default: break } }) }
    private func payload(_ selection: ActionSelection, _ value: String, update: @escaping (String) -> SceneAction) -> Binding<String> { .init(get: { value }, set: { replace(selection, with: update($0)) }) }

    private func addMenu(deactivation: Bool) -> some View { Menu("Add Action", systemImage: "plus") { add("Open Application", .openApplication(.init(bundleIdentifier: "com.apple.TextEdit")), deactivation); add("Browser Workspace", .openURL(.init(url: "https://example.com")), deactivation); add("Open File or Folder", .openFile(.init(path: "/")), deactivation); add("One-Shot Process", .runProcess(.init(executable: "/usr/bin/printf")), deactivation); add("Managed Process", .managedProcess(.init(executable: "/bin/sleep", singleInstanceKey: UUID().uuidString)), deactivation); add("Wait", .wait(.init(durationSeconds: 1)), deactivation); add("Editor Workspace", .editorWorkspace(.init(editor: .visualStudioCode, projectPath: "/")), deactivation); add("Terminal Workspace", .terminalWorkspace(.init(workingDirectory: "/")), deactivation); add("Docker Compose", .dockerCompose(.init(projectDirectory: "/")), deactivation); add("macOS Shortcut", .shortcut(.init(name: "")), deactivation) } }
    private func add(_ title: String, _ action: SceneAction, _ deactivation: Bool) -> some View { Button(title) { let configured = executionDefaults.applying(to: action); if deactivation { draft.deactivationActions.append(configured); selection = .stop(configured.id) } else { draft.actions.append(configured); selection = .start(configured.id) } } }
    private func actionSymbol(_ action: SceneAction) -> String { switch action { case .openApplication: "app"; case .openURL: "safari"; case .openFile: "folder"; case .runProcess: "terminal"; case .managedProcess: "server.rack"; case .wait: "timer"; case .editorWorkspace: "chevron.left.forwardslash.chevron.right"; case .terminalWorkspace: "macwindow"; case .dockerCompose: "shippingbox"; case .shortcut: "bolt.square"; case .windowLayout: "rectangle.on.rectangle" } }
}

private struct StructuredArgumentEditor: View {
    let executable: String
    @Binding var arguments: [String]
    @State private var selectedIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Structured Arguments").font(.headline)
                Spacer()
                Button("Add Argument", systemImage: "plus") { arguments.append(""); selectedIndex = arguments.count - 1 }
                Button("Remove", role: .destructive) { removeSelected() }.disabled(validSelection == nil)
                Button("Move Up", systemImage: "arrow.up") { move(-1) }.disabled((validSelection ?? 0) <= 0)
                Button("Move Down", systemImage: "arrow.down") { move(1) }.disabled(validSelection == nil || validSelection == arguments.count - 1)
            }
            ForEach(arguments.indices, id: \.self) { index in
                Button {
                    selectedIndex = index
                } label: {
                    HStack(alignment: .firstTextBaseline) {
                        Text("[\(index)]").font(.caption.monospaced()).foregroundStyle(.secondary)
                        Text(argumentLabel(arguments[index])).font(.body.monospaced()).lineLimit(2)
                        Spacer()
                        if selectedIndex == index { Image(systemName: "checkmark.circle.fill").foregroundStyle(ObsidianTokens.activeCyan) }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Argument \(index + 1), \(argumentLabel(arguments[index]))")
                Divider()
            }
            if let index = validSelection {
                Text("Argument \(index + 1) — exact boundary").font(.caption.bold())
                TextEditor(text: selectedArgumentBinding(index)).font(.body.monospaced()).frame(minHeight: 70).overlay(RoundedRectangle(cornerRadius: 5).stroke(.quaternary)).accessibilityIdentifier("sceneEditor.argumentValue")
                Text("Empty, whitespace-only, and multiline values remain one argument. Tabs and newlines are preserved exactly.").font(.caption).foregroundStyle(.secondary)
            } else if arguments.isEmpty {
                Text("No arguments. Add one to create an explicit array element.").font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Safe executable + argument-array preview").font(.caption.bold())
                Text(preview).font(.caption.monospaced()).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                Button("Copy Structured Preview", systemImage: "doc.on.doc") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(preview, forType: .string) }
                    .accessibilityIdentifier("sceneEditor.copyArgumentPreview")
                Text("This JSON preview is not shell syntax and is never executed as a command string.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
        .accessibilityIdentifier("sceneEditor.structuredArguments")
        .onChange(of: arguments.count) { _, count in if let selectedIndex, selectedIndex >= count { self.selectedIndex = count > 0 ? count - 1 : nil } }
    }

    private var validSelection: Int? { guard let selectedIndex, arguments.indices.contains(selectedIndex) else { return nil }; return selectedIndex }
    private func selectedArgumentBinding(_ index: Int) -> Binding<String> { .init(get: { arguments.indices.contains(index) ? arguments[index] : "" }, set: { if arguments.indices.contains(index) { arguments[index] = $0 } }) }
    private func removeSelected() { guard let index = validSelection else { return }; arguments.remove(at: index); selectedIndex = arguments.isEmpty ? nil : min(index, arguments.count - 1) }
    private func move(_ offset: Int) { guard let index = validSelection else { return }; let destination = index + offset; guard arguments.indices.contains(destination) else { return }; arguments.swapAt(index, destination); selectedIndex = destination }
    private func argumentLabel(_ value: String) -> String { if value.isEmpty { return "⟦empty string⟧" }; if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "⟦whitespace: \(value.debugDescription)⟧" }; return value.replacingOccurrences(of: "\n", with: "↵") }
    private var preview: String { let value = Preview(executable: executable, arguments: arguments); let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]; return (try? encoder.encode(value)).map { String(decoding: $0, as: UTF8.self) } ?? "Preview unavailable" }
    private struct Preview: Codable { let executable: String; let arguments: [String] }
}

private struct HealthCheckEditor: View {
    @Binding var check: HealthCheck
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(kind, systemImage: "waveform.path.ecg")
                Spacer()
                Toggle("Required", isOn: requiredBinding).toggleStyle(.switch)
                Button("Remove", role: .destructive, action: remove)
            }
            switch check {
            case .http:
                TextField("HTTP(S) URL", text: field({ if case .http(let value) = $0 { value.url } else { "" } }, { check, newValue in if case .http(var value) = check { value.url = newValue; check = .http(value) } }))
                Picker("Method", selection: field({ if case .http(let value) = $0 { value.method } else { HTTPMethod.get } }, { check, newValue in if case .http(var value) = check { value.method = newValue; check = .http(value) } })) { ForEach(HTTPMethod.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                HStack { TextField("Minimum status", value: field({ if case .http(let value) = $0 { value.expectedStatus.lowerBound } else { 200 } }, { check, newValue in if case .http(var value) = check { value.expectedStatus = newValue...max(newValue, value.expectedStatus.upperBound); check = .http(value) } }), format: .number); TextField("Maximum status", value: field({ if case .http(let value) = $0 { value.expectedStatus.upperBound } else { 299 } }, { check, newValue in if case .http(var value) = check { value.expectedStatus = min(newValue, value.expectedStatus.lowerBound)...newValue; check = .http(value) } }), format: .number) }
                TextField("Bounded response must contain (optional)", text: field({ if case .http(let value) = $0 { value.responseContains ?? "" } else { "" } }, { check, newValue in if case .http(var value) = check { value.responseContains = newValue.isEmpty ? nil : newValue; check = .http(value) } }))
            case .tcp:
                TextField("Host", text: field({ if case .tcp(let value) = $0 { value.host } else { "" } }, { check, newValue in if case .tcp(var value) = check { value.host = newValue; check = .tcp(value) } }))
                TextField("Port", value: field({ if case .tcp(let value) = $0 { value.port } else { 8080 } }, { check, newValue in if case .tcp(var value) = check { value.port = newValue; check = .tcp(value) } }), format: .number)
            case .process:
                TextField("Managed process action ID", text: field({ if case .process(let value) = $0 { value.actionID } else { "" } }, { check, newValue in if case .process(var value) = check { value.actionID = newValue; check = .process(value) } }))
            case .application:
                TextField("Application bundle identifier", text: field({ if case .application(let value) = $0 { value.bundleIdentifier } else { "" } }, { check, newValue in if case .application(var value) = check { value.bundleIdentifier = newValue; check = .application(value) } }))
            case .file:
                TextField("Absolute file or directory path", text: field({ if case .file(let value) = $0 { value.path } else { "" } }, { check, newValue in if case .file(var value) = check { value.path = newValue; check = .file(value) } }))
                Picker("Expected type", selection: fileKindBinding) { Text("File or directory").tag("either"); Text("File").tag("file"); Text("Directory").tag("directory") }
                TextField("Modified within seconds (optional)", text: optionalFileAgeBinding)
            case .docker:
                TextField("Docker Compose action/project ID", text: field({ if case .docker(let value) = $0 { value.composeActionID } else { "" } }, { check, newValue in if case .docker(var value) = check { value.composeActionID = newValue; check = .docker(value) } }))
                TextField("Docker service", text: field({ if case .docker(let value) = $0 { value.service } else { "" } }, { check, newValue in if case .docker(var value) = check { value.service = newValue; check = .docker(value) } }))
                Toggle("Require Docker healthy status", isOn: field({ if case .docker(let value) = $0 { value.requireHealthy } else { true } }, { check, newValue in if case .docker(var value) = check { value.requireHealthy = newValue; check = .docker(value) } }))
            }
            HStack {
                TextField("Timeout seconds", value: timeoutBinding, format: .number)
                TextField("Interval seconds", value: intervalBinding, format: .number)
                Stepper("Attempts: \(maximumAttemptsBinding.wrappedValue)", value: maximumAttemptsBinding, in: 1...100)
            }
            Text("Check ID: \(check.id)").font(.caption2.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
        }
        .padding(.vertical, 6)
    }

    private var kind: String { switch check { case .http: "HTTP readiness"; case .tcp: "TCP readiness"; case .process: "Managed-process readiness"; case .application: "Application readiness"; case .file: "File or directory readiness"; case .docker: "Docker service readiness" } }
    private func field<Value>(_ get: @escaping (HealthCheck) -> Value, _ set: @escaping (inout HealthCheck, Value) -> Void) -> Binding<Value> { .init(get: { get(check) }, set: { newValue in set(&check, newValue) }) }
    private var requiredBinding: Binding<Bool> { field(\.isRequired) { check, value in switch check { case .http(var x): x.required = value; check = .http(x); case .tcp(var x): x.required = value; check = .tcp(x); case .process(var x): x.required = value; check = .process(x); case .application(var x): x.required = value; check = .application(x); case .file(var x): x.required = value; check = .file(x); case .docker(var x): x.required = value; check = .docker(x) } } }
    private var timeoutBinding: Binding<Double> { field({ switch $0 { case .http(let x): x.timeoutSeconds; case .tcp(let x): x.timeoutSeconds; case .process(let x): x.timeoutSeconds ?? 3; case .application(let x): x.timeoutSeconds ?? 3; case .file(let x): x.timeoutSeconds ?? 3; case .docker(let x): x.timeoutSeconds ?? 5 } }) { check, value in switch check { case .http(var x): x.timeoutSeconds = value; check = .http(x); case .tcp(var x): x.timeoutSeconds = value; check = .tcp(x); case .process(var x): x.timeoutSeconds = value; check = .process(x); case .application(var x): x.timeoutSeconds = value; check = .application(x); case .file(var x): x.timeoutSeconds = value; check = .file(x); case .docker(var x): x.timeoutSeconds = value; check = .docker(x) } } }
    private var intervalBinding: Binding<Double> { field({ switch $0 { case .http(let x): x.intervalSeconds; case .tcp(let x): x.intervalSeconds; case .process(let x): x.intervalSeconds ?? 1; case .application(let x): x.intervalSeconds ?? 1; case .file(let x): x.intervalSeconds ?? 1; case .docker(let x): x.intervalSeconds ?? 2 } }) { check, value in switch check { case .http(var x): x.intervalSeconds = value; check = .http(x); case .tcp(var x): x.intervalSeconds = value; check = .tcp(x); case .process(var x): x.intervalSeconds = value; check = .process(x); case .application(var x): x.intervalSeconds = value; check = .application(x); case .file(var x): x.intervalSeconds = value; check = .file(x); case .docker(var x): x.intervalSeconds = value; check = .docker(x) } } }
    private var maximumAttemptsBinding: Binding<Int> { field({ switch $0 { case .http(let x): x.maximumAttempts; case .tcp(let x): x.maximumAttempts; case .process(let x): x.maximumAttempts ?? 1; case .application(let x): x.maximumAttempts ?? 1; case .file(let x): x.maximumAttempts ?? 1; case .docker(let x): x.maximumAttempts ?? 15 } }) { check, value in switch check { case .http(var x): x.maximumAttempts = value; check = .http(x); case .tcp(var x): x.maximumAttempts = value; check = .tcp(x); case .process(var x): x.maximumAttempts = value; check = .process(x); case .application(var x): x.maximumAttempts = value; check = .application(x); case .file(var x): x.maximumAttempts = value; check = .file(x); case .docker(var x): x.maximumAttempts = value; check = .docker(x) } } }
    private var fileKindBinding: Binding<String> { field({ if case .file(let value) = $0 { value.mustBeDirectory.map { $0 ? "directory" : "file" } ?? "either" } else { "either" } }, { check, kind in if case .file(var value) = check { value.mustBeDirectory = kind == "either" ? nil : kind == "directory"; check = .file(value) } }) }
    private var optionalFileAgeBinding: Binding<String> { field({ if case .file(let value) = $0 { value.modifiedWithinSeconds.map { String($0) } ?? "" } else { "" } }, { check, text in if case .file(var value) = check { value.modifiedWithinSeconds = Double(text); check = .file(value) } }) }
}

private enum ActionSelection: Hashable { case start(String), stop(String) }

private extension SceneAction {
    func replacingConfiguration(_ value: ActionConfiguration) -> SceneAction { switch self { case .openApplication(var x): x.configuration = value; return .openApplication(x); case .openURL(var x): x.configuration = value; return .openURL(x); case .openFile(var x): x.configuration = value; return .openFile(x); case .runProcess(var x): x.configuration = value; return .runProcess(x); case .managedProcess(var x): x.configuration = value; return .managedProcess(x); case .wait(var x): x.configuration = value; return .wait(x); case .editorWorkspace(var x): x.configuration = value; return .editorWorkspace(x); case .terminalWorkspace(var x): x.configuration = value; return .terminalWorkspace(x); case .dockerCompose(var x): x.configuration = value; return .dockerCompose(x); case .shortcut(var x): x.configuration = value; return .shortcut(x); case .windowLayout(var x): x.configuration = value; return .windowLayout(x) } }
}
