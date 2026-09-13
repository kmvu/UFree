//
//  BVTNudgeUITests.swift
//  UFreeUITests
//
//  BVT-33, 36, 38, 39 — inbox nudge, stamp, rapid-tap, offline error.
//

import XCTest

final class BVTNudgeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_offlineNudge_showsError() throws {
        let app = UITestLaunch.makeApp(scenario: "offline")
        app.launch()
        app.openWhosFreeTab()

        let today = app.buttons["whosFree.day.\(UITestDates.todayDateString())"]
        if today.waitForExistence(timeout: 6) {
            today.tap()
        }

        let nudge = app.buttons["whosFree.nudge.alex-ui-test"]
        XCTAssertTrue(nudge.waitForExistence(timeout: 8), "BVT-39: nudge control")
        nudge.tap()

        let errorAlert = app.alerts["Error"]
        XCTAssertTrue(
            errorAlert.waitForExistence(timeout: 6),
            "BVT-39: failed nudge surfaces an error"
        )
        if errorAlert.buttons["OK"].waitForExistence(timeout: 2) {
            errorAlert.buttons["OK"].tap()
        }
    }

    @MainActor
    func test_nudgeRapidTap_staysResponsive() throws {
        let app = UITestLaunch.makeApp()
        app.launch()
        app.openWhosFreeTab()

        let today = app.buttons["whosFree.day.\(UITestDates.todayDateString())"]
        if today.waitForExistence(timeout: 6) {
            today.tap()
        }

        let nudge = app.buttons["whosFree.nudge.alex-ui-test"]
        XCTAssertTrue(nudge.waitForExistence(timeout: 8), "BVT-38: nudge")
        nudge.tap()
        nudge.tap()
        nudge.tap()

        XCTAssertTrue(app.tabBars.buttons["tab.whosFree"].exists, "BVT-38: rapid taps do not crash")
    }
}
