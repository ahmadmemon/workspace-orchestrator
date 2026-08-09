import Foundation
import XCTest
@testable import SceneCore

final class SceneModelTests: XCTestCase {
    private let encoder: JSONEncoder = {
        let value = JSONEncoder()
        value.dateEncodingStrategy = .iso8601
        return value
    }()

    private let decoder: JSONDecoder = {
        let value = JSONDecoder()
        value.dateDecodingStrategy = .iso8601
        return value
    }()

    func testSceneEncodingIncludesAllActionTypes() throws {
        let data = try encoder.encode(TestFixtures.validScene)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(text.contains("openApplication"))
        XCTAssertTrue(text.contains("openURL"))
        XCTAssertTrue(text.contains("runProcess"))
    }

    func testSceneDecoding() throws {
        let data = try encoder.encode(TestFixtures.validScene)
        XCTAssertEqual(try decoder.decode(Scene.self, from: data), TestFixtures.validScene)
    }

    func testRoundTripSerialization() throws {
        let first = try encoder.encode(TestFixtures.validScene)
        let decoded = try decoder.decode(Scene.self, from: first)
        let second = try encoder.encode(decoded)
        XCTAssertEqual(try decoder.decode(Scene.self, from: second), TestFixtures.validScene)
    }

    func testUnknownActionTypeIsRejected() {
        let json = """
        {"schemaVersion":1,"id":"scene","name":"Bad","actions":[{"id":"a","type":"futureAction"}],"createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:00:00Z"}
        """
        XCTAssertThrowsError(try decoder.decode(Scene.self, from: Data(json.utf8)))
    }
}

enum TestFixtures {
    static let date = Date(timeIntervalSince1970: 1_700_000_000)
    static let validScene = Scene(
        id: "scene-1",
        name: "Test Scene",
        description: "A scene",
        actions: [
            .openApplication(.init(id: "app", bundleIdentifier: "com.apple.TextEdit")),
            .openURL(.init(id: "url", url: "https://example.com")),
            .runProcess(.init(id: "process", executable: "/usr/bin/printf", arguments: ["hello"]))
        ],
        createdAt: date,
        updatedAt: date
    )
}
