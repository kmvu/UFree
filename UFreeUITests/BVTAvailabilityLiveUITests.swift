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
        app.openWhosFreeTab()
        DualSimFlow.focusTodayChipIfNeeded(app)
        let today = UITestDates.todayDateString()
        try await driver.markDayFree(uid: peer.uid, idToken: peer.idToken, dateString: today)

        LiveExpectation.expectLive(
            app.staticTexts[peer.displayName],
            within: 15,
            update: "\(peer.displayName) free on Who's Free"
        )
        DualSimFlow.assertBothCue(app)
    }

    @MainActor
    func test_backgroundThenReturn_showsPeerFreeDay() async throws {
        let (driver, app) = try await LiveUIFlow.launchFreshPersona1()
        let (peer, _) = try await LiveUIFlow.acceptSeededPeer(driver, app: app)
        app.openWhosFreeTab()
        DualSimFlow.focusTodayChipIfNeeded(app)

        XCUIDevice.shared.press(.home)
        let today = UITestDates.todayDateString()
        try await driver.markDayFree(uid: peer.uid, idToken: peer.idToken, dateString: today)
        app.activate()

        LiveExpectation.expectLive(
            app.staticTexts[peer.displayName],
            within: 15,
            update: "\(peer.displayName) free after returning to the foreground"
        )
    }
}
