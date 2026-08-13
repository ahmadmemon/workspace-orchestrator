import SceneCore
import SwiftUI

struct WorkspaceCoreView: View {
    let status: SceneRunStatus; let progress: Double; var compact = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @AppStorage("reduceCustomEffects") private var reduceCustomEffects = false
    @AppStorage("effectIntensity") private var effectIntensity = 0.65
    @AppStorage("workspaceCoreAnimationIntensity") private var animationIntensity = 0.65
    private var color: Color { switch status { case .ready: ObsidianTokens.success; case .readyWithWarnings: ObsidianTokens.warning; case .failed: ObsidianTokens.failure; case .cancelled, .interrupted, .stopped: ObsidianTokens.mutedText; default: ObsidianTokens.cyan } }
    private var active: Bool { status.isActive }
    var body: some View {
        ZStack {
            ForEach(0..<9, id: \.self) { index in
                Circle().trim(from: CGFloat(index) / 9 + 0.012, to: CGFloat(index + 1) / 9 - 0.018).stroke(index < Int(progress * 9) ? color : ObsidianTokens.border, style: .init(lineWidth: compact ? 3 : 7, lineCap: .round)).rotationEffect(.degrees(index.isMultiple(of: 2) ? 8 : -3)).padding(CGFloat(index % 3) * (compact ? 1 : 2))
            }
            Circle().stroke(ObsidianTokens.border.opacity(contrast == .increased ? 1 : 0.7), lineWidth: compact ? 1 : 2).padding(compact ? 12 : 28)
            Image(systemName: symbol).font(.system(size: compact ? 15 : 34, weight: .semibold)).foregroundStyle(color)
        }
        .frame(width: compact ? 54 : 190, height: compact ? 54 : 190)
        .shadow(color: active && !reduceCustomEffects && !reduceTransparency ? color.opacity(0.25 * effectIntensity) : .clear, radius: 16 * effectIntensity)
        .opacity(active && !reduceMotion && !reduceCustomEffects ? 1 - (0.08 * animationIntensity) : 1)
        .animation(reduceMotion || reduceCustomEffects || animationIntensity == 0 ? nil : .easeInOut(duration: 0.12 + 0.28 * animationIntensity), value: status)
        .accessibilityElement(children: .ignore).accessibilityLabel("Workspace Core").accessibilityValue("\(status.displayName), \(Int(progress * 100)) percent of actions complete")
    }
    private var symbol: String { switch status { case .ready: "checkmark"; case .readyWithWarnings: "exclamationmark"; case .failed: "xmark"; case .stopping, .stopped: "stop.fill"; case .cancelled, .interrupted: "pause.fill"; default: "square.grid.2x2.fill" } }
}

extension SceneRunStatus {
    var displayName: String { switch self { case .idle: "Offline"; case .preparing: "Preparing"; case .running: "Running"; case .checking: "Checking"; case .retrying: "Retrying"; case .ready: "Ready"; case .readyWithWarnings: "Ready with warnings"; case .failed: "Failed"; case .cancelling: "Cancelling"; case .cancelled: "Cancelled"; case .interrupted: "Interrupted"; case .stopping: "Stopping"; case .stopped: "Stopped" } }
    var symbol: String { switch self { case .ready: "checkmark.circle.fill"; case .readyWithWarnings: "exclamationmark.triangle.fill"; case .failed: "xmark.circle.fill"; case .cancelled, .interrupted: "pause.circle.fill"; case .stopping, .stopped: "stop.circle.fill"; default: "bolt.horizontal.circle.fill" } }
    var color: Color { switch self { case .ready: ObsidianTokens.success; case .readyWithWarnings: ObsidianTokens.warning; case .failed: ObsidianTokens.failure; case .cancelled, .interrupted, .stopped: ObsidianTokens.mutedText; default: ObsidianTokens.cyan } }
}
extension ActionRunStatus { var displayName: String { switch self { case .waitingForDependencies: "Waiting for dependencies"; case .succeededWithWarning: "Succeeded with warning"; default: rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized } } }
