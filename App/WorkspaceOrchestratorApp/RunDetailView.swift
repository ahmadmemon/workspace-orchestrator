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
                        if let retryReason = record.retryReason { Label(retryReason, systemImage: "arrow.clockwise").font(.caption).foregroundStyle(ObsidianTokens.warning) }
                        if let error = record.errorMessage { Text(error).foregroundStyle(ObsidianTokens.failure).textSelection(.enabled) }
                        if !record.attempts.isEmpty {
                            DisclosureGroup("Attempts (\(record.attempts.count))") {
                                ForEach(record.attempts) { attempt in
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack { Text("Attempt \(attempt.attempt)").font(.caption.bold()); Spacer(); Text(attempt.status.displayName).font(.caption); Text(attempt.endedAt.map { String(format: "%.2fs", $0.timeIntervalSince(attempt.startedAt)) } ?? "in progress").font(.caption.monospacedDigit()) }
                                        if let reason = attempt.reason { Text(reason).font(.caption).foregroundStyle(ObsidianTokens.secondaryText) }
                                        if let error = attempt.errorMessage { Text(error).font(.caption).foregroundStyle(ObsidianTokens.failure).textSelection(.enabled) }
                                    }.padding(.vertical, 3)
                                }
                            }.font(.caption)
                        }
                        if !record.healthChecks.isEmpty {
                            DisclosureGroup("Health checks (\(record.healthChecks.count))") {
                                ForEach(record.healthChecks) { check in
                                    HStack(alignment: .top) { Text("\(check.kind) #\(check.attempt)").font(.caption.monospaced()); Spacer(); Text(check.status.displayName).font(.caption); if let message = check.message { Text(message).font(.caption).foregroundStyle(ObsidianTokens.secondaryText).textSelection(.enabled) } }.padding(.vertical, 2)
                                }
                            }.font(.caption)
                        }
                        if let process = record.processResult {
                            DisclosureGroup("Process result") {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("exit \(process.exitCode) • \(String(format: "%.3fs", process.duration)) • timed out \(process.timedOut ? "yes" : "no") • cancelled \(process.cancelled ? "yes" : "no")").font(.caption.monospaced()).textSelection(.enabled)
                                    if !process.stdout.isEmpty { Text("stdout").font(.caption.bold()); Text(process.stdout).font(.system(.caption, design: .monospaced)).textSelection(.enabled) }
                                    if !process.stderr.isEmpty { Text("stderr").font(.caption.bold()); Text(process.stderr).font(.system(.caption, design: .monospaced)).foregroundStyle(ObsidianTokens.warning).textSelection(.enabled) }
                                    if record.outputTruncated == true { Label("Stored output was truncated by the configured per-action limit.", systemImage: "scissors").font(.caption).foregroundStyle(ObsidianTokens.warning) }
                                }.padding(8).background(ObsidianTokens.base, in: RoundedRectangle(cornerRadius: 6))
                            }.font(.caption)
                        }
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
