//
//  BVTDualSimNudgeA.swift
//  UFreeUITests
//
//  Layer C session 3 — persona 1 nudges after a live handshake; sees I'm in.
//

import XCTest

final class BVTDualSimNudgeA: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try MailboxClient.requireMailbox()
    }

    @MainActor
    func test_inviter_nudgesPeer_andSeesImIn() async throws {
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

        DualSimFlow.nudgePeerOnToday(app, name: DualSimFlow.persona2Name)
        try await MailboxClient.post("nudged")
        try await MailboxClient.waitFor("replied", timeout: 60)

        DualSimFlow.assertInReplyOnWhosFree(app, name: DualSimFlow.persona2Name)
        try await MailboxClient.post("replySeenA")
    }
}
