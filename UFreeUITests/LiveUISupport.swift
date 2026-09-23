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

        waitForIncomingHandshakeRow(app, peerName: peer.displayName)
        let accept = app.firstExisting(
            app.buttons["friends.accept"],
            app.buttons["Accept"]
        )
        XCTAssertTrue(accept.waitForExistence(timeout: 8), "Incoming request from \(peer.displayName)")
        accept.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.dismissConnectChrome()
        app.openFriendsTab()
        XCTAssertTrue(
            app.staticTexts[peer.displayName].waitForExistence(timeout: 12)
                || app.descendants(matching: .any)["friends.friend.\(peer.uid)"].waitForExistence(timeout: 4),
            "\(peer.displayName) should be in Friends after accept"
        )
        return (peer, persona1Uid)
    }

    /// Incoming requests sit below the discovery card; Firestore can lag on CI.
    /// Bounce Friends and scroll until Accept / Decline / the peer name is in the tree.
    @MainActor
    static func waitForIncomingHandshakeRow(_ app: XCUIApplication, peerName: String) {
        app.dismissBlockingSheets()
        app.openFriendsTab()
        let deadline = Date().addingTimeInterval(22)
        while Date() < deadline {
            app.dismissBlockingSheets()
            if incomingHandshakeRowVisible(app) {
                return
            }
            app.swipeUp()
            if incomingHandshakeRowVisible(app) {
                return
            }
            app.openScheduleTab()
            app.openFriendsTab()
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        }
        XCTAssertTrue(
            incomingHandshakeRowVisible(app),
            "Incoming request from \(peerName) should appear on Friends"
        )
    }

    @MainActor
    private static func incomingHandshakeRowVisible(_ app: XCUIApplication) -> Bool {
        app.buttons["friends.accept"].exists
            || app.buttons["friends.decline"].exists
            || app.buttons["Accept"].exists
            || app.buttons["Decline"].exists
    }
}
