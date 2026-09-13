//
//  BVTDualSimAvailabilityB.swift
//  UFreeUITests
//
//  Layer C session 2 — persona 2 accepts, sees A's free day, marks today free.
//

import XCTest

final class BVTDualSimAvailabilityB: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try MailboxClient.requireMailbox()
    }

    @MainActor
    func test_acceptor_seesPeerFreeDay_thenMarksToday() async throws {
        try await MailboxClient.waitFor("readyA", timeout: 60)
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

        DualSimFlow.assertBothCue(app)
        try await MailboxClient.waitFor("bothSeenA", timeout: 45)
    }
}
