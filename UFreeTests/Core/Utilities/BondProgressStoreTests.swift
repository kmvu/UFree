//
//  BondProgressStoreTests.swift
//  UFreeTests
//

import XCTest
@testable import UFree

@MainActor
final class BondProgressStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var sut: BondProgressStore!

    override func setUp() {
        super.setUp()
        suiteName = "BondProgressStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        sut = BondProgressStore(defaults: defaults)
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

    func test_recordHang_returnsMilestonesAtOneFiveTen() {
        XCTAssertEqual(sut.recordHang(friendId: "f1", dayKey: "2020-01-01"), 1)
        XCTAssertNil(sut.recordHang(friendId: "f1", dayKey: "2020-01-02"))
        XCTAssertNil(sut.recordHang(friendId: "f1", dayKey: "2020-01-03"))
        XCTAssertNil(sut.recordHang(friendId: "f1", dayKey: "2020-01-04"))
        XCTAssertEqual(sut.recordHang(friendId: "f1", dayKey: "2020-01-05"), 5)
        for day in 6...9 {
            XCTAssertNil(sut.recordHang(friendId: "f1", dayKey: "2020-01-0\(day)"))
        }
        XCTAssertEqual(sut.recordHang(friendId: "f1", dayKey: "2020-01-10"), 10)
        XCTAssertEqual(sut.hangsConfirmed(for: "f1"), 10)
    }

    func test_recordHang_isIdempotentPerFriendDay() {
        XCTAssertEqual(sut.recordHang(friendId: "f1", dayKey: "2020-01-01"), 1)
        XCTAssertNil(sut.recordHang(friendId: "f1", dayKey: "2020-01-01"))
        XCTAssertEqual(sut.hangsConfirmed(for: "f1"), 1)
        XCTAssertTrue(sut.hasRecordedHang(friendId: "f1", dayKey: "2020-01-01"))
    }

    func test_incrementNudge_countsPerFriend() {
        sut.incrementNudge(friendId: "f1")
        sut.incrementNudge(friendId: "f1")
        sut.incrementNudge(friendId: "f2")
        XCTAssertEqual(sut.nudgesExchanged(for: "f1"), 2)
        XCTAssertEqual(sut.nudgesExchanged(for: "f2"), 1)
    }

    func test_bind_scopesCountersPerUser() {
        _ = sut.recordHang(friendId: "f1", dayKey: "2020-01-01")
        sut.bind(userId: "user-b")
        XCTAssertEqual(sut.hangsConfirmed(for: "f1"), 0)

        sut.bind(userId: "user-a")
        XCTAssertEqual(sut.hangsConfirmed(for: "f1"), 1)
    }

    func test_resetAll_clearsCounters() {
        _ = sut.recordHang(friendId: "f1", dayKey: "2020-01-01")
        sut.incrementNudge(friendId: "f1")
        sut.resetAll()
        XCTAssertEqual(sut.hangsConfirmed(for: "f1"), 0)
        XCTAssertEqual(sut.nudgesExchanged(for: "f1"), 0)
    }
}
