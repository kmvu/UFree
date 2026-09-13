//
//  BVTLayoutUITests.swift
//  UFreeUITests
//
//  BVT-44, 45 — iPad skip-unless-pad, iPhone landscape.
//

import XCTest

final class BVTLayoutUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func test_iphoneLandscape_scheduleStaysUsable() throws {
        let app = UITestLaunch.makeApp()
        app.launch()
        app.openScheduleTab()

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(
            app.tabBars.buttons["tab.schedule"].waitForExistence(timeout: 5)
                || app.descendants(matching: .any)["schedule.weekCarousel"].waitForExistence(timeout: 3),
            "BVT-45: Schedule remains usable in landscape"
        )

        app.openWhosFreeTab()
        XCTAssertTrue(
            app.descendants(matching: .any)["whosFree.root"].waitForExistence(timeout: 6),
            "BVT-45: Who's Free remains usable in landscape"
        )
    }

    @MainActor
    func test_ipadLayout_whenRunningOniPad() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("BVT-44 requires an iPad destination")
        }

        let app = UITestLaunch.makeApp()
        app.launch()
        XCTAssertTrue(
            app.descendants(matching: .any)["whosFree.root"].waitForExistence(timeout: 12)
                || app.tabBars.buttons["tab.schedule"].waitForExistence(timeout: 8),
            "BVT-44: iPad reaches main navigation"
        )
    }
}
