//
//  BVTDualSimConnectB.swift
//  UFreeUITests
//
//  Layer C session 1 — acceptor (persona 2). Skips unless BVT_MAILBOX_URL is set.
//

import XCTest

final class BVTDualSimConnectB: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard ProcessInfo.processInfo.environment["BVT_MAILBOX_URL"] != nil else {
            throw XCTSkip("Layer C requires BVT_MAILBOX_URL from Scripts/run_dual_sim_bvt.sh")
        }
    }

    @MainActor
    func test_acceptor_waitsForInviter_thenReachesTabs() async throws {
        try await MailboxClient.waitFor("readyA", timeout: 45)

        let app = EmulatorUILaunch.makeApp(persona: 2)
        app.launch()

        let onTabs = app.tabBars.buttons["tab.schedule"].waitForExistence(timeout: 30)
            || app.buttons["login.persona.2"].waitForExistence(timeout: 8)
        XCTAssertTrue(onTabs, "Peer B should reach login or Schedule")

        if app.buttons["login.persona.2"].exists {
            app.buttons["login.persona.2"].tap()
            XCTAssertTrue(app.tabBars.buttons["tab.schedule"].waitForExistence(timeout: 25))
        }

        try await MailboxClient.post("readyB")
    }
}
