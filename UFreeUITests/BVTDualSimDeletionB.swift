//
//  BVTDualSimDeletionB.swift
//  UFreeUITests
//
//  Layer C session 4 — persona 2 sees the deleted peer leave Friends / Who's Free.
//

import XCTest

final class BVTDualSimDeletionB: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try MailboxClient.requireMailbox()
    }

    @MainActor
    func test_acceptor_losesDeletedPeer() async throws {
        try await MailboxClient.waitFor("readyA", timeout: 60)
        let app = DualSimFlow.launchPersona(2)
        try await MailboxClient.post("readyB")

        try await MailboxClient.waitFor("requested", timeout: 60)
        DualSimFlow.acceptIncoming(app)
        try await MailboxClient.post("accepted")

        app.openFriendsTab()
        XCTAssertTrue(
            app.staticTexts[DualSimFlow.persona1Name].waitForExistence(timeout: 15),
            "BVT-48 setup: \(DualSimFlow.persona1Name) is in Friends before delete"
        )
        try await MailboxClient.waitFor("deleted", timeout: 90)
        DualSimFlow.assertPeerGone(app, name: DualSimFlow.persona1Name)
        try await MailboxClient.post("peerGone")
    }
}
