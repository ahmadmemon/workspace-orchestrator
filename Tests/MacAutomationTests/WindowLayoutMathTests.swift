import XCTest
import SceneCore
@testable import MacAutomation

final class WindowLayoutMathTests: XCTestCase {
    func testNormalizeAndDenormalizeRoundTrip() {
        let display = CGRect(x: 100, y: 200, width: 1200, height: 800), frame = CGRect(x: 400, y: 400, width: 600, height: 400)
        let normalized = WindowLayoutMath.normalize(frame, in: display)
        XCTAssertEqual(normalized, .init(x: 0.25, y: 0.25, width: 0.5, height: 0.5)); XCTAssertEqual(WindowLayoutMath.denormalize(normalized, in: display), frame)
    }
    func testMissingDisplayUsesMainFallback() {
        let displays = [DisplayGeometry(id: "secondary", frame: .init(x: 100, y: 0, width: 100, height: 100), visibleFrame: .init(x: 100, y: 0, width: 100, height: 100)), DisplayGeometry(id: "main", frame: .init(x: 0, y: 0, width: 100, height: 100), visibleFrame: .init(x: 0, y: 0, width: 100, height: 100), isMain: true)]
        XCTAssertEqual(WindowLayoutMath.display(for: "missing", among: displays)?.id, "main")
    }
    func testClampKeepsFrameVisible() {
        let value = WindowLayoutMath.clamp(.init(x: -200, y: 900, width: 900, height: 900), to: .init(x: 0, y: 0, width: 800, height: 600))
        XCTAssertEqual(value, .init(x: 0, y: 0, width: 800, height: 600))
    }
}
