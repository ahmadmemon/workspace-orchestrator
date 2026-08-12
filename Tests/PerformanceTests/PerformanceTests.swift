import ActivationKit
import SceneCore
import XCTest

final class PerformanceTests: XCTestCase {
    func testLargeSceneGraphValidationPerformance() throws {
        let actions = (0..<600).map { index in
            SceneAction.wait(.init(
                id: "action-\(index)",
                durationSeconds: 0.001,
                configuration: .init(dependencies: index == 0 ? [] : ["action-\(index - 1)"])
            ))
        }
        let scene = Scene(id: "performance-graph", name: "Performance Graph", actions: actions)

        measure {
            do {
                try SceneValidator.validate(scene)
            } catch {
                XCTFail("Large scene graph validation failed: \(error)")
            }
        }
    }

    func testLargeRunHistorySerializationPerformance() throws {
        let actions = (0..<20).map { SceneAction.wait(.init(id: "action-\($0)", durationSeconds: 0.001)) }
        let scene = Scene(id: "history-scene", name: "History Scene", actions: actions)
        let runs = (0..<1_000).map { SceneRunResult(scene: scene, id: "run-\($0)", appVersion: "1.0.0-rc.1") }
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        measure {
            do {
                let data = try encoder.encode(runs)
                let decoded = try decoder.decode([SceneRunResult].self, from: data)
                XCTAssertEqual(decoded.count, runs.count)
            } catch {
                XCTFail("Large run history serialization failed: \(error)")
            }
        }
    }

    func testLargeOutputRedactionPerformance() {
        let line = "token=super-secret-value Authorization: Bearer abcdefghijklmnop payload\n"
        let output = String(repeating: line, count: 8_000)

        measure {
            let redacted = Redactor.redact(output, secrets: ["super-secret-value"])
            XCTAssertFalse(redacted.contains("super-secret-value"))
            XCTAssertFalse(redacted.contains("abcdefghijklmnop"))
            XCTAssertTrue(redacted.hasSuffix("[OUTPUT TRUNCATED]"))
        }
    }

    func testClapDetectorFixtureThroughputPerformance() {
        let fixtures = (0..<50_000).map { index in
            AudioFeatureFrame(
                timestamp: Double(index) * 0.01,
                rmsEnergy: index.isMultiple(of: 997) ? 0.08 : 0.008,
                peakDuration: 0.03,
                highFrequencyRatio: 0.3,
                spectralFlatness: 0.2
            )
        }

        measure {
            var detector = DoubleClapDetector(configuration: .init(enabled: true))
            var eventCount = 0
            for fixture in fixtures where detector.consume(fixture) != .none { eventCount += 1 }
            XCTAssertGreaterThan(eventCount, 0)
        }
    }
}
