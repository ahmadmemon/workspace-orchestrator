import SceneCore
import SwiftUI

struct RunDetailView: View {
    let run: SceneRunResult
    let cancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(run.sceneName).font(.largeTitle.bold())
                        Label(run.status.displayName, systemImage: statusIcon(run.status))
                            .foregroundStyle(statusColor(run.status))
                    }
                    Spacer()
                    if run.status == .running {
                        Button("Cancel", role: .destructive, action: cancel)
                    }
                }

                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                    if let startedAt = run.startedAt {
                        GridRow { Text("Started").foregroundStyle(.secondary); Text(startedAt.formatted()) }
                    }
                    if let duration = run.duration {
                        GridRow { Text("Duration").foregroundStyle(.secondary); Text(duration.formattedDuration) }
                    }
                    if let current = run.currentAction {
                        GridRow { Text("Current action").foregroundStyle(.secondary); Text(current.name) }
                    }
                }

                if let error = run.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }

                Text("Actions").font(.title2.bold())
                ForEach(run.actionRecords) { record in
                    HStack(alignment: .top) {
                        Image(systemName: actionIcon(record.status))
                            .foregroundStyle(actionColor(record.status))
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.name).font(.headline)
                            Text(record.status.displayName).foregroundStyle(.secondary)
                            if let error = record.errorMessage {
                                Text(error).foregroundStyle(.red).textSelection(.enabled)
                            }
                            if let process = record.processResult {
                                if !process.stdout.isEmpty { output("stdout", process.stdout) }
                                if !process.stderr.isEmpty { output("stderr", process.stderr) }
                            }
                        }
                        Spacer()
                        if let duration = record.duration { Text(duration.formattedDuration).monospacedDigit() }
                    }
                    .padding()
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(28)
        }
    }

    private func output(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption.bold()).foregroundStyle(.secondary)
            Text(value).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
        }
    }

    private func statusIcon(_ status: SceneRunStatus) -> String {
        switch status {
        case .idle: "pause.circle"
        case .running: "play.circle.fill"
        case .succeeded: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .cancelled: "stop.circle.fill"
        }
    }

    private func statusColor(_ status: SceneRunStatus) -> Color {
        switch status { case .succeeded: .green; case .failed: .red; case .cancelled: .orange; default: .primary }
    }

    private func actionIcon(_ status: ActionRunStatus) -> String {
        switch status {
        case .pending: "circle"
        case .running: "circle.dotted"
        case .succeeded: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .cancelled: "stop.circle.fill"
        case .timedOut: "clock.badge.exclamationmark.fill"
        }
    }

    private func actionColor(_ status: ActionRunStatus) -> Color {
        switch status { case .succeeded: .green; case .failed, .timedOut: .red; case .cancelled: .orange; default: .secondary }
    }
}

private extension TimeInterval {
    var formattedDuration: String { formatted(.number.precision(.fractionLength(2))) + " s" }
}
