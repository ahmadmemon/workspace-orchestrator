import Foundation
import XCTest
@testable import SceneCore

final class SceneStoreTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testMissingStorageDirectoryLoadsEmptyCollection() async throws {
        let store = JSONSceneStore(directoryURL: temporaryDirectory)
        let scenes = try await store.loadScenes()
        XCTAssertEqual(scenes, [])
    }

    func testSaveAndLoadScene() async throws {
        let store = JSONSceneStore(directoryURL: temporaryDirectory)
        try await store.save(TestFixtures.validScene)
        let scenes = try await store.loadScenes()
        XCTAssertEqual(scenes, [TestFixtures.validScene])
    }

    func testUpdateScene() async throws {
        let store = JSONSceneStore(directoryURL: temporaryDirectory)
        try await store.save(TestFixtures.validScene)
        var updated = TestFixtures.validScene
        updated.name = "Updated"
        try await store.save(updated)
        let scenes = try await store.loadScenes()
        XCTAssertEqual(scenes.count, 1)
        XCTAssertEqual(scenes.first?.name, "Updated")
    }

    func testDeleteScene() async throws {
        let store = JSONSceneStore(directoryURL: temporaryDirectory)
        try await store.save(TestFixtures.validScene)
        try await store.deleteScene(id: TestFixtures.validScene.id)
        let scenes = try await store.loadScenes()
        XCTAssertEqual(scenes, [])
    }

    func testCorruptSceneDataIsPreservedAndReported() async throws {
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        let file = temporaryDirectory.appendingPathComponent("scenes.json")
        let corruptData = Data("not-json".utf8)
        try corruptData.write(to: file)
        let store = JSONSceneStore(directoryURL: temporaryDirectory)
        do {
            _ = try await store.loadScenes()
            XCTFail("Expected corrupt data error")
        } catch let error as SceneStoreError {
            guard case .corruptData = error else { return XCTFail("Unexpected error: \(error)") }
        }
        XCTAssertEqual(try Data(contentsOf: file), corruptData)
    }
}
