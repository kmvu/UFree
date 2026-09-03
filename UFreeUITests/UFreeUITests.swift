//
//  UFreeUITests.swift
//  UFreeUITests
//
//  Shared UI-test launch helpers.
//

import XCTest

enum UITestLaunch {
    static func makeApp(arguments: [String] = ["UI_TESTING_MODE"]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        return app
    }
}

final class UFreeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch_withUITestingMode_reachesMainTabs() throws {
        let app = UITestLaunch.makeApp()
        app.launch()

        XCTAssertTrue(
            app.tabBars.buttons["tab.schedule"].waitForExistence(timeout: 10),
            "UI_TESTING_MODE should land on authenticated tabs"
        )
    }
}
