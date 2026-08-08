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

    func test_shouldShowPairOnboardingBanner_trueWhenNoHandshakeAndNoFriends() {
        XCTAssertTrue(sut.shouldShowPairOnboardingBanner(friendCount: 0))
    }

    func test_shouldShowPairOnboardingBanner_falseWhenFriendsExist() {
        XCTAssertFalse(sut.shouldShowPairOnboardingBanner(friendCount: 1))
    }

    func test_shouldShowPairOnboardingBanner_falseAfterHandshake() {
        sut.markFirstHandshake()
        XCTAssertFalse(sut.shouldShowPairOnboardingBanner(friendCount: 0))
    }

    func test_shouldShowPairOnboardingBanner_falseAfterPermanentDismiss() {
        sut.dismissPairChecklistPermanently()
        XCTAssertTrue(sut.hasDismissedPairChecklist)
        XCTAssertFalse(sut.shouldShowPairOnboardingBanner(friendCount: 0))
    }

    func test_acknowledgeExistingFriends_setsHandshakeWithoutWeekendCTA() {
        sut.acknowledgeExistingFriends()

        XCTAssertTrue(sut.hasCompletedFirstHandshake)
        XCTAssertFalse(sut.pendingWeekendCTA)
        XCTAssertFalse(sut.shouldShowPairOnboardingBanner(friendCount: 0))
    }

    func test_markFirstHandshake_setsPendingWeekendCTA() {
        sut.markFirstHandshake()
        XCTAssertTrue(sut.pendingWeekendCTA)
    }

    func test_pairOnboardingBannerTitle_tracksNextStep() {
        XCTAssertEqual(sut.pairOnboardingBannerTitle, "Invite 1 friend to start")
        XCTAssertEqual(sut.pairOnboardingCompletedSteps, 0)

        sut.markInvitedFriend()
        XCTAssertEqual(sut.pairOnboardingBannerTitle, "Mark when you're free")
        XCTAssertEqual(sut.pairOnboardingCompletedSteps, 1)

        sut.markFreeDay()
        XCTAssertEqual(sut.pairOnboardingBannerTitle, "Waiting for them to accept")
        XCTAssertEqual(sut.pairOnboardingCompletedSteps, 2)
    }

    func test_shouldShowPairChecklist_matchesBannerAPI() {
        XCTAssertEqual(
            sut.shouldShowPairChecklist(friendCount: 0),
            sut.shouldShowPairOnboardingBanner(friendCount: 0)
        )
        sut.dismissPairChecklistPermanently()
        XCTAssertEqual(
            sut.shouldShowPairChecklist(friendCount: 0),
            sut.shouldShowPairOnboardingBanner(friendCount: 0)
        )
    }
}
