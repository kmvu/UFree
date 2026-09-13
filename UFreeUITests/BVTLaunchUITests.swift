//
//  BVTLaunchUITests.swift
//  UFreeUITests
//
//  BVT-01, 02, 04, 06 — install chrome, name gate, cold start, sign-out.
//

import XCTest

final class BVTLaunchUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_loginChrome_requiresNameBeforeSiwA() throws {
        let app = UITestLaunch.makeApp(scenario: "login")
        app.launch()

        XCTAssertTrue(app.textFields["login.name"].waitForExistence(timeout: 10), "BVT-01: login name field")
        XCTAssertTrue(app.buttons["login.siwa"].waitForExistence(timeout: 3), "BVT-01: SiwA button")
        XCTAssertFalse(app.buttons["login.siwa"].isEnabled, "BVT-02: SiwA stays disabled with empty name")
    }

    @MainActor
    func test_mockSignIn_withName_reachesTabs() throws {
        let app = UITestLaunch.makeApp(scenario: "login")
        app.launch()

        let name = app.textFields["login.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        app.typeIntoField(name, "BVT Tester")
        app.dismissKeyboardIfPresent()

        let siwa = app.buttons["login.siwa"]
        XCTAssertTrue(siwa.waitForExistence(timeout: 3))
        XCTAssertTrue(siwa.isEnabled, "BVT-02: SiwA enables after a name is entered")
        siwa.tap()

        XCTAssertTrue(
            app.tabBars.buttons["tab.schedule"].waitForExistence(timeout: 12),
            "Mock SiwA should land on Schedule"
        )
    }

    @MainActor
    func test_coldStart_staysOnTabs() throws {
        let app = UITestLaunch.makeApp()
        app.launch()
        app.openScheduleTab()

        app.terminate()
        app.launch()

        XCTAssertTrue(
            app.tabBars.buttons["tab.schedule"].waitForExistence(timeout: 12),
            "BVT-04: UI_TESTING_MODE relaunch stays signed in"
        )
    }

    @MainActor
    func test_signOut_returnsToLogin() throws {
        let app = UITestLaunch.makeApp()
        app.launch()
        app.openScheduleTab()

        let menu = app.buttons["settings.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 8))
        menu.tap()

        let signOut = app.firstExisting(
            app.buttons["settings.signOut"],
            app.buttons["Sign Out"]
        )
        XCTAssertTrue(signOut.waitForExistence(timeout: 4), "BVT-06: Sign Out in toolbar menu")
        signOut.tap()

        XCTAssertTrue(
            app.textFields["login.name"].waitForExistence(timeout: 10),
            "BVT-06: sign-out returns to login"
        )
    }

    @MainActor
    func test_offlineColdStart_reachesTabs() throws {
        let app = UITestLaunch.makeApp(scenario: "offline")
        app.launch()
        XCTAssertTrue(
            app.tabBars.buttons["tab.schedule"].waitForExistence(timeout: 20),
            "BVT-05: mock-offline launch still reaches authenticated tabs"
        )
    }
}
