import SceneCore
import SwiftUI

struct CommandPaletteView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    private var matchingScenes: [SceneCore.Scene] {
        guard !query.isEmpty else { return model.recentScenes + model.scenes.filter { !model.recentScenes.map(\.id).contains($0.id) } }
        return model.scenes.compactMap { scene -> (SceneCore.Scene, Int)? in
            let name = scene.name.lowercased(), needle = query.lowercased()
            if name.contains(needle) { return (scene, name.hasPrefix(needle) ? 0 : 1) }
            var cursor = name.startIndex
            for character in needle { guard let found = name[cursor...].firstIndex(of: character) else { return nil }; cursor = name.index(after: found) }
            return (scene, 2)
        }.sorted { $0.1 < $1.1 }.map(\.0)
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack { Image(systemName: "command").foregroundStyle(ObsidianTokens.cyan); TextField("Search scenes and commands", text: $query).textFieldStyle(.plain).font(.title3) }.padding(18)
            Divider()
            List {
                Section("Commands") {
                    paletteButton("Open Dashboard", symbol: "square.grid.2x2") { model.selectedSection = .dashboard }
                    paletteButton("Open History", symbol: "clock.arrow.circlepath") { model.selectedSection = .history }
                    paletteButton("Capture Workspace", symbol: "viewfinder") { model.selectedSection = .capture }
                    if model.isRunning { paletteButton("Cancel Current Run", symbol: "stop.circle", role: .destructive) { model.cancelCurrentRun() } }
                }
                Section("Scenes") { ForEach(matchingScenes) { scene in paletteButton("Run \(scene.name)", symbol: scene.iconName ?? "play.fill") { model.run(scene) }.disabled(model.isRunning || scene.trustState == .importedUntrusted) } }
            }.scrollContentBackground(.hidden).background(ObsidianTokens.elevated)
        }.background(ObsidianTokens.elevated).foregroundStyle(ObsidianTokens.primaryText)
    }
    private func paletteButton(_ title: String, symbol: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View { Button(role: role) { action(); dismiss() } label: { Label(title, systemImage: symbol).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle()) }.buttonStyle(.plain).padding(.vertical, 5) }
}
