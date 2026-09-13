//
//  BVTSettingsUITests.swift
//  UFreeUITests
//
//  BVT-46, 47 — delete cancel stays signed in; confirm wipe returns to login.
//

import XCTest

final class BVTSettingsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_deleteAccount_cancel_staysSignedIn() throws {
        let app = UITestLaunch.makeApp()
        app.launch()
        app.openScheduleTab()

        XCTAssertTrue(app.buttons["settings.open"].waitForExistence(timeout: 8))
        app.buttons["settings.open"].tap()

        let delete = app.buttons["settings.deleteAccount"]
        XCTAssertTrue(delete.waitForExistence(timeout: 6), "BVT-46: Delete Account")
        delete.tap()

        let cancel = app.alerts.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 4))
        cancel.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["settings.root"].waitForExistence(timeout: 4)
                || app.navigationBars["Settings"].exists,
            "BVT-46: cancel keeps Settings open and signed in"
        )
    }

    @MainActor
    func test_deleteAccount_completesToLogin() throws {
        let app = UITestLaunch.makeApp()
        app.launch()
        app.openScheduleTab()

        XCTAssertTrue(app.buttons["settings.open"].waitForExistence(timeout: 8))
        app.buttons["settings.open"].tap()

        let delete = app.buttons["settings.deleteAccount"]
        XCTAssertTrue(delete.waitForExistence(timeout: 6), "BVT-47: Delete Account")
        delete.tap()

        let confirm = app.alerts.buttons["Delete"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 4))
        confirm.tap()

        XCTAssertTrue(
            app.textFields["login.name"].waitForExistence(timeout: 12),
            "BVT-47: mock wipe signs the user out"
        )
    }
}
