import XCTest

final class WorkspaceOrchestratorUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingCanBeSkippedWithoutGrantingPermissions() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-onboarding"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Welcome"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Restore a reviewed workspace and know when it is genuinely ready."].exists)
        app.buttons["Skip optional setup"].click()

        XCTAssertTrue(app.staticTexts["WORKSPACE COMMAND"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Workspace Offline"].exists)
    }
}
