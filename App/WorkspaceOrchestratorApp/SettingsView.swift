import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            LabeledContent("Storage", value: "Application Support/WorkspaceOrchestrator")
            LabeledContent("Saved scenes", value: "\(model.scenes.count)")
            Text("Milestone 1 uses local JSON storage and performs no synchronization or telemetry.")
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 480)
    }
}
