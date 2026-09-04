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
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING_MODE"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func test_markSaturdayFree_thenOpenWhosFree() throws {
        let scheduleTab = app.tabBars.buttons["Schedule"]
        XCTAssertTrue(
            scheduleTab.waitForExistence(timeout: 10),
            "Expected Schedule tab after UI_TESTING_MODE bootstrap"
        )
        scheduleTab.tap()

        let saturdayId = "schedule.day.\(Self.saturdayDateStringInNext7Days())"
        // Prefer the combined button trait; fall back to any element with the id.
        let saturdayCard = firstExisting(
            app.buttons[saturdayId],
            app.descendants(matching: .any).matching(identifier: saturdayId).element(boundBy: 0)
        )
        XCTAssertTrue(
            saturdayCard.waitForExistence(timeout: 5),
            "Expected Saturday day card \(saturdayId)"
        )
        tapHittable(saturdayCard)

        let whosFreeTab = app.tabBars.buttons["Who's Free?"]
        XCTAssertTrue(whosFreeTab.waitForExistence(timeout: 5))
        whosFreeTab.tap()

        let whosFreeRoot = app.descendants(matching: .any)
            .matching(identifier: "whosFree.root")
            .firstMatch
        XCTAssertTrue(
            whosFreeRoot.waitForExistence(timeout: 5),
            "Expected Who's Free root after tab switch"
        )
        XCTAssertTrue(app.navigationBars["Who's Free?"].waitForExistence(timeout: 5))
    }

    /// Scroll horizontally if needed, then tap via center coordinate (avoids non-hittable StaticText).
    private func tapHittable(_ element: XCUIElement) {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline && !element.isHittable {
            app.swipeLeft()
        }
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    private func firstExisting(_ primary: XCUIElement, _ fallback: XCUIElement) -> XCUIElement {
        if primary.waitForExistence(timeout: 2) { return primary }
        return fallback
    }

    /// Matches app day-card ids: UTC `yyyy-MM-dd` for the next Saturday in the upcoming week.
    private static func saturdayDateStringInNext7Days(from reference: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let weekday = calendar.component(.weekday, from: reference)
        let daysUntilSaturday = (7 - weekday + 7) % 7
        let saturday = calendar.date(byAdding: .day, value: daysUntilSaturday, to: reference)!

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: saturday)
    }
}
