//
//  BVTDualSimNudgeB.swift
//  UFreeUITests
//
//  Layer C session 3 — persona 2 answers the live nudge from the inbox.
//

import XCTest

final class BVTDualSimNudgeB: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try MailboxClient.requireMailbox()
    }

    @MainActor
    func test_acceptor_repliesImIn_fromInbox() async throws {
        let app = DualSimFlow.launchPersona(2)
        try await MailboxClient.post("readyB")

        try await MailboxClient.waitFor("requested", timeout: 60)
        DualSimFlow.acceptIncoming(app)
        try await MailboxClient.post("accepted")

        try await MailboxClient.waitFor("markedFree", timeout: 60)
        DualSimFlow.assertFriendVisibleOnWhosFree(app, name: DualSimFlow.persona1Name)
        try await MailboxClient.post("peerSeesFree")

        DualSimFlow.markTodayFree(app)
        try await MailboxClient.post("peerMarkedFree")

        try await MailboxClient.waitFor("nudged", timeout: 60)
        DualSimFlow.replyImInFromInbox(app)
        try await MailboxClient.post("replied")
        try await MailboxClient.waitFor("replySeenA", timeout: 45)
    }
}
