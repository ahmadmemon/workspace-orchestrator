import AppKit
import SwiftUI

@main
struct WorkspaceOrchestratorApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Workspace Orchestrator", systemImage: menuBarSymbol) {
            MenuBarContentView(model: model)
        }
        .menuBarExtraStyle(.window)

        Window("Workspace Orchestrator", id: "dashboard") {
            DashboardView(model: model)
                .frame(minWidth: 980, minHeight: 680)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1180, height: 780)

        Settings {
            SettingsView(model: model)
        }
    }

    private var menuBarSymbol: String {
        switch model.currentRun?.status {
        case .preparing, .running, .checking, .retrying, .stopping: "square.grid.2x2.fill"
        case .ready: "checkmark.square.fill"
        case .readyWithWarnings: "exclamationmark.square.fill"
        case .failed: "xmark.square.fill"
        default: "square.grid.2x2"
        }
    }
}
