import SwiftUI

enum ObsidianTokens {
    static let base = Color(red: 10/255, green: 13/255, blue: 17/255)
    static let elevated = Color(red: 17/255, green: 22/255, blue: 28/255)
    static let panel = Color(red: 22/255, green: 29/255, blue: 37/255)
    static let secondaryPanel = Color(red: 27/255, green: 35/255, blue: 44/255)
    static let border = Color(red: 41/255, green: 53/255, blue: 65/255)
    static let primaryText = Color(red: 244/255, green: 248/255, blue: 251/255)
    static let secondaryText = Color(red: 170/255, green: 183/255, blue: 196/255)
    static let mutedText = Color(red: 113/255, green: 128/255, blue: 142/255)
    static let cyan = Color(red: 94/255, green: 215/255, blue: 1)
    static let activeCyan = Color(red: 46/255, green: 185/255, blue: 240/255)
    static let success = Color(red: 80/255, green: 216/255, blue: 144/255)
    static let warning = Color(red: 242/255, green: 185/255, blue: 92/255)
    static let failure = Color(red: 1, green: 107/255, blue: 120/255)
    static let info = Color(red: 119/255, green: 168/255, blue: 1)
    enum Spacing { static let xxs: CGFloat = 4; static let xs: CGFloat = 8; static let sm: CGFloat = 12; static let md: CGFloat = 16; static let lg: CGFloat = 24; static let xl: CGFloat = 32; static let xxl: CGFloat = 48 }
    enum Radius { static let control: CGFloat = 8; static let panel: CGFloat = 12; static let card: CGFloat = 16; static let overlay: CGFloat = 20 }
    static let fastMotion = 0.18; static let standardMotion = 0.26
}

struct ObsidianPanelModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View { content.padding(ObsidianTokens.Spacing.md).background(reduceTransparency ? AnyShapeStyle(ObsidianTokens.panel) : AnyShapeStyle(.ultraThinMaterial), in: RoundedRectangle(cornerRadius: ObsidianTokens.Radius.panel)).overlay(RoundedRectangle(cornerRadius: ObsidianTokens.Radius.panel).stroke(ObsidianTokens.border.opacity(0.8))) }
}
extension View { func obsidianPanel() -> some View { modifier(ObsidianPanelModifier()) } }

struct StatusBadge: View {
    let text: String; let color: Color; let symbol: String
    var body: some View { Label(text, systemImage: symbol).font(.caption.weight(.semibold)).foregroundStyle(color).padding(.horizontal, 10).padding(.vertical, 5).background(color.opacity(0.12), in: Capsule()).accessibilityElement(children: .combine) }
}
