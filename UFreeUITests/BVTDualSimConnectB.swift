//
//  BVTDualSimConnectB.swift
//  UFreeUITests
//
//  Layer C session 1 — acceptor (persona 2). Skips unless BVT_MAILBOX_URL is set.
//

import XCTest

final class BVTDualSimConnectB: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try MailboxClient.requireMailbox()
    }

    @MainActor
    func test_acceptor_waitsForInviter_thenReachesTabs() async throws {
        try await MailboxClient.waitFor("readyA", timeout: 45)
        _ = DualSimFlow.launchPersona(2)
        try await MailboxClient.post("readyB")
    }
}
