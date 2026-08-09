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

    func test_markFirstHandshake_setsPendingWeekendCTAWhenFreeDayUnmarked() {
        sut.markFirstHandshake()
        XCTAssertTrue(sut.pendingWeekendCTA)
        XCTAssertTrue(sut.shouldPresentWeekendCTAAfterConnection)
    }

    func test_markFirstHandshake_skipsPendingWeekendCTAWhenFreeDayAlreadyMarked() {
        sut.markFreeDay()
        sut.markFirstHandshake()
        XCTAssertFalse(sut.pendingWeekendCTA)
        XCTAssertFalse(sut.shouldPresentWeekendCTAAfterConnection)
    }

    func test_shouldCelebrateFirstConnection_trueOnZeroToOneDuringOnboarding() {
        XCTAssertTrue(sut.shouldCelebrateFirstConnection(previousFriendCount: 0, newFriendCount: 1))
    }

    func test_shouldCelebrateFirstConnection_trueEvenIfHandshakeAcknowledgedWithoutCelebration() {
        // Silent ack must not block the inviter’s live 0→1 celebration.
        sut.acknowledgeExistingFriends()
        XCTAssertTrue(sut.shouldCelebrateFirstConnection(previousFriendCount: 0, newFriendCount: 1))
    }

    func test_shouldCelebrateFirstConnection_falseAfterAlreadyCelebrated() {
        sut.markCelebratedFirstAccept()
        XCTAssertFalse(sut.shouldCelebrateFirstConnection(previousFriendCount: 0, newFriendCount: 1))
    }

    func test_shouldCelebrateFirstConnection_falseWhenNotLeavingZero() {
        XCTAssertFalse(sut.shouldCelebrateFirstConnection(previousFriendCount: 1, newFriendCount: 2))
        XCTAssertFalse(sut.shouldCelebrateFirstConnection(previousFriendCount: 0, newFriendCount: 0))
    }

    func test_pairOnboardingBannerTitle_tracksNextStep() {
        XCTAssertEqual(sut.pairOnboardingBannerTitle, "Invite 1 friend to start")
        XCTAssertEqual(sut.pairOnboardingCompletedSteps, 0)
        XCTAssertEqual(sut.pairOnboardingBannerSubtitle, "0/3 done · Next: Invite a friend")

        sut.markInvitedFriend()
        XCTAssertEqual(sut.pairOnboardingBannerTitle, "Mark when you're free")
        XCTAssertEqual(sut.pairOnboardingCompletedSteps, 1)
        XCTAssertEqual(sut.pairOnboardingBannerSubtitle, "1/3 done · Next: Mark a free day")

        sut.markFreeDay()
        XCTAssertEqual(sut.pairOnboardingBannerTitle, "Waiting for them to accept")
        XCTAssertEqual(sut.pairOnboardingCompletedSteps, 2)
        XCTAssertEqual(sut.pairOnboardingBannerSubtitle, "2/3 done · Next: Wait for accept")
    }

    func test_markInvitedFriend_returnsTrueOnlyFirstTime() {
        XCTAssertTrue(sut.markInvitedFriend())
        XCTAssertFalse(sut.markInvitedFriend())
    }

    func test_markFreeDay_returnsTrueOnlyFirstTime() {
        XCTAssertTrue(sut.markFreeDay())
        XCTAssertFalse(sut.markFreeDay())
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

    func test_postConnectCoach_activatesAndDismisses() {
        XCTAssertFalse(sut.shouldShowPostConnectCoach)
        sut.activatePostConnectCoach()
        XCTAssertTrue(sut.shouldShowPostConnectCoach)

        sut.dismissPostConnectCoach()
        XCTAssertFalse(sut.shouldShowPostConnectCoach)
        sut.activatePostConnectCoach()
        XCTAssertFalse(sut.shouldShowPostConnectCoach)
    }

    func test_connectionToastHelpers_includeFriendName() {
        XCTAssertEqual(
            OnboardingProgressStore.firstConnectionToast(friendName: "Alice"),
            "Connected with Alice!"
        )
        XCTAssertEqual(
            OnboardingProgressStore.firstConnectionToast(friendName: nil),
            OnboardingProgressStore.firstConnectionToastMessage
        )
        XCTAssertEqual(
            OnboardingProgressStore.subsequentConnectionToast(friendName: "Bob"),
            "You're connected with Bob! See when they're free."
        )
        XCTAssertEqual(
            OnboardingProgressStore.postConnectNudgeMission(friendName: "Cara", weekday: "Sat"),
            "Nudge Cara for Sat."
        )
    }
}
