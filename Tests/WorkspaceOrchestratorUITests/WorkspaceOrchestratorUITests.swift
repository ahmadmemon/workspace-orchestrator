import XCTest

final class WorkspaceOrchestratorUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingCanBeSkippedWithoutGrantingPermissions() throws {
        let app = launch(["--reset-onboarding"])

        XCTAssertTrue(app.staticTexts["Welcome"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Restore a reviewed workspace and know when it is genuinely ready."].exists)
        app.buttons["Skip optional setup"].click()

        XCTAssertTrue(app.staticTexts["WORKSPACE COMMAND"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Workspace Offline"].exists)
    }

    func testDeterministicDashboardAndOperationalScreens() throws {
        let app = launch(["--seed-ui-fixtures"])

        XCTAssertTrue(app.descendants(matching: .any)["screen.dashboard"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Seeded Workspace"].waitForExistence(timeout: 5))
        select("scenes", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["screen.scenes"].waitForExistence(timeout: 5))
    }

    func testSceneCreationValidationAndActionEditing() throws {
        let app = launch(["--seed-ui-fixtures"])
        XCTAssertTrue(app.descendants(matching: .any)["screen.dashboard"].waitForExistence(timeout: 5))
        app.buttons["New Scene"].click()

        let name = app.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.click()
        name.typeKey("a", modifierFlags: .command)
        name.typeKey(.delete, modifierFlags: [])
        name.typeKey("s", modifierFlags: .command)
        XCTAssertTrue(app.descendants(matching: .any)["sceneEditor.validation"].waitForExistence(timeout: 5))

        name.typeText("Created in UI Test")
        let addAction = app.menuButtons["Add Action"].firstMatch
        XCTAssertTrue(addAction.waitForExistence(timeout: 5))
        addAction.click()
        app.menuItems["Wait"].click()
        XCTAssertTrue(app.staticTexts["Stable action ID"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Dependencies (IDs, comma separated)"].exists)
        app.typeKey("s", modifierFlags: .command)

        select("scenes", in: app)
        XCTAssertTrue(app.staticTexts["Created in UI Test"].waitForExistence(timeout: 5))
    }

    func testReadyWarningAndFailureFixturesAreVisible() throws {
        for fixture in [("readyWithWarnings", "Ready with warnings"), ("failed", "Failed")] {
            let app = launch(["--seed-ui-fixtures", "--ui-run-status=\(fixture.0)"])
            XCTAssertTrue(app.staticTexts[fixture.1].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["Seeded Workspace"].exists)
            app.terminate()
        }
    }

    func testImportedAdvancedSceneExposesConditionsHealthChecksAndStructuredArguments() throws {
        let app = launch(["--seed-ui-fixtures"])
        select("scenes", in: app)
        XCTAssertTrue(app.staticTexts["Seeded Workspace"].waitForExistence(timeout: 5))
        app.buttons["Edit"].firstMatch.click()
        XCTAssertTrue(app.descendants(matching: .any)["screen.sceneEditor"].waitForExistence(timeout: 5))
        app.staticTexts["Advanced Process"].firstMatch.click()

        XCTAssertTrue(app.descendants(matching: .any)["sceneEditor.structuredArguments"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["sceneEditor.condition.0"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["sceneEditor.conditionSummary"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["sceneEditor.healthCheck.0"].exists)
        XCTAssertTrue(app.buttons["Move Up"].exists)
        XCTAssertTrue(app.buttons["Move Down"].exists)
        XCTAssertTrue(app.buttons["Copy Structured Preview"].waitForExistence(timeout: 5))
    }

    func testSettingsExposePersistedGeneralControls() throws {
        let app = launch(["--seed-ui-fixtures"])
        app.typeKey(",", modifierFlags: .command)

        XCTAssertTrue(app.descendants(matching: .any)["screen.settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["Open Dashboard at launch"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["Reopen interrupted-run recovery at launch"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["Check for Updates Now"].exists)
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] + arguments
        app.launch()
        return app
    }

    private func select(_ section: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let item = app.descendants(matching: .any)["navigation.\(section)"]
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Missing navigation item \(section)", file: file, line: line)
        app.activate()
        item.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
    }
}
