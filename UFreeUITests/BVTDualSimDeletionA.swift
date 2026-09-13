//
//  BVTDualSimDeletionA.swift
//  UFreeUITests
//
//  Layer C session 4 — persona 1 deletes after a live handshake.
//

import XCTest

final class BVTDualSimDeletionA: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try MailboxClient.requireMailbox()
    }

    @MainActor
    func test_inviter_deletesAccount_andReturnsToLogin() async throws {
        let app = DualSimFlow.launchPersona(1)
        try await MailboxClient.post("readyA")
        try await MailboxClient.waitFor("readyB", timeout: 60)

        DualSimFlow.invitePersona2(app)
        try await MailboxClient.post("requested")
        try await MailboxClient.waitFor("accepted", timeout: 60)
        app.dismissConnectChrome()

        DualSimFlow.deleteAccountToLogin(app)
        try await MailboxClient.post("deleted")
        try await MailboxClient.waitFor("peerGone", timeout: 45)
    }
}
