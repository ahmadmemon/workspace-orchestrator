import AppKit
import SwiftUI

@main
struct WorkspaceOrchestratorApp: App {
    @StateObject private var model = AppModel()
    @AppStorage("appearanceMode") private var appearanceMode = "Obsidian"

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: model)
        } label: {
            MenuBarLabel(symbol: menuBarSymbol)
        }
        .menuBarExtraStyle(.window)

        Window("Workspace Orchestrator", id: "dashboard") {
            Group {
                if ProcessInfo.processInfo.arguments.contains("--ui-show-settings") { SettingsView(model: model) }
                else { DashboardView(model: model).frame(minWidth: 980, minHeight: 680) }
            }
                .preferredColorScheme(appearanceMode == "System" ? nil : .dark)
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

private struct MenuBarLabel: View {
    @Environment(\.openWindow) private var openWindow
    @AppStorage("openDashboardAtLaunch") private var openDashboardAtLaunch = true
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .accessibilityLabel("Workspace Orchestrator")
            .task {
                if ProcessInfo.processInfo.arguments.contains("--ui-testing") || openDashboardAtLaunch {
                    openWindow(id: "dashboard")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
            }
    }
}
