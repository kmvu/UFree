//
//  InboxUITests.swift
//  UFreeUITests
//
//  Accept + nudge-reply under UI_TESTING_MODE (seeded Casey request + Alex nudge).
//

import XCTest

final class InboxUITests: XCTestCase {

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
    func test_acceptFriendRequest_fromNotificationCenter() throws {
        openNotificationCenter()

        let accept = firstExisting(
            app.buttons["notifications.accept"],
            app.buttons["Accept"]
        )
        XCTAssertTrue(accept.waitForExistence(timeout: 5), "Expected Accept on Casey's request")
        accept.tap()

        // Subsequent-friend accept shows a toast and auto-dismisses the inbox.
        let caseyToast = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Casey")
        ).firstMatch
        XCTAssertTrue(
            caseyToast.waitForExistence(timeout: 6),
            "Accept should celebrate Casey (toast or Connected row)"
        )

        let inbox = app.descendants(matching: .any)["notifications.root"]
        if inbox.exists {
            _ = inbox.waitForNonExistence(timeout: 8)
        } else if app.buttons["Done"].waitForExistence(timeout: 2) {
            app.buttons["Done"].tap()
        }

        let friendsTab = app.tabBars.buttons["tab.friends"]
        XCTAssertTrue(friendsTab.waitForExistence(timeout: 8))
        friendsTab.tap()

        let casey = firstExisting(
            app.descendants(matching: .any)["friends.friend.casey-ui-test"],
            app.staticTexts["Casey"]
        )
        XCTAssertTrue(
            casey.waitForExistence(timeout: 8),
            "Accepting Casey's request should add Casey to Friends"
        )
    }

    @MainActor
    func test_replyToNudge_fromNotificationCenter() throws {
        openNotificationCenter()

        let imIn = app.buttons["notifications.reply.imIn"]
        XCTAssertTrue(imIn.waitForExistence(timeout: 5), "Expected I'm in on Alex's nudge")
        imIn.tap()

        let replied = app.staticTexts["You replied: I'm in"]
        XCTAssertTrue(
            replied.waitForExistence(timeout: 5),
            "Nudge reply should stamp the inbox row"
        )
    }

    private func openNotificationCenter() {
        let scheduleTab = firstExisting(
            app.tabBars.buttons["tab.schedule"],
            app.tabBars.buttons["Schedule"]
        )
        XCTAssertTrue(
            scheduleTab.waitForExistence(timeout: 20),
            "Expected Schedule tab after UI_TESTING_MODE bootstrap"
        )
        scheduleTab.tap()

        let bell = app.buttons["notifications.bell"]
        XCTAssertTrue(
            bell.waitForExistence(timeout: 5),
            "Expected notification bell"
        )
        bell.tap()

        let inbox = app.descendants(matching: .any)["notifications.root"]
        XCTAssertTrue(
            inbox.waitForExistence(timeout: 5) || app.navigationBars["Notifications"].waitForExistence(timeout: 2),
            "Expected notification center"
        )
    }

    private func firstExisting(_ primary: XCUIElement, _ fallback: XCUIElement) -> XCUIElement {
        if primary.waitForExistence(timeout: 2) { return primary }
        return fallback
    }
}
