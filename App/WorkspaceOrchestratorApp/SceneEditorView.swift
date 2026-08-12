import SceneCore
import SwiftUI

struct SceneEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SceneCore.Scene
    @State private var selection: ActionSelection?
    @State private var validationMessage: String?
    let save: (SceneCore.Scene) async -> Void

    init(scene: SceneCore.Scene, save: @escaping (SceneCore.Scene) async -> Void) { _draft = State(initialValue: scene); self.save = save }
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Start Workspace") { ForEach(draft.actions) { action in Label(action.displayName, systemImage: actionSymbol(action)).tag(ActionSelection.start(action.id)) }.onMove { draft.actions.move(fromOffsets: $0, toOffset: $1) }.onDelete { draft.actions.remove(atOffsets: $0) }; addMenu(deactivation: false) }
                Section("Stop Workspace") { ForEach(draft.deactivationActions) { action in Label(action.displayName, systemImage: actionSymbol(action)).tag(ActionSelection.stop(action.id)) }.onMove { draft.deactivationActions.move(fromOffsets: $0, toOffset: $1) }.onDelete { draft.deactivationActions.remove(atOffsets: $0) }; addMenu(deactivation: true) }
            }.navigationSplitViewColumnWidth(min: 240, ideal: 280)
        } detail: {
            Form {
                Section("Scene") { TextField("Name", text: $draft.name); TextField("Description", text: Binding(get: { draft.description ?? "" }, set: { draft.description = $0.isEmpty ? nil : $0 }), axis: .vertical); TextField("SF Symbol", text: Binding(get: { draft.iconName ?? "" }, set: { draft.iconName = $0.isEmpty ? nil : $0 })); Toggle("Favorite", isOn: $draft.favorite); TextField("Tags, comma separated", text: Binding(get: { draft.tags.joined(separator: ", ") }, set: { draft.tags = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } })); Stepper("Maximum concurrency: \(draft.maximumConcurrency)", value: $draft.maximumConcurrency, in: 1...16) }
                if let selected = selectedAction { Section("Selected Action") { TextField("Action name", text: actionNameBinding(selected)); Toggle("Enabled", isOn: enabledBinding(selected)); Picker("Failure policy", selection: failureBinding(selected)) { Text("Stop scene").tag(FailurePolicy.stopScene); Text("Continue degraded").tag(FailurePolicy.continueDegraded); Text("Continue optional").tag(FailurePolicy.continueOptional); Text("Skip dependents").tag(FailurePolicy.skipDependents) }; TextField("Dependencies (IDs, comma separated)", text: dependencyBinding(selected)); payloadEditor(selected) } }
                if let validationMessage { Section { Text(validationMessage).foregroundStyle(ObsidianTokens.failure).textSelection(.enabled) } }
            }.formStyle(.grouped)
        }
        .toolbar { ToolbarItemGroup(placement: .confirmationAction) { Button("Cancel") { dismiss() }; Button("Save") { do { try SceneValidator.validate(draft); validationMessage = nil; Task { await save(draft) } } catch { validationMessage = error.localizedDescription } }.buttonStyle(.borderedProminent) } }
        .navigationTitle(draft.name)
    }

    private var selectedAction: ActionSelection? { selection }
    private func action(for selection: ActionSelection) -> SceneAction? { switch selection { case .start(let id): draft.actions.first { $0.id == id }; case .stop(let id): draft.deactivationActions.first { $0.id == id } } }
    private func replace(_ selection: ActionSelection, with action: SceneAction) { switch selection { case .start(let id): if let index = draft.actions.firstIndex(where: { $0.id == id }) { draft.actions[index] = action }; case .stop(let id): if let index = draft.deactivationActions.firstIndex(where: { $0.id == id }) { draft.deactivationActions[index] = action } } }
    private func updateConfiguration(_ selection: ActionSelection, _ body: (inout ActionConfiguration) -> Void) { guard let action = action(for: selection) else { return }; var configuration = action.configuration; body(&configuration); replace(selection, with: action.replacingConfiguration(configuration)) }
    private func actionNameBinding(_ selection: ActionSelection) -> Binding<String> { .init(get: { action(for: selection)?.configuration.name ?? "" }, set: { value in updateConfiguration(selection) { $0.name = value.isEmpty ? nil : value } }) }
    private func enabledBinding(_ selection: ActionSelection) -> Binding<Bool> { .init(get: { action(for: selection)?.configuration.enabled ?? true }, set: { value in updateConfiguration(selection) { $0.enabled = value } }) }
    private func failureBinding(_ selection: ActionSelection) -> Binding<FailurePolicy> { .init(get: { action(for: selection)?.configuration.failurePolicy ?? .stopScene }, set: { value in updateConfiguration(selection) { $0.failurePolicy = value } }) }
    private func dependencyBinding(_ selection: ActionSelection) -> Binding<String> { .init(get: { action(for: selection)?.configuration.dependencies.joined(separator: ", ") ?? "" }, set: { value in updateConfiguration(selection) { $0.dependencies = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } } }) }

    @ViewBuilder private func payloadEditor(_ selection: ActionSelection) -> some View {
        if let action = action(for: selection) {
            switch action {
            case .openApplication(let value): TextField("Bundle identifier", text: payload(selection, value.bundleIdentifier) { var copy = value; copy.bundleIdentifier = $0; return .openApplication(copy) })
            case .openURL(let value): TextField("HTTP(S) URL", text: payload(selection, value.url) { var copy = value; copy.url = $0; return .openURL(copy) })
            case .openFile(let value): TextField("Absolute file or folder path", text: payload(selection, value.path) { var copy = value; copy.path = $0; return .openFile(copy) })
            case .runProcess(let value): processFields(selection, value: value)
            case .managedProcess(let value): TextField("Absolute executable", text: payload(selection, value.executable) { var copy = value; copy.executable = $0; return .managedProcess(copy) }); TextField("Single-instance key", text: payload(selection, value.singleInstanceKey) { var copy = value; copy.singleInstanceKey = $0; return .managedProcess(copy) })
            case .wait(let value): TextField("Message", text: payload(selection, value.message) { var copy = value; copy.message = $0; return .wait(copy) }); TextField("Duration seconds", value: Binding(get: { value.durationSeconds }, set: { var copy = value; copy.durationSeconds = $0; replace(selection, with: .wait(copy)) }), format: .number)
            case .editorWorkspace(let value): TextField("Project or workspace path", text: payload(selection, value.projectPath) { var copy = value; copy.projectPath = $0; return .editorWorkspace(copy) })
            case .terminalWorkspace(let value): TextField("Working directory", text: payload(selection, value.workingDirectory) { var copy = value; copy.workingDirectory = $0; return .terminalWorkspace(copy) }); TextField("tmux session (optional)", text: payload(selection, value.tmuxSessionName ?? "") { var copy = value; copy.tmuxSessionName = $0.isEmpty ? nil : $0; return .terminalWorkspace(copy) })
            case .dockerCompose(let value): TextField("Compose project directory", text: payload(selection, value.projectDirectory) { var copy = value; copy.projectDirectory = $0; return .dockerCompose(copy) }); Toggle("Build images", isOn: Binding(get: { value.build }, set: { var copy = value; copy.build = $0; replace(selection, with: .dockerCompose(copy)) }))
            case .shortcut(let value): TextField("Shortcut name", text: payload(selection, value.name) { var copy = value; copy.name = $0; return .shortcut(copy) })
            case .windowLayout(let value): LabeledContent("Reviewed placements", value: "\(value.placements.count)"); Text("Window layouts are edited through Capture Workspace to preserve matching confidence and display mapping.").foregroundStyle(.secondary)
            }
        }
    }
    @ViewBuilder private func processFields(_ selection: ActionSelection, value: RunProcessAction) -> some View { TextField("Absolute executable", text: payload(selection, value.executable) { var copy = value; copy.executable = $0; return .runProcess(copy) }); TextField("Arguments, one per line", text: payload(selection, value.arguments.joined(separator: "\n")) { var copy = value; copy.arguments = $0.components(separatedBy: "\n"); return .runProcess(copy) }, axis: .vertical); TextField("Working directory", text: payload(selection, value.workingDirectory ?? "") { var copy = value; copy.workingDirectory = $0.isEmpty ? nil : $0; return .runProcess(copy) }) }
    private func payload(_ selection: ActionSelection, _ value: String, update: @escaping (String) -> SceneAction) -> Binding<String> { .init(get: { guard let current = action(for: selection) else { return value }; return current.payloadString(fallback: value) }, set: { replace(selection, with: update($0)) }) }

    private func addMenu(deactivation: Bool) -> some View { Menu("Add Action", systemImage: "plus") { add("Open Application", .openApplication(.init(bundleIdentifier: "com.apple.TextEdit")), deactivation); add("Browser Workspace", .openURL(.init(url: "https://example.com")), deactivation); add("Open File or Folder", .openFile(.init(path: "/")), deactivation); add("One-Shot Process", .runProcess(.init(executable: "/usr/bin/printf")), deactivation); add("Managed Process", .managedProcess(.init(executable: "/bin/sleep", singleInstanceKey: UUID().uuidString)), deactivation); add("Wait", .wait(.init(durationSeconds: 1)), deactivation); add("Editor Workspace", .editorWorkspace(.init(editor: .visualStudioCode, projectPath: "/")), deactivation); add("Terminal Workspace", .terminalWorkspace(.init(workingDirectory: "/")), deactivation); add("Docker Compose", .dockerCompose(.init(projectDirectory: "/")), deactivation); add("macOS Shortcut", .shortcut(.init(name: "")), deactivation) } }
    private func add(_ title: String, _ action: SceneAction, _ deactivation: Bool) -> some View { Button(title) { if deactivation { draft.deactivationActions.append(action); selection = .stop(action.id) } else { draft.actions.append(action); selection = .start(action.id) } } }
    private func actionSymbol(_ action: SceneAction) -> String { switch action { case .openApplication: "app"; case .openURL: "safari"; case .openFile: "folder"; case .runProcess: "terminal"; case .managedProcess: "server.rack"; case .wait: "timer"; case .editorWorkspace: "chevron.left.forwardslash.chevron.right"; case .terminalWorkspace: "macwindow"; case .dockerCompose: "shippingbox"; case .shortcut: "bolt.square"; case .windowLayout: "rectangle.on.rectangle" } }
}

private enum ActionSelection: Hashable { case start(String), stop(String) }

private extension SceneAction {
    func replacingConfiguration(_ value: ActionConfiguration) -> SceneAction { switch self { case .openApplication(var x): x.configuration = value; return .openApplication(x); case .openURL(var x): x.configuration = value; return .openURL(x); case .openFile(var x): x.configuration = value; return .openFile(x); case .runProcess(var x): x.configuration = value; return .runProcess(x); case .managedProcess(var x): x.configuration = value; return .managedProcess(x); case .wait(var x): x.configuration = value; return .wait(x); case .editorWorkspace(var x): x.configuration = value; return .editorWorkspace(x); case .terminalWorkspace(var x): x.configuration = value; return .terminalWorkspace(x); case .dockerCompose(var x): x.configuration = value; return .dockerCompose(x); case .shortcut(var x): x.configuration = value; return .shortcut(x); case .windowLayout(var x): x.configuration = value; return .windowLayout(x) } }
    func payloadString(fallback: String) -> String { switch self { case .openApplication(let x): x.bundleIdentifier; case .openURL(let x): x.url; case .openFile(let x): x.path; case .runProcess(let x): fallback.contains("\n") ? x.arguments.joined(separator: "\n") : (fallback.hasPrefix("/") && fallback != x.executable ? x.workingDirectory ?? "" : x.executable); case .managedProcess(let x): fallback.hasPrefix("/") ? x.executable : x.singleInstanceKey; case .wait(let x): x.message; case .editorWorkspace(let x): x.projectPath; case .terminalWorkspace(let x): fallback.hasPrefix("/") ? x.workingDirectory : x.tmuxSessionName ?? ""; case .dockerCompose(let x): x.projectDirectory; case .shortcut(let x): x.name; case .windowLayout: fallback } }
}
