import SceneCore
import SwiftUI

struct DashboardView: View {
    @ObservedObject var model: AppModel
    @State private var editingScene: SceneCore.Scene?
    @State private var scenePendingDeletion: SceneCore.Scene?

    var body: some View {
        NavigationSplitView {
            sceneList
                .navigationSplitViewColumnWidth(min: 260, ideal: 300)
        } detail: {
            if let run = model.currentRun {
                RunDetailView(run: run, cancel: model.cancelCurrentRun)
            } else {
                ContentUnavailableView(
                    "Ready for a Scene",
                    systemImage: "square.grid.2x2",
                    description: Text("Choose Run beside a saved scene. Actions execute in order and stop on the first failure.")
                )
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    editingScene = Scene(name: "New Scene")
                } label: {
                    Label("New Scene", systemImage: "plus")
                }
                Button {
                    Task { await model.installDemoScene() }
                } label: {
                    Label("Install Demo Scene", systemImage: "shippingbox")
                }
            }
        }
        .sheet(item: $editingScene) { scene in
            SceneEditorView(scene: scene) { saved in
                if await model.save(saved) { editingScene = nil }
            }
            .frame(minWidth: 620, minHeight: 560)
        }
        .confirmationDialog(
            "Delete this scene?",
            isPresented: Binding(
                get: { scenePendingDeletion != nil },
                set: { if !$0 { scenePendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: scenePendingDeletion
        ) { scene in
            Button("Delete “\(scene.name)”", role: .destructive) {
                Task { await model.delete(scene) }
            }
            Button("Cancel", role: .cancel) { }
        } message: { _ in
            Text("This cannot be undone.")
        }
        .alert("Workspace Orchestrator", isPresented: Binding(
            get: { model.presentedError != nil },
            set: { if !$0 { model.presentedError = nil } }
        )) {
            Button("OK") { model.presentedError = nil }
        } message: {
            Text(model.presentedError ?? "Unknown error")
        }
    }

    private var sceneList: some View {
        List {
            Section("Saved Scenes") {
                if model.isLoading {
                    ProgressView()
                } else if model.scenes.isEmpty {
                    Text("No scenes yet")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.scenes) { scene in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(scene.name).font(.headline)
                        if let description = scene.description, !description.isEmpty {
                            Text(description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Text("\(scene.actions.count) action\(scene.actions.count == 1 ? "" : "s")")
                            .font(.caption2).foregroundStyle(.secondary)
                        HStack {
                            Button("Run") { model.run(scene) }
                                .buttonStyle(.borderedProminent)
                                .disabled(model.isRunning)
                            Button("Edit") { editingScene = scene }
                            Button("Delete", role: .destructive) { scenePendingDeletion = scene }
                        }
                        .controlSize(.small)
                    }
                    .padding(.vertical, 5)
                }
            }
        }
    }
}
