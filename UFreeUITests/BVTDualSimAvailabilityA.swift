//
//  BVTDualSimAvailabilityA.swift
//  UFreeUITests
//
//  Layer C session 2 — persona 1 invites, marks today free, then sees Both.
//

import XCTest

final class BVTDualSimAvailabilityA: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try MailboxClient.requireMailbox()
    }

    @MainActor
    func test_inviter_connects_marksFree_andSeesBoth() async throws {
        let app = DualSimFlow.launchPersona(1)
        try await MailboxClient.post("readyA")
        try await MailboxClient.waitFor("readyB", timeout: 120)

        DualSimFlow.invitePersona2(app)
        try await MailboxClient.post("requested")
        try await MailboxClient.waitFor("accepted", timeout: 60)
        app.dismissConnectChrome()

        DualSimFlow.markTodayFree(app)
        try await MailboxClient.post("markedFree")
        try await MailboxClient.waitFor("peerSeesFree", timeout: 90)
        try await MailboxClient.waitFor("peerMarkedFree", timeout: 60)

        DualSimFlow.assertBothCue(app)
        try await MailboxClient.post("bothSeenA")
    }
}
