import SceneCore
import SwiftUI

struct ProcessApprovalView: View {
    @ObservedObject var model: AppModel
    let request: ProcessApprovalRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(ObsidianTokens.warning)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(request.requiresImportTrustReview ? "Review Imported Scene" : "Approve Executable Actions")
                        .font(.title2.bold())
                    Text("Nothing runs until you approve this exact configuration. Secret values are never shown or included in the fingerprint.")
                        .foregroundStyle(ObsidianTokens.secondaryText)
                }
            }

            if request.requiresImportTrustReview {
                Label("“\(request.scene.name)” was imported and remains untrusted until you explicitly trust it.", systemImage: "shippingbox.and.arrow.backward")
                    .foregroundStyle(ObsidianTokens.warning)
                    .obsidianPanel()
            }

            if request.actions.isEmpty {
                Text("No new executable configuration needs approval. Review the scene in the builder before trusting the import.")
                    .foregroundStyle(ObsidianTokens.secondaryText)
                    .obsidianPanel()
            } else {
                List(request.actions) { action in
                    if let details = action.processApprovalDetails {
                        ApprovalActionRow(name: action.displayName, details: details)
                            .listRowBackground(ObsidianTokens.panel)
                    }
                }
                .scrollContentBackground(.hidden)
            }

            HStack {
                Button("Cancel", role: .cancel) { model.cancelPendingRun() }
                Spacer()
                Button("Approve Once") { Task { await model.approvePendingRun(scope: .once, trustImportedScene: false) } }
                    .disabled(request.actions.isEmpty && !request.requiresImportTrustReview)
                Button(request.requiresImportTrustReview ? "Trust Scene & Approve Exact" : "Approve Exact Actions") {
                    Task { await model.approvePendingRun(scope: .exactAction, trustImportedScene: request.requiresImportTrustReview) }
                }
                .buttonStyle(.borderedProminent)
                .tint(ObsidianTokens.activeCyan)
            }
        }
        .padding(24)
        .frame(minWidth: 720, minHeight: 520)
        .background(ObsidianTokens.base)
        .foregroundStyle(ObsidianTokens.primaryText)
        .accessibilityIdentifier("processApprovalSheet")
    }
}

private struct ApprovalActionRow: View {
    let name: String
    let details: ProcessApprovalDetails

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Text(name).font(.headline); Spacer(); StatusBadge(text: details.kind, color: ObsidianTokens.warning, symbol: "terminal") }
            approvalLine("Executable", details.executable)
            approvalLine("Arguments", details.arguments.isEmpty ? "None" : details.arguments.map(quoted).joined(separator: " "))
            approvalLine("Working directory", details.workingDirectory ?? "Default")
            approvalLine("Environment names", details.environmentNames.isEmpty ? "None" : details.environmentNames.joined(separator: ", "))
            approvalLine("Timeout", details.timeout.map { "\($0) seconds" } ?? "Action default")
            approvalLine("Retry", "\(details.retryPolicy.strategy.rawValue), maximum \(details.retryPolicy.maximumAttempts) attempt(s)")
            approvalLine("Resource", details.managed ? "Managed" : "One shot")
            if let stop = details.stopBehavior { approvalLine("Stop behavior", stop) }
        }
        .padding(.vertical, 8)
    }

    private func approvalLine(_ label: String, _ value: String) -> some View {
        LabeledContent(label) { Text(value).font(.caption.monospaced()).textSelection(.enabled).multilineTextAlignment(.trailing) }
    }

    private func quoted(_ value: String) -> String { "\"\(value)\"" }
}
