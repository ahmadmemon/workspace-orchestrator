import SceneCore
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let workspaceOrchestratorArchive = UTType(exportedAs: "com.ahmadmemon.workspace-orchestrator.scene-archive", conformingTo: .json)
}

struct SceneArchiveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.workspaceOrchestratorArchive, .json] }
    let data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { .init(regularFileWithContents: data) }
}

struct ImportReviewView: View {
    @ObservedObject var model: AppModel
    let request: ImportReviewRequest
    @State private var duplicatePolicy: ImportDuplicatePolicy = .createCopy

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Image(systemName: "shippingbox.and.arrow.backward.fill").font(.title).foregroundStyle(ObsidianTokens.warning); VStack(alignment: .leading) { Text("Review Untrusted Import").font(.title2.bold()); Text(request.sourceURL.lastPathComponent).font(.caption.monospaced()).foregroundStyle(ObsidianTokens.mutedText) } }
            Text("Imported scenes are saved as untrusted and never run automatically. Executable, Docker, Shortcut, and window-control actions require another explicit review before execution.").foregroundStyle(ObsidianTokens.secondaryText)
            List {
                Section("Scenes") { ForEach(request.preview.scenes) { scene in VStack(alignment: .leading, spacing: 4) { Text(scene.name).font(.headline); Text("\(scene.actions.count) start actions • \(scene.deactivationActions.count) stop actions").font(.caption); Text(scene.id).font(.caption2.monospaced()).foregroundStyle(ObsidianTokens.mutedText) }.padding(.vertical, 4) } }
                previewSection("Executables", request.preview.executables, symbol: "terminal")
                previewSection("Applications", request.preview.applications, symbol: "app")
                previewSection("URLs", request.preview.urls, symbol: "link")
                previewSection("Files and folders", request.preview.paths, symbol: "folder")
                previewSection("Permissions", request.preview.requiredPermissions, symbol: "lock.shield")
                previewSection("Destructive actions", request.preview.destructiveActions, symbol: "exclamationmark.triangle")
            }.scrollContentBackground(.hidden)
            Picker("When an ID already exists", selection: $duplicatePolicy) { Text("Create an imported copy").tag(ImportDuplicatePolicy.createCopy); Text("Replace existing definition").tag(ImportDuplicatePolicy.replaceExisting); Text("Skip duplicate").tag(ImportDuplicatePolicy.skipExisting) }
            HStack { Button("Cancel", role: .cancel) { model.cancelImport() }; Spacer(); Button("Save as Untrusted") { Task { await model.confirmImport(duplicatePolicy: duplicatePolicy) } }.buttonStyle(.borderedProminent) }
        }
        .padding(24).frame(minWidth: 760, minHeight: 620).background(ObsidianTokens.base).foregroundStyle(ObsidianTokens.primaryText)
        .accessibilityIdentifier("importReviewSheet")
    }

    private func previewSection(_ title: String, _ values: [String], symbol: String) -> some View {
        Section(title) { if values.isEmpty { Text("None").foregroundStyle(ObsidianTokens.mutedText) } else { ForEach(values, id: \.self) { Label($0, systemImage: symbol).font(.caption.monospaced()) } } }
    }
}
