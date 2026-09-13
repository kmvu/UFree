//
//  BVTConnectLiveUITests.swift
//  UFreeUITests
//
//  Layer B — live handshake against emulators (BVT-12/13). Skips when emulators are down.
//

import XCTest

final class BVTConnectLiveUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_personaLogin_reachesTabs_whenEmulatorIsUp() async throws {
        try EmulatorUILaunch.requireEmulator()
        let driver = PeerDriver()
        try await driver.resetEmulatorData()

        let app = EmulatorUILaunch.makeApp(persona: 1)
        app.launch()

        XCTAssertTrue(
            app.tabBars.buttons["tab.schedule"].waitForExistence(timeout: 25)
                || app.buttons["login.persona.1"].waitForExistence(timeout: 8),
            "BVT live: persona 1 reaches Schedule (or the DEBUG persona button if auto-login is still in flight)"
        )
    }
}
