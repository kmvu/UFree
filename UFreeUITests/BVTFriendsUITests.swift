//
//  BVTFriendsUITests.swift
//  UFreeUITests
//
//  BVT-12, 13, 16, 20, 21 — phone search, request guard, remove, connected state, contacts.
//

import XCTest

final class BVTFriendsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_findByPhone_showsJordanAndRequest() throws {
        let app = UITestLaunch.makeApp()
        app.launch()
        app.openFriendsTab()
        app.searchFriendsPhone("+15551234567")

        let jordan = app.firstExisting(
            app.descendants(matching: .any)["friends.friend.jordan-ui-test"],
            app.staticTexts["Jordan"]
        )
        XCTAssertTrue(jordan.waitForExistence(timeout: 8), "BVT-12: Jordan appears")
        XCTAssertTrue(app.buttons["friends.request"].waitForExistence(timeout: 4), "BVT-12: Request button")
    }

    @MainActor
    func test_requestButton_disablesWhileSending() throws {
        let app = UITestLaunch.makeApp()
        app.launch()
        app.openFriendsTab()
        app.searchFriendsPhone("+15551234567")

        let request = app.buttons["friends.request"]
        XCTAssertTrue(request.waitForExistence(timeout: 8), "BVT-13: Request")
        request.tap()
        if request.exists { request.tap() }
        if request.exists { request.tap() }

        XCTAssertTrue(
            request.waitForNonExistence(timeout: 6) || !request.exists || !request.isEnabled,
            "BVT-13: rapid taps do not leave a stuck enabled Request"
        )
    }

    @MainActor
    func test_removeFriend_dropsAlexRow() throws {
        let app = UITestLaunch.makeApp()
        app.launch()
        app.openFriendsTab()

        let alex = app.descendants(matching: .any)["friends.friend.alex-ui-test"]
        XCTAssertTrue(alex.waitForExistence(timeout: 8), "Alex is seeded")

        let remove = app.buttons["friends.remove"]
        XCTAssertTrue(remove.waitForExistence(timeout: 4), "BVT-16: Remove")
        remove.tap()

        let confirm = app.alerts.buttons["Remove"]
        if confirm.waitForExistence(timeout: 3) {
            confirm.tap()
        }

        XCTAssertTrue(
            alex.waitForNonExistence(timeout: 6),
            "BVT-16: Alex leaves the friends list"
        )
    }

    @MainActor
    func test_connectedFriend_hasNoRequestButton() throws {
        let app = UITestLaunch.makeApp()
        app.launch()
        app.openFriendsTab()

        let alex = app.descendants(matching: .any)["friends.friend.alex-ui-test"]
        XCTAssertTrue(alex.waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.staticTexts["Connected"].waitForExistence(timeout: 3),
            "BVT-20: connected caption"
        )
        XCTAssertFalse(
            app.buttons["friends.request"].exists,
            "BVT-20: Request must not appear on a connected row"
        )
    }

    @MainActor
    func test_unknownPhone_doesNotLeakAProfile() throws {
        let app = UITestLaunch.makeApp(scenario: "empty")
        app.launch()
        app.openFriendsTab()
        app.searchFriendsPhone("+15559999999")

        let notFound = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "No user found")
        ).firstMatch
        XCTAssertTrue(notFound.waitForExistence(timeout: 8), "BVT-14: unknown number is a generic miss")
        XCTAssertFalse(
            app.descendants(matching: .any)["friends.friend.jordan-ui-test"].exists,
            "BVT-14: a miss must not reveal another member"
        )
        XCTAssertFalse(
            app.staticTexts["+15551234567"].exists,
            "BVT-14: raw phone numbers stay off the friends list"
        )
    }

    @MainActor
    func test_declineRequest_removesCaseyRow() throws {
        let app = UITestLaunch.makeApp()
        app.launch()
        app.openFriendsTab()

        let decline = app.firstExisting(
            app.buttons["friends.decline"],
            app.buttons["xmark"]
        )
        XCTAssertTrue(decline.waitForExistence(timeout: 8), "BVT-19: Decline on Casey's request")
        decline.tap()

        XCTAssertTrue(
            app.buttons["friends.accept"].waitForNonExistence(timeout: 6),
            "BVT-19: declined request leaves the incoming list"
        )
    }

    @MainActor
    func test_syncContactsControlExists() throws {
        let app = UITestLaunch.makeApp(scenario: "empty")
        app.launch()
        app.openFriendsTab()

        XCTAssertTrue(
            app.buttons["friends.syncContacts"].waitForExistence(timeout: 8),
            "BVT-21: Sync Contacts is available when there are no discovered matches"
        )
    }
}
