//
//  BVTConnectLiveUITests.swift
//  UFreeUITests
//
//  Layer B — live handshake against emulators (BVT-12/13/15/16/20).
//  Skips when Auth/Firestore emulators are down.
//

import XCTest

final class BVTConnectLiveUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_personaLogin_reachesTabs_whenEmulatorIsUp() async throws {
        let (_, app) = try await launchPersona1()
        XCTAssertTrue(
            app.tabBars.buttons["tab.schedule"].exists,
            "BVT live: persona 1 reaches Schedule"
        )
    }

    @MainActor
    func test_findByPhone_showsPeerAndRequest() async throws {
        let (driver, app) = try await launchPersona1()
        let peer = try await driver.seedPersona(1)

        app.openFriendsTab()
        app.searchFriendsPhone(peer.phoneNumber)

        let row = app.descendants(matching: .any)["friends.friend.\(peer.uid)"]
        XCTAssertTrue(
            row.waitForExistence(timeout: 10) || app.staticTexts[peer.displayName].waitForExistence(timeout: 4),
            "BVT-12: \(peer.displayName) appears from phone search"
        )
        XCTAssertTrue(
            app.buttons["friends.request"].waitForExistence(timeout: 6),
            "BVT-12: Request is offered for a new peer"
        )
    }

    @MainActor
    func test_requestThenPeerAccept_showsConnected() async throws {
        let (driver, app) = try await launchPersona1()
        let peer = try await driver.seedPersona(1)
        let persona1Uid = try await driver.waitForUid(
            phoneNumber: PeerDriver.personaPhones[0],
            readerIdToken: peer.idToken
        )

        app.openFriendsTab()
        app.searchFriendsPhone(peer.phoneNumber)
        let request = app.buttons["friends.request"]
        XCTAssertTrue(request.waitForExistence(timeout: 10), "BVT-13: Request")
        request.tap()
        if request.exists { request.tap() }

        try await driver.acceptFriendRequest(
            fromId: persona1Uid,
            toId: peer.uid,
            recipientIdToken: peer.idToken
        )

        let connected = app.staticTexts["Connected"]
        let row = app.descendants(matching: .any)["friends.friend.\(peer.uid)"]
        XCTAssertTrue(
            connected.waitForExistence(timeout: 12) || row.waitForExistence(timeout: 6),
            "BVT-15/20: peer accept lands \(peer.displayName) in the trusted circle"
        )
        XCTAssertFalse(
            app.buttons["friends.request"].exists,
            "BVT-20: Request must not remain after the handshake"
        )
    }

    @MainActor
    func test_incomingRequest_acceptAddsPeer() async throws {
        let (driver, app) = try await launchPersona1()
        let peer = try await driver.seedPersona(1)
        let persona1Uid = try await driver.waitForUid(
            phoneNumber: PeerDriver.personaPhones[0],
            readerIdToken: peer.idToken
        )

        try await driver.sendFriendRequest(
            fromId: peer.uid,
            fromName: peer.displayName,
            toId: persona1Uid,
            senderIdToken: peer.idToken
        )

        app.openFriendsTab()
        let accept = app.firstExisting(
            app.buttons["friends.accept"],
            app.buttons["Accept"]
        )
        XCTAssertTrue(accept.waitForExistence(timeout: 12), "BVT-15: incoming request from \(peer.displayName)")
        accept.tap()
        app.dismissConnectChrome()
        app.openFriendsTab()

        let peerRow = app.firstExisting(
            app.descendants(matching: .any)["friends.friend.\(peer.uid)"],
            app.staticTexts[peer.displayName]
        )
        XCTAssertTrue(
            peerRow.waitForExistence(timeout: 12),
            "BVT-15: accepting adds \(peer.displayName) to Friends"
        )
    }

    @MainActor
    func test_removeFriend_dropsPeer() async throws {
        let (driver, app) = try await launchPersona1()
        let peer = try await driver.seedPersona(1)
        let persona1Uid = try await driver.waitForUid(
            phoneNumber: PeerDriver.personaPhones[0],
            readerIdToken: peer.idToken
        )

        try await driver.sendFriendRequest(
            fromId: peer.uid,
            fromName: peer.displayName,
            toId: persona1Uid,
            senderIdToken: peer.idToken
        )

        app.openFriendsTab()
        let accept = app.firstExisting(
            app.buttons["friends.accept"],
            app.buttons["Accept"]
        )
        XCTAssertTrue(accept.waitForExistence(timeout: 12))
        accept.tap()
        app.dismissConnectChrome()
        app.openFriendsTab()

        let row = app.descendants(matching: .any)["friends.friend.\(peer.uid)"]
        XCTAssertTrue(
            row.waitForExistence(timeout: 12) || app.staticTexts[peer.displayName].waitForExistence(timeout: 4),
            "Peer is in the circle before remove"
        )

        let remove = app.buttons["friends.remove"]
        XCTAssertTrue(remove.waitForExistence(timeout: 6), "BVT-16: Remove")
        remove.tap()
        if app.alerts.buttons["Remove"].waitForExistence(timeout: 3) {
            app.alerts.buttons["Remove"].tap()
        }

        XCTAssertTrue(
            row.waitForNonExistence(timeout: 8)
                || app.staticTexts[peer.displayName].waitForNonExistence(timeout: 4),
            "BVT-16: \(peer.displayName) leaves the friends list"
        )
    }

    @MainActor
    func test_unknownPhone_doesNotLeakAProfile() async throws {
        let (_, app) = try await launchPersona1()
        app.openFriendsTab()
        app.searchFriendsPhone("+15559999999")

        let notFound = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "No user found")
        ).firstMatch
        XCTAssertTrue(notFound.waitForExistence(timeout: 10), "BVT-14: unknown number is a generic miss")
        XCTAssertFalse(
            app.staticTexts[PeerDriver.personaNames[1]].exists,
            "BVT-14: a miss must not reveal another member"
        )
        XCTAssertFalse(
            app.staticTexts["+15559999999"].exists,
            "BVT-14: raw phone numbers stay off the friends list"
        )
    }

    @MainActor
    func test_declineIncomingRequest_removesRow() async throws {
        let (driver, app) = try await launchPersona1()
        let peer = try await driver.seedPersona(1)
        let persona1Uid = try await driver.waitForUid(
            phoneNumber: PeerDriver.personaPhones[0],
            readerIdToken: peer.idToken
        )
        try await driver.sendFriendRequest(
            fromId: peer.uid,
            fromName: peer.displayName,
            toId: persona1Uid,
            senderIdToken: peer.idToken
        )

        app.openFriendsTab()
        let decline = app.firstExisting(
            app.buttons["friends.decline"],
            app.buttons["xmark"]
        )
        XCTAssertTrue(decline.waitForExistence(timeout: 12), "BVT-19: Decline")
        decline.tap()
        XCTAssertTrue(
            app.buttons["friends.accept"].waitForNonExistence(timeout: 8),
            "BVT-19: declined request leaves the incoming list"
        )
    }

    @MainActor
    func test_syncContactsControlExists() async throws {
        let (_, app) = try await launchPersona1()
        app.openFriendsTab()
        XCTAssertTrue(
            app.buttons["friends.syncContacts"].waitForExistence(timeout: 10),
            "BVT-21: Sync Contacts is available"
        )
    }

    @MainActor
    private func launchPersona1() async throws -> (PeerDriver, XCUIApplication) {
        try await LiveUIFlow.launchFreshPersona1()
    }
}
