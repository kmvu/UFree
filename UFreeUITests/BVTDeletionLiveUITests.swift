//
//  BVTDeletionLiveUITests.swift
//  UFreeUITests
//
//  Layer B — peer wipe drops Friends / Who's Free (BVT-48 / 49).
//

import XCTest

final class BVTDeletionLiveUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_peerWipe_leavesFriendsAndWhosFree() async throws {
        let (driver, app) = try await LiveUIFlow.launchFreshPersona1()
        let (peer, persona1Uid) = try await LiveUIFlow.acceptSeededPeer(driver, app: app)

        DualSimFlow.markTodayFree(app)
        try await driver.markDayFree(
            uid: peer.uid,
            idToken: peer.idToken,
            dateString: UITestDates.todayDateString()
        )
        DualSimFlow.assertFriendVisibleOnWhosFree(app, name: peer.displayName)

        try await driver.wipeAccount(
            uid: peer.uid,
            idToken: peer.idToken,
            removeFromUserIds: [persona1Uid]
        )

        DualSimFlow.assertPeerGone(app, name: peer.displayName)
    }
}
