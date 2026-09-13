//
//  BVTDiscoveryLiveUITests.swift
//  UFreeUITests
//
//  Layer B — injected QR (BVT-17) and profile Universal Link (BVT-18).
//

import XCTest

final class BVTDiscoveryLiveUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_scannedProfile_sendsRequestAndConnects() async throws {
        let driver = try await LiveUIFlow.prepareDriver()
        let peer = try await driver.seedPersona(1)
        let app = LiveUIFlow.launchPersona1(
            extraArguments: ["UI_TEST_SCANNED_PROFILE=\(peer.uid)"]
        )

        app.openFriendsTab()
        let persona1Uid = try await driver.waitForUid(
            phoneNumber: PeerDriver.personaPhones[0],
            readerIdToken: peer.idToken
        )
        let requestPath = "friendRequests/\(PeerDriver.friendRequestId(fromId: persona1Uid, toId: peer.uid))"
        try await driver.waitForDocument(path: requestPath, idToken: peer.idToken)

        try await driver.acceptFriendRequest(
            fromId: persona1Uid,
            toId: peer.uid,
            recipientIdToken: peer.idToken
        )

        app.openFriendsTab()
        XCTAssertTrue(
            app.staticTexts[peer.displayName].waitForExistence(timeout: 15)
                || app.descendants(matching: .any)["friends.friend.\(peer.uid)"].waitForExistence(timeout: 4),
            "BVT-17: scanned profile request is accepted into Friends"
        )
    }

    @MainActor
    func test_profileLink_showsPeerAndSendsRequest() async throws {
        let driver = try await LiveUIFlow.prepareDriver()
        let peer = try await driver.seedPersona(1)
        let profileURL = "https://ufree.app/profile/\(peer.uid)"
        let app = LiveUIFlow.launchPersona1(
            extraArguments: ["UI_TEST_OPEN_URL=\(profileURL)"]
        )

        let persona1Uid = try await driver.waitForUid(
            phoneNumber: PeerDriver.personaPhones[0],
            readerIdToken: peer.idToken
        )

        XCTAssertTrue(
            app.descendants(matching: .any)["deepLink.profile"].waitForExistence(timeout: 12)
                || app.staticTexts[peer.displayName].waitForExistence(timeout: 6),
            "BVT-18: profile link shows \(peer.displayName)"
        )
        let send = app.firstExisting(
            app.buttons["deepLink.sendRequest"],
            app.buttons["Send Friend Request"]
        )
        XCTAssertTrue(send.waitForExistence(timeout: 8), "BVT-18: Send Friend Request")
        send.tap()
        _ = send.waitForNonExistence(timeout: 6)

        let requestPath = "friendRequests/\(PeerDriver.friendRequestId(fromId: persona1Uid, toId: peer.uid))"
        try await driver.waitForDocument(path: requestPath, idToken: peer.idToken, timeout: 16)
    }
}
