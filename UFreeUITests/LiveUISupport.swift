//
//  LiveUISupport.swift
//  UFreeUITests
//
//  Shared launch + handshake for Layer B emulator UI tests.
//

import XCTest

enum LiveUIFlow {
    @MainActor
    static func prepareDriver() async throws -> PeerDriver {
        try EmulatorUILaunch.requireEmulator()
        let driver = PeerDriver()
        try await driver.resetEmulatorData()
        return driver
    }

    @MainActor
    static func launchPersona1(extraArguments: [String] = []) -> XCUIApplication {
        let app = EmulatorUILaunch.makeApp(persona: 1, extraArguments: extraArguments)
        app.launch()
        EmulatorUILaunch.waitForPersonaReady(app, persona: 1)
        app.dismissBlockingSheets()
        return app
    }

    @MainActor
    static func launchFreshPersona1(extraArguments: [String] = []) async throws -> (PeerDriver, XCUIApplication) {
        let driver = try await prepareDriver()
        return (driver, launchPersona1(extraArguments: extraArguments))
    }

    /// Seeds Test User 2, sends them as the incoming request, persona 1 accepts.
    @MainActor
    static func acceptSeededPeer(
        _ driver: PeerDriver,
        app: XCUIApplication,
        seedIndex: Int = 1
    ) async throws -> (peer: PeerSession, persona1Uid: String) {
        let peer = try await driver.seedPersona(seedIndex)
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
        XCTAssertTrue(accept.waitForExistence(timeout: 16), "Incoming request from \(peer.displayName)")
        accept.tap()
        app.dismissConnectChrome()
        app.openFriendsTab()
        XCTAssertTrue(
            app.staticTexts[peer.displayName].waitForExistence(timeout: 12)
                || app.descendants(matching: .any)["friends.friend.\(peer.uid)"].waitForExistence(timeout: 4),
            "\(peer.displayName) should be in Friends after accept"
        )
        return (peer, persona1Uid)
    }
}
