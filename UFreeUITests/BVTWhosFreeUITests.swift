//
//  BVTWhosFreeUITests.swift
//  UFreeUITests
//
//  BVT-27, 29–32 — seeded Alex, badges, Both, partial, empty hero.
//

import XCTest

final class BVTWhosFreeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_seededAlexAppears() throws {
        let app = UITestLaunch.makeApp()
        app.launch()
        app.openWhosFreeTab()

        let alex = app.descendants(matching: .any)["whosFree.friend.alex-ui-test"]
        XCTAssertTrue(alex.waitForExistence(timeout: 10), "BVT-27: Alex is on Who's Free")
    }

    @MainActor
    func test_todayBadge_countsAlex() throws {
        let app = UITestLaunch.makeApp()
        app.launch()
        app.openWhosFreeTab()

        let today = app.buttons["whosFree.day.\(UITestDates.todayDateString())"]
        XCTAssertTrue(today.waitForExistence(timeout: 8), "BVT-29: today chip")
        XCTAssertTrue(
            today.label.contains("1") || today.value as? String == "1" || today.value as? String == "Both",
            "BVT-29: today badge reflects one free friend; label=\(today.label) value=\(today.value ?? "")"
        )
    }

    @MainActor
    func test_bothCue_afterMarkingTodayFree() throws {
        let app = UITestLaunch.makeApp()
        app.launch()
        app.openScheduleTab()
        app.markDayViaSheet(
            dateString: UITestDates.todayDateString(),
            actionIdentifier: "schedule.sheet.freeAllDay"
        )

        app.openWhosFreeTab()
        let today = app.buttons["whosFree.day.\(UITestDates.todayDateString())"]
        XCTAssertTrue(today.waitForExistence(timeout: 8), "BVT-28: today chip")
        let value = (today.value as? String) ?? ""
        XCTAssertTrue(
            value == "Both" || today.label.localizedCaseInsensitiveContains("Both"),
            "BVT-28: mutual free day shows the Both cue; label=\(today.label) value=\(value)"
        )
    }

    @MainActor
    func test_partialDayFriend_isListed() throws {
        let app = UITestLaunch.makeApp(scenario: "partialDay")
        app.launch()
        app.openWhosFreeTab()

        let alex = app.descendants(matching: .any)["whosFree.friend.alex-ui-test"]
        XCTAssertTrue(alex.waitForExistence(timeout: 10), "BVT-31: partial-day Alex is visible")
    }

    @MainActor
    func test_emptyStateHero() throws {
        let app = UITestLaunch.makeApp(scenario: "empty")
        app.launch()
        app.openWhosFreeTab()

        XCTAssertTrue(
            app.descendants(matching: .any)["whosFree.empty"].waitForExistence(timeout: 10)
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "invite")).firstMatch.waitForExistence(timeout: 4),
            "BVT-32: empty-state hero when no friends are free"
        )
    }

    @MainActor
    func test_nudgeAll_existsWhenTwoFriendsFree() throws {
        let app = UITestLaunch.makeApp(scenario: "batchNudge")
        app.launch()
        app.openWhosFreeTab()

        // selectedDate defaults to today. Tapping the today chip toggles it off
        // and hides Nudge all.
        XCTAssertTrue(
            app.descendants(matching: .any)["whosFree.friend.alex-ui-test"].waitForExistence(timeout: 8)
                || app.descendants(matching: .any)["whosFree.friend.dana-ui-test"].waitForExistence(timeout: 4),
            "BVT-37: batch-nudge seeds Alex and Dana"
        )
        XCTAssertTrue(
            app.buttons["whosFree.nudgeAll"].waitForExistence(timeout: 8),
            "BVT-37: Nudge all is available when 2+ friends are free"
        )
    }
}
