import SceneCore
import SwiftUI

struct SceneEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SceneCore.Scene
    @State private var validationMessage: String?
    let save: (SceneCore.Scene) async -> Void

    init(scene: SceneCore.Scene, save: @escaping (SceneCore.Scene) async -> Void) {
        _draft = State(initialValue: scene)
        self.save = save
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Scene") {
                    TextField("Name", text: $draft.name)
                    TextField("Description (optional)", text: Binding(
                        get: { draft.description ?? "" },
                        set: { draft.description = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                }

                Section("Ordered Actions") {
                    if draft.actions.isEmpty {
                        Text("Add one of the three supported action types.").foregroundStyle(.secondary)
                    }
                    ForEach(Array(draft.actions.enumerated()), id: \.element.id) { index, action in
                        actionEditor(index: index, action: action)
                    }
                    .onDelete { draft.actions.remove(atOffsets: $0) }
                    .onMove { draft.actions.move(fromOffsets: $0, toOffset: $1) }

                    Menu("Add Action", systemImage: "plus") {
                        Button("Open Application") {
                            draft.actions.append(.openApplication(.init(bundleIdentifier: "com.apple.TextEdit")))
                        }
                        Button("Open URL") {
                            draft.actions.append(.openURL(.init(url: "https://example.com")))
                        }
                        Button("Run Process") {
                            draft.actions.append(.runProcess(.init(executable: "/usr/bin/printf", arguments: [""])))
                        }
                    }
                }
            }

            if let validationMessage {
                Text(validationMessage).foregroundStyle(.red).font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading).padding()
            }
            Divider()
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    do {
                        try SceneValidator.validate(draft)
                        validationMessage = nil
                        Task { await save(draft) }
                    } catch {
                        validationMessage = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle(draft.name)
    }

    @ViewBuilder
    private func actionEditor(index: Int, action: SceneAction) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(index + 1). \(action.displayName)").font(.headline)
                Spacer()
                Button {
                    draft.actions.swapAt(index, index - 1)
                } label: {
                    Image(systemName: "arrow.up")
                }
                .help("Move action earlier")
                .disabled(index == 0)
                .buttonStyle(.borderless)
                Button {
                    draft.actions.swapAt(index, index + 1)
                } label: {
                    Image(systemName: "arrow.down")
                }
                .help("Move action later")
                .disabled(index == draft.actions.count - 1)
                .buttonStyle(.borderless)
                Button(role: .destructive) { draft.actions.remove(at: index) } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            switch action {
            case .openApplication(let value):
                TextField("Bundle identifier", text: Binding(
                    get: { value.bundleIdentifier },
                    set: { draft.actions[index] = .openApplication(.init(id: value.id, bundleIdentifier: $0)) }
                ))
            case .openURL(let value):
                TextField("https://example.com", text: Binding(
                    get: { value.url },
                    set: { draft.actions[index] = .openURL(.init(id: value.id, url: $0)) }
                ))
            case .runProcess(let value):
                TextField("Absolute executable path", text: Binding(
                    get: { value.executable },
                    set: { newValue in
                        var updated = value
                        updated.executable = newValue
                        draft.actions[index] = .runProcess(updated)
                    }
                ))
                TextField("Arguments (one per line)", text: Binding(
                    get: { value.arguments.joined(separator: "\n") },
                    set: { newValue in
                        var updated = value
                        updated.arguments = newValue.components(separatedBy: "\n")
                        draft.actions[index] = .runProcess(updated)
                    }
                ), axis: .vertical)
                TextField("Working directory (optional)", text: Binding(
                    get: { value.workingDirectory ?? "" },
                    set: { newValue in
                        var updated = value
                        updated.workingDirectory = newValue.isEmpty ? nil : newValue
                        draft.actions[index] = .runProcess(updated)
                    }
                ))
                TextField("Timeout seconds (optional)", text: Binding(
                    get: { value.timeoutSeconds.map { String($0) } ?? "" },
                    set: { newValue in
                        var updated = value
                        updated.timeoutSeconds = newValue.isEmpty ? nil : Double(newValue)
                        draft.actions[index] = .runProcess(updated)
                    }
                ))
            }
        }
        .padding(.vertical, 8)
    }

}
