import AppKit
import SceneCore
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("Workspace Orchestrator")
            .font(.headline)

        if model.scenes.isEmpty {
            Text("No saved scenes")
                .foregroundStyle(.secondary)
        } else {
            Section("Available Scenes") {
                ForEach(model.scenes) { scene in
                    Button {
                        model.run(scene)
                    } label: {
                        Label(scene.name, systemImage: "play.fill")
                    }
                    .disabled(model.isRunning)
                }
            }
        }

        if let run = model.currentRun {
            Divider()
            Text("Status: \(run.status.displayName)")
            if let action = run.currentAction {
                Text("Current: \(action.name)")
            }
        }

        if model.isRunning {
            Button("Cancel Current Run", role: .destructive) {
                model.cancelCurrentRun()
            }
        }

        Divider()
        Button("Open Dashboard") {
            openWindow(id: "dashboard")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Manage Scenes / Settings") {
            openWindow(id: "dashboard")
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("Quit Workspace Orchestrator") { NSApp.terminate(nil) }
    }
}

extension SceneRunStatus {
    var displayName: String { rawValue.capitalized }
}

extension ActionRunStatus {
    var displayName: String {
        switch self {
        case .timedOut: "Timed Out"
        default: rawValue.capitalized
        }
    }
}
