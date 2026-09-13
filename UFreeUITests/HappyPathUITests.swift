//
//  HappyPathUITests.swift
//  UFreeUITests
//
//  Deterministic happy path under UI_TESTING_MODE.
//

import XCTest

final class HappyPathUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = UITestLaunch.makeApp()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func test_markSaturdayFree_thenOpenWhosFree() throws {
        app.openScheduleTab()

        let saturdayId = UITestDates.saturdayDateString()
        app.markDayViaSheet(dateString: saturdayId, actionIdentifier: "schedule.sheet.freeAllDay")

        let saturdayCard = app.dayCard(dateString: saturdayId)
        let freeLabel = NSPredicate(format: "label CONTAINS[c] %@", "Free")
        let becameFree = XCTNSPredicateExpectation(predicate: freeLabel, object: saturdayCard)
        wait(for: [becameFree], timeout: 5)
        XCTAssertTrue(
            saturdayCard.label.localizedCaseInsensitiveContains("Free"),
            "Saturday card should show free after the day sheet; label was \(saturdayCard.label)"
        )

        app.openWhosFreeTab()

        let whosFreeRoot = app.descendants(matching: .any)["whosFree.root"]
        let navTitle = app.navigationBars["Who's Free?"]
        let feedVisible = whosFreeRoot.waitForExistence(timeout: 10)
            || navTitle.waitForExistence(timeout: 2)
        XCTAssertTrue(feedVisible, "Expected Who's Free root after tab switch")

        let alex = app.firstExisting(
            app.descendants(matching: .any)["whosFree.friend.alex-ui-test"],
            app.staticTexts["Alex"]
        )
        XCTAssertTrue(
            alex.waitForExistence(timeout: 10),
            "Seeded friend Alex should appear on Who's Free"
        )
    }
}
