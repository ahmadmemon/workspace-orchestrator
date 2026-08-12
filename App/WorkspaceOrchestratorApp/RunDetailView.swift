import SceneCore
import SwiftUI

struct RunDetailView: View {
    let run: SceneRunResult
    let cancel: () -> Void
    private var progress: Double { run.actionRecords.isEmpty ? 0 : Double(run.completedActionCount) / Double(run.actionRecords.count) }
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 22) { WorkspaceCoreView(status: run.status, progress: progress); VStack(alignment: .leading, spacing: 8) { Text(run.sceneName).font(.largeTitle.bold()); StatusBadge(text: run.status.displayName, color: run.status.color, symbol: run.status.symbol); if let error = run.errorMessage { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(ObsidianTokens.failure).textSelection(.enabled) } }; Spacer(); if run.status.isActive { Button("Cancel", role: .destructive, action: cancel) } }.obsidianPanel()
            HStack { LabeledContent("Started", value: run.startedAt?.formatted() ?? "—"); LabeledContent("Duration", value: run.duration.map { String(format: "%.2f s", $0) } ?? "—"); LabeledContent("Actions", value: "\(run.completedActionCount)/\(run.actionRecords.count)") }.font(.callout).monospacedDigit().obsidianPanel()
            Text("Action Timeline").font(.title2.bold())
            ForEach(run.actionRecords) { record in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: symbol(record.status)).foregroundStyle(color(record.status)).frame(width: 24)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack { Text(record.name).font(.headline); Spacer(); Text(record.status.displayName).font(.caption.weight(.semibold)).foregroundStyle(color(record.status)) }
                        if let state = record.dependencyState { Text(state).font(.caption).foregroundStyle(ObsidianTokens.secondaryText) }
                        if let reason = record.skipReason { Text(reason).foregroundStyle(ObsidianTokens.warning) }
                        if let error = record.errorMessage { Text(error).foregroundStyle(ObsidianTokens.failure).textSelection(.enabled) }
                        if !record.attempts.isEmpty { Text("\(record.attempts.count) attempt\(record.attempts.count == 1 ? "" : "s")").font(.caption.monospaced()).foregroundStyle(ObsidianTokens.mutedText) }
                        if let output = record.outputSummary, !output.isEmpty { Text(output).font(.system(.caption, design: .monospaced)).textSelection(.enabled).padding(8).background(ObsidianTokens.base, in: RoundedRectangle(cornerRadius: 6)) }
                    }
                    if let duration = record.duration { Text(String(format: "%.2fs", duration)).font(.caption.monospacedDigit()).foregroundStyle(ObsidianTokens.mutedText) }
                }.obsidianPanel().accessibilityIdentifier("run.action.\(record.id)")
            }
        }.padding(28) }
    }
    private func symbol(_ status: ActionRunStatus) -> String { switch status { case .succeeded: "checkmark.circle.fill"; case .succeededWithWarning: "exclamationmark.circle.fill"; case .failed, .timedOut: "xmark.circle.fill"; case .cancelled, .interrupted: "pause.circle.fill"; case .skipped: "forward.end.circle"; case .stopped: "stop.circle.fill"; default: "circle.dotted" } }
    private func color(_ status: ActionRunStatus) -> Color { switch status { case .succeeded: ObsidianTokens.success; case .succeededWithWarning, .skipped: ObsidianTokens.warning; case .failed, .timedOut: ObsidianTokens.failure; default: ObsidianTokens.cyan } }
}
