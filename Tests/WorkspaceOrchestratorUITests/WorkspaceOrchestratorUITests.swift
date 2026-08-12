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
        XCTAssertTrue(app.staticTexts["Seeded Workspace"].exists)

        select("history", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["screen.history"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ready"].exists)

        select("integrations", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["screen.integrations"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Docker CLI"].exists)

        select("permissions", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["screen.permissions"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Accessibility"].exists)

        select("diagnostics", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["screen.diagnostics"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Copy Summary"].exists)
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

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] + arguments
        app.launch()
        return app
    }

    private func select(_ section: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let item = app.descendants(matching: .any)["navigation.\(section)"]
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Missing navigation item \(section)", file: file, line: line)
        item.click()
    }
}
