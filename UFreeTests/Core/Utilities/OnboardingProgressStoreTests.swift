//
//  OnboardingProgressStoreTests.swift
//  UFreeTests
//

import XCTest
@testable import UFree

@MainActor
final class OnboardingProgressStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var sut: OnboardingProgressStore!

    override func setUp() {
        super.setUp()
        suiteName = "OnboardingProgressStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        sut = OnboardingProgressStore(defaults: defaults)
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

    func test_shouldShowPairChecklist_trueWhenNoHandshakeAndNoFriends() {
        XCTAssertTrue(sut.shouldShowPairChecklist(friendCount: 0))
    }

    func test_shouldShowPairChecklist_falseWhenFriendsExist() {
        XCTAssertFalse(sut.shouldShowPairChecklist(friendCount: 1))
    }

    func test_shouldShowPairChecklist_falseAfterHandshake() {
        sut.markFirstHandshake()
        XCTAssertFalse(sut.shouldShowPairChecklist(friendCount: 0))
    }

    func test_acknowledgeExistingFriends_setsHandshakeWithoutWeekendCTA() {
        sut.acknowledgeExistingFriends()

        XCTAssertTrue(sut.hasCompletedFirstHandshake)
        XCTAssertFalse(sut.pendingWeekendCTA)
        XCTAssertFalse(sut.shouldShowPairChecklist(friendCount: 0))
    }

    func test_markFirstHandshake_setsPendingWeekendCTA() {
        sut.markFirstHandshake()
        XCTAssertTrue(sut.pendingWeekendCTA)
    }
}
