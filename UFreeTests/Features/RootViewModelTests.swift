//
//  RootViewModelTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 31/12/25.
//

import XCTest
import Combine
@testable import UFree

@MainActor
final class RootViewModelTests: XCTestCase {
    
    private var authRepository: MockAuthRepository!
    private var viewModel: RootViewModel!
    
    override func setUp() async throws {
        try await super.setUp()
        authRepository = MockAuthRepository()
        viewModel = RootViewModel(authRepository: authRepository)
    }
    
    // MARK: - Initial State
    
    func test_init_currentUserIsNil() {
        XCTAssertNil(viewModel.currentUser)
    }
    
    func test_init_isSigningInIsFalse() {
        XCTAssertFalse(viewModel.isSigningIn)
    }
    
    // MARK: - Sign In
    
    func test_signInAnonymously_setsCurrentUser() async throws {
        await viewModel.signInAnonymously().value
        
        XCTAssertNotNil(viewModel.currentUser)
        XCTAssertTrue(viewModel.currentUser?.isAnonymous ?? false)
    }
    
    func test_signInAnonymously_setsIsSigningInDuringOperation() async {
        var wasSigningIn = false
        
        let observation = viewModel.$isSigningIn.sink { isSigningIn in
            if isSigningIn {
                wasSigningIn = true
            }
        }
        
        // Don't await the task here, we want to observe state during execution
        let task = viewModel.signInAnonymously()
        
        // Yield to allow the Task to start executing on the MainActor
        await Task.yield()
        
        // Wait for the synchronous publish to hit our sink before the task finishes
        XCTAssertTrue(wasSigningIn)
        observation.cancel()
        await task.value // Clean up
    }
    
    func test_signInAnonymously_clearsErrorMessageOnSuccess() async throws {
        viewModel.errorMessage = "Previous error"
        
        await viewModel.signInAnonymously().value
        
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Sign Out
    
    func test_signOut_clearsCurrentUser() async throws {
        await viewModel.signInAnonymously().value
        XCTAssertNotNil(viewModel.currentUser)

        await viewModel.signOut().value

        // Auth-state listener may still be draining a buffered sign-in emission;
        // wait until sign-out's nil (or the stream's nil) wins.
        await waitUntil("sign-out clears currentUser") {
            self.viewModel.currentUser == nil
        }
    }
    
    // MARK: - Auth State Stream
    
    func test_authStateListener_updatesCurrentUser() async throws {
        let user = try await authRepository.signInAnonymously()
        
        // Wait for the ViewModel's authState listener task to pick up the emission
        // Since we are mocking the stream, we can yield to the runloop to let the AsyncStream process
        await Task.yield()
        
        // Let's ensure we wait deterministically until the user matches
        let startDate = Date()
        while viewModel.currentUser?.id != user.id && Date().timeIntervalSince(startDate) < 1.0 {
            await Task.yield()
        }
        
        XCTAssertEqual(viewModel.currentUser?.id, user.id)
    }

    // MARK: - Deep Links

    func test_deepLinkNotification_setsProfileId() {
        let expectation = XCTestExpectation(description: "Wait for property update")
        
        let cancellable = viewModel.$deepLinkProfileId
            .dropFirst()
            .sink { profileId in
                if profileId == "test_user_id" {
                    expectation.fulfill()
                }
            }
        
        NotificationCenter.default.post(name: .didReceiveProfileDeepLink, object: "test_user_id")
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(viewModel.deepLinkProfileId, "test_user_id")
        cancellable.cancel()
    }

    // MARK: - Onboarding celebration

    func test_celebrateFirstConnection_setsToastAndIsIdempotent() {
        let suiteName = "RootViewModelCelebration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = OnboardingProgressStore(defaults: defaults)

        XCTAssertTrue(viewModel.celebrateFirstConnection(friendName: "Alice", store: store))
        XCTAssertEqual(
            viewModel.celebrationToast,
            OnboardingProgressStore.firstConnectionToast(friendName: "Alice")
        )
        XCTAssertTrue(store.hasCelebratedFirstAccept)
        // No weekend CTA queued → land on Who's Free with mission coach.
        XCTAssertEqual(viewModel.activeTab, .feed)
        XCTAssertTrue(store.shouldShowPostConnectCoach)
        XCTAssertFalse(viewModel.showWeekendCTA)

        XCTAssertFalse(viewModel.celebrateFirstConnection(store: store))
    }

    func test_celebrateFirstConnection_presentsWeekendCTAOnlyAfterToastDismiss() async {
        let suiteName = "RootViewModelWeekendCTA.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = OnboardingProgressStore(defaults: defaults)
        store.markFirstHandshake()
        viewModel.celebrationToastDurationNanoseconds = 50_000_000

        XCTAssertTrue(viewModel.celebrateFirstConnection(store: store))
        XCTAssertEqual(viewModel.activeTab, .schedule)
        XCTAssertFalse(viewModel.showWeekendCTA)

        try? await Task.sleep(nanoseconds: 120_000_000)
        XCTAssertNil(viewModel.celebrationToast)
        XCTAssertTrue(viewModel.showWeekendCTA)
    }

    func test_celebrateFirstConnection_skipsWeekendCTAWhenFreeDayMarked() async {
        let suiteName = "RootViewModelSkipWeekend.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = OnboardingProgressStore(defaults: defaults)
        store.markFreeDay()
        store.markFirstHandshake()
        viewModel.celebrationToastDurationNanoseconds = 50_000_000

        XCTAssertTrue(viewModel.celebrateFirstConnection(friendName: "Bob", store: store))
        XCTAssertEqual(viewModel.activeTab, .feed)
        XCTAssertTrue(store.shouldShowPostConnectCoach)
        try? await Task.sleep(nanoseconds: 120_000_000)
        XCTAssertFalse(viewModel.showWeekendCTA)
    }

    func test_handlePostAccept_subsequentFriend_goesToFeedWithNamedToast() {
        viewModel.handlePostAccept(friendName: "Cara", wasFirstFriend: false)

        XCTAssertEqual(viewModel.activeTab, .feed)
        XCTAssertEqual(
            viewModel.celebrationToast,
            OnboardingProgressStore.subsequentConnectionToast(friendName: "Cara")
        )
    }

    func test_handlePostAccept_firstFriend_celebrates() {
        let suiteName = "RootViewModelPostAcceptFirst.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = OnboardingProgressStore(defaults: defaults)
        store.markFreeDay()

        viewModel.handlePostAccept(friendName: "Dana", wasFirstFriend: true, store: store)

        XCTAssertTrue(store.hasCelebratedFirstAccept)
        XCTAssertEqual(viewModel.activeTab, .feed)
        XCTAssertEqual(
            viewModel.celebrationToast,
            OnboardingProgressStore.firstConnectionToast(friendName: "Dana")
        )
    }

    func test_dismissPostConnectCoach_clearsMission() {
        let suiteName = "RootViewModelDismissCoach.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = OnboardingProgressStore(defaults: defaults)
        store.activatePostConnectCoach()
        viewModel.missionFocusDate = Date()

        viewModel.dismissPostConnectCoach(store: store)

        XCTAssertFalse(store.shouldShowPostConnectCoach)
        XCTAssertNil(viewModel.missionFocusDate)
    }

    func test_presentOnboardingStepFeedback_setsToast() {
        viewModel.presentOnboardingStepFeedback(OnboardingProgressStore.inviteStepToastMessage)
        XCTAssertEqual(viewModel.celebrationToast, OnboardingProgressStore.inviteStepToastMessage)
    }
}
