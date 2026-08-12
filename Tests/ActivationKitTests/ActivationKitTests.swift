import XCTest
@testable import ActivationKit

final class ActivationKitTests: XCTestCase {
    func testDefaultHotKeyIsOptionCommandSpace() {
        let configuration = HotKeyConfiguration()
        XCTAssertEqual(configuration.keyCode, 49)
        XCTAssertEqual(configuration.modifiers, 2_048 | 256)
        XCTAssertTrue(configuration.enabled)
    }

    func testVoiceParserControlCommands() {
        XCTAssertEqual(VoiceCommandParser.parse("stop current workspace"), .stopCurrent)
        XCTAssertEqual(VoiceCommandParser.parse("cancel current run"), .cancelCurrent)
        XCTAssertEqual(VoiceCommandParser.parse("show history"), .showHistory)
    }
    func testValidDoubleClap() { var detector = DoubleClapDetector(configuration: enabled()); XCTAssertEqual(detector.consume(clap(1)), .firstTransient); XCTAssertEqual(detector.consume(clap(1.3)), .doubleClap) }
    func testSingleClapDoesNotActivate() { var detector = DoubleClapDetector(configuration: enabled()); XCTAssertEqual(detector.consume(clap(1)), .firstTransient); XCTAssertEqual(detector.consume(noise(2)), .none) }
    func testTooFastClapsAreRejected() { var detector = DoubleClapDetector(configuration: enabled()); _ = detector.consume(clap(1)); XCTAssertEqual(detector.consume(clap(1.03)), .rejected) }
    func testTooSlowClapsStartNewPair() { var detector = DoubleClapDetector(configuration: enabled()); _ = detector.consume(clap(1)); XCTAssertEqual(detector.consume(clap(2)), .firstTransient) }
    func testSpeechLikeSignalRejected() { var detector = DoubleClapDetector(configuration: enabled()); XCTAssertEqual(detector.consume(.init(timestamp: 1, rmsEnergy: 0.2, peakDuration: 0.3, highFrequencyRatio: 0.05, spectralFlatness: 0.05)), .none) }
    func testCooldownPreventsTripleActivation() { var detector = DoubleClapDetector(configuration: enabled()); _ = detector.consume(clap(1)); XCTAssertEqual(detector.consume(clap(1.3)), .doubleClap); XCTAssertEqual(detector.consume(clap(1.6)), .none) }
    func testVoiceParserAndExactMatch() { XCTAssertEqual(VoiceCommandParser.parse("Start Project H"), .runScene("project h")); XCTAssertEqual(VoiceCommandParser.match(sceneQuery: "project h", sceneNames: ["Project H", "Project Home"]), .exact("Project H")) }
    func testAmbiguousVoiceMatchRequiresChoice() { if case .ambiguous = VoiceCommandParser.match(sceneQuery: "project", sceneNames: ["Project H", "Project X"]) {} else { XCTFail("Expected ambiguity") } }
    private func enabled() -> ClapConfiguration { .init(enabled: true, sensitivity: 0.7, minimumInterval: 0.12, maximumInterval: 0.65, cooldown: 2) }
    private func clap(_ time: Double) -> AudioFeatureFrame { .init(timestamp: time, rmsEnergy: 0.3, peakDuration: 0.02, highFrequencyRatio: 0.4, spectralFlatness: 0.35) }
    private func noise(_ time: Double) -> AudioFeatureFrame { .init(timestamp: time, rmsEnergy: 0.01, peakDuration: 0.2, highFrequencyRatio: 0.05, spectralFlatness: 0.03) }
}
