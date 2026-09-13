//
//  BVTDualSimConnectB.swift
//  UFreeUITests
//
//  Layer C session 1 — persona 2 accepts, then sees persona 1 in Friends.
//

import XCTest

final class BVTDualSimConnectB: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try MailboxClient.requireMailbox()
    }

    @MainActor
    func test_acceptor_acceptsAndSeesInviter() async throws {
        try await MailboxClient.waitFor("readyA", timeout: 60)
        let app = DualSimFlow.launchPersona(2)
        try await MailboxClient.post("readyB")

        try await MailboxClient.waitFor("requested", timeout: 60)
        DualSimFlow.acceptIncoming(app)
        try await MailboxClient.post("accepted")

        app.openFriendsTab()
        XCTAssertTrue(
            app.staticTexts[DualSimFlow.persona1Name].waitForExistence(timeout: 15),
            "BVT-15: \(DualSimFlow.persona1Name) is in Friends after accept"
        )
        try await MailboxClient.post("seenB")
        try await MailboxClient.waitFor("seenA", timeout: 30)
    }
}
