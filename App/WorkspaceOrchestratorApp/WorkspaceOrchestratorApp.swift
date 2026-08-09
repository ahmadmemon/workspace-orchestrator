import AppKit
import SwiftUI

@main
struct WorkspaceOrchestratorApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Workspace Orchestrator", systemImage: model.isRunning ? "play.circle.fill" : "square.grid.2x2") {
            MenuBarContentView(model: model)
        }
        .menuBarExtraStyle(.menu)

        Window("Workspace Orchestrator", id: "dashboard") {
            DashboardView(model: model)
                .frame(minWidth: 760, minHeight: 520)
        }
        .defaultSize(width: 900, height: 640)

        Settings {
            SettingsView(model: model)
        }
    }
}
