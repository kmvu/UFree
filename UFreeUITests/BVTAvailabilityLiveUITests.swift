//
//  BVTAvailabilityLiveUITests.swift
//  UFreeUITests
//
//  Layer B — live Who's Free against emulators (BVT-10 / 28).
//

import XCTest

final class BVTAvailabilityLiveUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_peerMarksFree_showsOnWhosFreeAndBoth() async throws {
        let (driver, app) = try await LiveUIFlow.launchFreshPersona1()
        let (peer, _) = try await LiveUIFlow.acceptSeededPeer(driver, app: app)

        DualSimFlow.markTodayFree(app)
        let today = UITestDates.todayDateString()
        try await driver.markDayFree(uid: peer.uid, idToken: peer.idToken, dateString: today)

        app.openScheduleTab()
        DualSimFlow.assertFriendVisibleOnWhosFree(app, name: peer.displayName)
        DualSimFlow.assertBothCue(app)
    }
}
