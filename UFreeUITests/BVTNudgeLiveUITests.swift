//
//  BVTNudgeLiveUITests.swift
//  UFreeUITests
//
//  Layer B — live nudge + I'm in via PeerDriver (BVT-33 / 36).
//

import XCTest

final class BVTNudgeLiveUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_nudgePeer_restReplyShowsIn() async throws {
        let (driver, app) = try await LiveUIFlow.launchFreshPersona1()
        let (peer, persona1Uid) = try await LiveUIFlow.acceptSeededPeer(driver, app: app)

        DualSimFlow.markTodayFree(app)
        let today = UITestDates.todayDateString()
        try await driver.markDayFree(uid: peer.uid, idToken: peer.idToken, dateString: today)

        DualSimFlow.nudgePeerOnToday(app, name: peer.displayName)
        try await driver.sendNudgeReply(
            to: persona1Uid,
            from: peer.uid,
            fromName: peer.displayName,
            targetDateString: today,
            idToken: peer.idToken
        )

        DualSimFlow.assertInReplyOnWhosFree(app, name: peer.displayName)
    }
}
