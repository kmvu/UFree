//
//  UFreeUITests.swift
//  UFreeUITests
//
//  Shared UI-test launch helpers.
//

import XCTest
import UIKit

enum UITestLaunch {
    static func makeApp(
        scenario: String? = nil,
        extraArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["UI_TESTING_MODE"]
        if let scenario {
            arguments.append("UI_TESTING_SCENARIO=\(scenario)")
        }
        arguments.append(contentsOf: extraArguments)
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

    func openScheduleTab() {
        let tab = firstExisting(
            tabBars.buttons["tab.schedule"],
            tabBars.buttons["Schedule"]
        )
        XCTAssertTrue(tab.waitForExistence(timeout: 20), "Expected Schedule tab")
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if tab.isSelected { return }
            tab.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        }
        XCTAssertTrue(tab.isSelected, "Schedule tab should stay selected")
    }

    func openWhosFreeTab() {
        let tab = firstExisting(
            tabBars.buttons["tab.whosFree"],
            tabBars.buttons["Who's Free?"]
        )
        XCTAssertTrue(tab.waitForExistence(timeout: 20), "Expected Who's Free tab")
        tab.tap()
    }

    func openFriendsTab() {
        let tab = firstExisting(
            tabBars.buttons["tab.friends"],
            tabBars.buttons["Add Friends"],
            tabBars.buttons["Friends"]
        )
        XCTAssertTrue(tab.waitForExistence(timeout: 20), "Expected Friends tab")
        tab.tap()
    }

    func searchFriendsPhone(_ number: String) {
        var search = textFields["friends.searchPhone"]
        if !search.waitForExistence(timeout: 3) {
            swipeUp()
            swipeUp()
            search = firstExisting(
                textFields["friends.searchPhone"],
                textFields["Find by Phone Number"]
            )
        }
        XCTAssertTrue(search.waitForExistence(timeout: 8), "Expected Find by Phone field")
        search.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        _ = keyboards.firstMatch.waitForExistence(timeout: 3)
        if keyboards.firstMatch.exists {
            for character in number {
                let key = keys[String(character)]
                if key.exists {
                    key.tap()
                }
            }
        } else {
            typeIntoField(search, number)
        }
        if buttons["arrow.right.circle.fill"].waitForExistence(timeout: 2) {
            buttons["arrow.right.circle.fill"].tap()
        }
    }

    func dismissBlockingSheets() {
        let candidates = [
            buttons["weekend.cta.dismiss"],
            buttons["hangout.checklist.notNow"],
            buttons["Not now"]
        ]
        if descendants(matching: .any)["weekend.cta"].exists
            || descendants(matching: .any)["hangout.checklist.sheet"].exists
            || candidates.contains(where: \.exists) {
            candidates.first(where: \.exists)?.tap()
        }
    }

    func dismissConnectChrome() {
        _ = descendants(matching: .any)["celebration.toast"].waitForExistence(timeout: 3)
        dismissBlockingSheets()
        let cta = descendants(matching: .any)["weekend.cta"]
        if cta.waitForExistence(timeout: 6) {
            dismissBlockingSheets()
            _ = cta.waitForNonExistence(timeout: 4)
        }
    }

    func dayCard(dateString: String) -> XCUIElement {
        let id = "schedule.day.\(dateString)"
        return firstExisting(
            buttons[id],
            descendants(matching: .any).matching(identifier: id).element(boundBy: 0)
        )
    }

    func markDayViaSheet(dateString: String, actionIdentifier: String) {
        let card = dayCard(dateString: dateString)
        XCTAssertTrue(card.waitForExistence(timeout: 5), "Expected day card \(dateString)")
        tapScheduleDayCard(card)

        let action = buttons[actionIdentifier]
        XCTAssertTrue(action.waitForExistence(timeout: 5), "Expected \(actionIdentifier) in day sheet")
        action.tap()

        let save = buttons["schedule.sheet.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        save.tap()
        _ = save.waitForNonExistence(timeout: 4)
    }

    func firstExisting(_ elements: XCUIElement...) -> XCUIElement {
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if let match = elements.first(where: { $0.exists }) {
                return match
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }
        return elements[0]
    }

    /// Focus a SwiftUI text field and type. `tap()` alone often fails to become
    /// first responder on iOS 26 simulators (“Neither element nor any descendant
    /// has keyboard focus”).
    func typeIntoField(_ field: XCUIElement, _ text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Expected text field \(field.identifier)")
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        let focusWait = XCTNSPredicateExpectation(predicate: focused, object: field)
        if XCTWaiter.wait(for: [focusWait], timeout: 2) != .completed {
            field.tap()
            _ = XCTWaiter.wait(
                for: [XCTNSPredicateExpectation(predicate: focused, object: field)],
                timeout: 2
            )
        }

        let isFocused = (field.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
        if isFocused {
            field.typeText(text)
            return
        }

        UIPasteboard.general.string = text
        field.press(forDuration: 1.1)
        let paste = menuItems["Paste"]
        XCTAssertTrue(paste.waitForExistence(timeout: 3), "Could not focus or paste into \(field.identifier)")
        paste.tap()
    }

    func dismissKeyboardIfPresent() {
        if keyboards.firstMatch.exists {
            coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        }
    }

    private func isMostlyVisible(_ frame: CGRect, in bounds: CGRect) -> Bool {
        guard frame.width > 1, frame.height > 1 else { return false }
        let visible = frame.intersection(bounds)
        return visible.width >= min(40, frame.width * 0.6)
            && visible.height >= min(40, frame.height * 0.6)
    }
}

enum UITestDates {
    static func saturdayDateString(from reference: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let weekday = calendar.component(.weekday, from: reference)
        let daysUntilSaturday = (7 - weekday + 7) % 7
        let saturday = calendar.date(byAdding: .day, value: daysUntilSaturday, to: reference)!
        return utcDayKey(saturday)
    }

    static func todayDateString(from reference: Date = Date()) -> String {
        utcDayKey(reference)
    }

    static func utcDayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
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
