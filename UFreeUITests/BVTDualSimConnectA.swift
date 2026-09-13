//
//  BVTDualSimConnectA.swift
//  UFreeUITests
//
//  Layer C session 1 — persona 1 invites, then sees persona 2 in Friends.
//

import XCTest

final class BVTDualSimConnectA: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try MailboxClient.requireMailbox()
    }

    @MainActor
    func test_inviter_requestsAndSeesAcceptedPeer() async throws {
        let app = DualSimFlow.launchPersona(1)
        try await MailboxClient.post("readyA")
        try await MailboxClient.waitFor("readyB", timeout: 60)

        DualSimFlow.invitePersona2(app)
        try await MailboxClient.post("requested")
        try await MailboxClient.waitFor("accepted", timeout: 60)
        app.dismissConnectChrome()

        app.openFriendsTab()
        XCTAssertTrue(
            app.staticTexts[DualSimFlow.persona2Name].waitForExistence(timeout: 15),
            "BVT-15/20: \(DualSimFlow.persona2Name) is in Friends after accept"
        )
        try await MailboxClient.post("seenA")
        try await MailboxClient.waitFor("seenB", timeout: 30)
    }
}
