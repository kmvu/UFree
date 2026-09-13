//
//  BVTDualSimConnectA.swift
//  UFreeUITests
//
//  Layer C session 1 — inviter (persona 1). Skips unless BVT_MAILBOX_URL is set.
//

import XCTest

final class BVTDualSimConnectA: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try MailboxClient.requireMailbox()
    }

    @MainActor
    func test_inviter_reachesTabs_andSignalsReady() async throws {
        _ = DualSimFlow.launchPersona(1)
        try await MailboxClient.post("readyA")
    }
}

