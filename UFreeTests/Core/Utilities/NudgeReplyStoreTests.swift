//
//  NudgeReplyStoreTests.swift
//  UFreeTests
//

import XCTest
@testable import UFree

@MainActor
final class NudgeReplyStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var sut: NudgeReplyStore!

    override func setUp() {
        super.setUp()
        suiteName = "NudgeReplyStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        sut = NudgeReplyStore(defaults: defaults)
        sut.bind(userId: "user-a")
    }

    override func tearDown() {
        sut = nil
        if let suiteName {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func test_pendingHangoutPrompts_requiresPastImInWithoutOutcome() {
        sut.record(
            friendId: "friend-1",
            friendName: "Alex",
            dayKey: "2020-01-01",
            response: .imIn
        )
        sut.record(
            friendId: "friend-2",
            friendName: "Blair",
            dayKey: "2099-01-01",
            response: .imIn
        )
        sut.record(
            friendId: "friend-3",
            friendName: "Cara",
            dayKey: "2020-01-02",
            response: .maybe
        )

        let pending = sut.pendingHangoutPrompts(now: Date())
        XCTAssertEqual(pending.map(\.friendId), ["friend-1"])
    }

    func test_markConfirmed_removesPromptAndIsIdempotent() {
        sut.record(
            friendId: "friend-1",
            friendName: "Alex",
            dayKey: "2020-01-01",
            response: .imIn
        )
        sut.markConfirmed(friendId: "friend-1", dayKey: "2020-01-01")
        XCTAssertTrue(sut.isResolved(friendId: "friend-1", dayKey: "2020-01-01"))
        XCTAssertTrue(sut.pendingHangoutPrompts().isEmpty)

        sut.markDismissed(friendId: "friend-1", dayKey: "2020-01-01")
        XCTAssertEqual(
            sut.records.first?.outcome,
            .confirmed,
            "Confirmed outcome must not flip to dismissed"
        )
    }

    func test_bind_scopesRecordsPerUser() {
        sut.record(
            friendId: "friend-1",
            friendName: "Alex",
            dayKey: "2020-01-01",
            response: .imIn
        )
        sut.bind(userId: "user-b")
        XCTAssertTrue(sut.records.isEmpty)

        sut.bind(userId: "user-a")
        XCTAssertEqual(sut.records.count, 1)
    }

    func test_resetAll_clearsRecords() {
        sut.record(
            friendId: "friend-1",
            friendName: "Alex",
            dayKey: "2020-01-01",
            response: .imIn
        )
        sut.resetAll()
        XCTAssertTrue(sut.records.isEmpty)
    }
}
