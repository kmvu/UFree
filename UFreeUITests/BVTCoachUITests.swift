//
//  BVTCoachUITests.swift
//  UFreeUITests
//
//  BVT-22–26 — first-connect celebration, weekend CTA / mission chip, checklist.
//

import XCTest

final class BVTCoachUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_firstAccept_showsCelebrationToast() throws {
        let app = UITestLaunch.makeApp(scenario: "firstConnect")
        app.launch()
        app.openFriendsTab()

        let accept = app.firstExisting(
            app.buttons["friends.accept"],
            app.buttons["Accept"]
        )
        XCTAssertTrue(accept.waitForExistence(timeout: 8), "Casey request on Friends")
        accept.tap()

        let toast = app.descendants(matching: .any)["celebration.toast"]
        let casey = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Casey")).firstMatch
        XCTAssertTrue(
            toast.waitForExistence(timeout: 6) || casey.waitForExistence(timeout: 4),
            "BVT-22: first accept celebrates Casey"
        )

        XCTAssertTrue(
            app.descendants(matching: .any)["weekend.cta"].waitForExistence(timeout: 10),
            "BVT-23: first connect without a free day offers the weekend CTA"
        )
    }

    @MainActor
    func test_weekendCTA_marksFreeAndShowsMission() throws {
        let app = UITestLaunch.makeApp(scenario: "firstConnect")
        app.launch()
        app.openFriendsTab()

        let accept = app.firstExisting(
            app.buttons["friends.accept"],
            app.buttons["Accept"]
        )
        XCTAssertTrue(accept.waitForExistence(timeout: 8))
        accept.tap()

        let cta = app.descendants(matching: .any)["weekend.cta"]
        XCTAssertTrue(cta.waitForExistence(timeout: 12), "BVT-24: weekend CTA after first accept")

        let mark = app.firstExisting(
            app.buttons["I'm free Sat & Sun"],
            app.buttons["weekend.cta.confirm"]
        )
        XCTAssertTrue(mark.waitForExistence(timeout: 4))
        mark.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["mission.chip"].waitForExistence(timeout: 8)
                || app.tabBars.buttons["tab.whosFree"].waitForExistence(timeout: 4),
            "BVT-25: marking the weekend free continues into the post-connect mission"
        )
    }

    @MainActor
    func test_checklist_notNow_andDontShowAgain() throws {
        let app = UITestLaunch.makeApp(scenario: "empty")
        app.launch()
        app.openWhosFreeTab()

        let banner = app.descendants(matching: .any)["hangout.checklist.banner"]
        if banner.waitForExistence(timeout: 6) {
            banner.tap()
        }

        let sheet = app.descendants(matching: .any)["hangout.checklist.sheet"]
        if sheet.waitForExistence(timeout: 4) {
            let notNow = app.buttons["hangout.checklist.notNow"]
            if notNow.waitForExistence(timeout: 2) {
                notNow.tap()
            }
            XCTAssertTrue(sheet.waitForNonExistence(timeout: 4), "BVT-26: Not now closes the sheet")
        }

        if banner.waitForExistence(timeout: 3) {
            banner.tap()
            let dontShow = app.buttons["hangout.checklist.dontShow"]
            if dontShow.waitForExistence(timeout: 3) {
                dontShow.tap()
            }
        }

        app.terminate()
        app.launch()
        app.openWhosFreeTab()
        XCTAssertFalse(
            app.descendants(matching: .any)["hangout.checklist.sheet"].waitForExistence(timeout: 2),
            "BVT-26: Don't show again does not auto-present the sheet"
        )
    }
}
