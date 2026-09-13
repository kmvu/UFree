//
//  BVTScheduleUITests.swift
//  UFreeUITests
//
//  BVT-07, 08, 09, 11 — day sheet Free / window / Busy vs unknown / banner.
//

import XCTest

final class BVTScheduleUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = UITestLaunch.makeApp(scenario: "busyUnknown")
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func test_markFullDayFree_viaSheet() throws {
        app.openScheduleTab()
        let saturday = UITestDates.saturdayDateString()
        app.markDayViaSheet(dateString: saturday, actionIdentifier: "schedule.sheet.freeAllDay")

        let card = app.dayCard(dateString: saturday)
        XCTAssertTrue(
            card.label.localizedCaseInsensitiveContains("Free"),
            "BVT-07: card reads Free after Free all day + Save"
        )
    }

    @MainActor
    func test_markAfternoonWindow_isNotFullDayFree() throws {
        app.openScheduleTab()
        let saturday = UITestDates.saturdayDateString()
        app.markDayViaSheet(dateString: saturday, actionIdentifier: "schedule.sheet.afternoon")

        let card = app.dayCard(dateString: saturday)
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        XCTAssertFalse(
            card.label.localizedCaseInsensitiveContains("Unknown"),
            "BVT-08: afternoon window should not stay unknown"
        )
        let looksPartial = card.label.localizedCaseInsensitiveContains("Afternoon")
            || card.label.localizedCaseInsensitiveContains("Mixed")
            || card.label.localizedCaseInsensitiveContains("starting")
        XCTAssertTrue(
            looksPartial || !card.label.localizedStandardContains("Free all"),
            "BVT-08: partial window is not presented as a blank unknown day; label=\(card.label)"
        )
    }

    @MainActor
    func test_busyVersusUnknown() throws {
        app.openScheduleTab()
        let saturday = UITestDates.saturdayDateString()
        let today = UITestDates.todayDateString()

        app.markDayViaSheet(dateString: saturday, actionIdentifier: "schedule.sheet.busy")
        let busyCard = app.dayCard(dateString: saturday)
        XCTAssertTrue(
            busyCard.label.localizedCaseInsensitiveContains("Busy"),
            "BVT-09: marked day reads Busy"
        )

        if today != saturday {
            let unknownCard = app.dayCard(dateString: today)
            XCTAssertTrue(unknownCard.waitForExistence(timeout: 3))
            XCTAssertTrue(
                unknownCard.label.localizedCaseInsensitiveContains("Unknown"),
                "BVT-09: untouched day stays unknown, not Busy"
            )
        }
    }

    @MainActor
    func test_statusBannerExists() throws {
        app.openScheduleTab()
        XCTAssertTrue(
            app.descendants(matching: .any)["schedule.banner"].waitForExistence(timeout: 8),
            "BVT-11: status banner is on Schedule"
        )
    }

    @MainActor
    func test_remoteFailure_stillSavesLocally() throws {
        app.terminate()
        app = UITestLaunch.makeApp(scenario: "offline")
        app.launch()
        app.openScheduleTab()

        let saturday = UITestDates.saturdayDateString()
        app.markDayViaSheet(dateString: saturday, actionIdentifier: "schedule.sheet.freeAllDay")

        let card = app.dayCard(dateString: saturday)
        XCTAssertTrue(
            card.label.localizedCaseInsensitiveContains("Free"),
            "BVT-10: offline-first write still marks the card Free when remote sync fails"
        )
    }
}
