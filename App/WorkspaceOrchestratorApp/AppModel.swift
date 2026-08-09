import Foundation
import MacAutomation
import SceneCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var scenes: [Scene] = []
    @Published private(set) var currentRun: SceneRunResult?
    @Published var presentedError: String?
    @Published private(set) var isLoading = false

    private let store: any SceneStoring
    private let executor: SceneExecutor
    private var runTask: Task<Void, Never>?

    var isRunning: Bool { currentRun?.status == .running }

    init(
        store: (any SceneStoring)? = nil,
        executor: SceneExecutor? = nil
    ) {
        do {
            self.store = try store ?? JSONSceneStore.applicationSupportStore()
        } catch {
            let fallback = FileManager.default.temporaryDirectory
                .appendingPathComponent("WorkspaceOrchestrator", isDirectory: true)
            self.store = JSONSceneStore(directoryURL: fallback)
            presentedError = error.localizedDescription
        }
        self.executor = executor ?? SceneExecutor(
            applicationOpener: NSWorkspaceApplicationOpener(),
            urlOpener: NSWorkspaceURLOpener(),
            processRunner: FoundationProcessRunner()
        )
        Task { await loadScenes() }
    }

    func loadScenes() async {
        isLoading = true
        defer { isLoading = false }
        do {
            scenes = try await store.loadScenes()
        } catch {
            presentedError = error.localizedDescription
        }
    }

    func save(_ scene: Scene) async -> Bool {
        var updated = scene
        updated.updatedAt = Date()
        do {
            try SceneValidator.validate(updated)
            try await store.save(updated)
            await loadScenes()
            return true
        } catch {
            presentedError = error.localizedDescription
            return false
        }
    }

    func delete(_ scene: Scene) async {
        do {
            try await store.deleteScene(id: scene.id)
            await loadScenes()
        } catch {
            presentedError = error.localizedDescription
        }
    }

    func installDemoScene() async {
        guard !scenes.contains(where: { $0.name == "Workspace Orchestrator Demo" }) else {
            presentedError = "The Demo Scene is already installed."
            return
        }
        _ = await save(.demo())
    }

    func run(_ scene: Scene) {
        guard !isRunning else { return }
        runTask = Task { [executor] in
            let finalResult = await executor.execute(scene: scene) { [weak self] update in
                await self?.accept(update)
            }
            currentRun = finalResult
            runTask = nil
        }
    }

    func cancelCurrentRun() {
        runTask?.cancel()
    }

    private func accept(_ update: SceneRunResult) {
        currentRun = update
    }
}
