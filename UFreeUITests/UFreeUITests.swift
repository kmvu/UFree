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

extension XCUIApplication {
    /// Tap a schedule day card that may be clipped in the week carousel.
    ///
    /// Do not query `isHittable`: XCTest fails the test when a combined
    /// accessibility button is off-screen ("Activation point invalid and no
    /// suggested hit points"). Scroll the named carousel until the card's
    /// frame intersects the window, then coordinate-tap.
    func tapScheduleDayCard(_ card: XCUIElement) {
        let carousel = descendants(matching: .any)["schedule.weekCarousel"]
        _ = carousel.waitForExistence(timeout: 3)
        let bounds = windows.firstMatch.frame
        let deadline = Date().addingTimeInterval(6)

        while Date() < deadline {
            if isMostlyVisible(card.frame, in: bounds) { break }
            if carousel.exists {
                let from = carousel.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
                let to = carousel.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
                from.press(forDuration: 0.05, thenDragTo: to)
            } else {
                swipeLeft()
            }
        }

        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func isMostlyVisible(_ frame: CGRect, in bounds: CGRect) -> Bool {
        guard frame.width > 1, frame.height > 1 else { return false }
        let visible = frame.intersection(bounds)
        return visible.width >= min(40, frame.width * 0.6)
            && visible.height >= min(40, frame.height * 0.6)
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
            app.tabBars.buttons["tab.schedule"].waitForExistence(timeout: 20),
            "UI_TESTING_MODE should land on authenticated tabs"
        )
    }
}
