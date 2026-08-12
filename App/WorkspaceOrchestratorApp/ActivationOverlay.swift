import SceneCore
import SwiftUI

struct ActivationOverlay: View {
    let run: SceneRunResult; let cancel: () -> Void; let dismiss: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private var progress: Double { run.actionRecords.isEmpty ? 0 : Double(run.completedActionCount) / Double(run.actionRecords.count) }
    var body: some View {
        VStack(spacing: 18) {
            WorkspaceCoreView(status: run.status, progress: progress)
            Text(run.sceneName).font(.title.bold())
            StatusBadge(text: run.status.displayName, color: run.status.color, symbol: run.status.symbol)
            if let current = run.currentAction { Text(current.name).foregroundStyle(ObsidianTokens.secondaryText) }
            ProgressView(value: progress).tint(run.status.color).frame(width: 300).accessibilityLabel("Action progress")
            HStack { if run.status.isActive { Button("Cancel", role: .destructive, action: cancel) }; Button("Open Dashboard", action: dismiss) }
        }.padding(32).frame(width: 460).background(reduceTransparency ? AnyShapeStyle(ObsidianTokens.elevated) : AnyShapeStyle(.regularMaterial), in: RoundedRectangle(cornerRadius: ObsidianTokens.Radius.overlay)).overlay(RoundedRectangle(cornerRadius: ObsidianTokens.Radius.overlay).stroke(ObsidianTokens.border)).shadow(color: .black.opacity(0.45), radius: 30).accessibilityElement(children: .contain)
    }
}
