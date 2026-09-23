//
//  RootViewModel.swift
//  UFree
//
//  Created by Khang Vu on 31/12/25.
//

import Foundation
import Combine

@MainActor
public final class RootViewModel: ObservableObject {
    // MARK: - Auth State
    enum AuthPhase {
        case loading           // Firebase checking for existing session
        case unauthenticated   // No user found, show login
        case authenticated     // User logged in, show main app
    }
    
    @Published var authPhase: AuthPhase = .loading
    @Published var currentUser: User? = nil
    @Published var isSigningIn = false
    @Published var errorMessage: String? = nil
    
    // Navigation / Deep Links
    @Published var deepLinkProfileId: String? = nil
    
    // Navigation Tabs
    public enum Tab {
        case schedule
        case feed
        case friends
    }
    @Published public var activeTab: Tab = .schedule
    @Published public var showWeekendCTA = false
    /// Soft bottom banner on Who's Free (does not auto-present the sheet).
    @Published public var showPairOnboardingBanner = false
    /// Checklist bottom sheet — opened only when the user taps the banner.
    @Published public var showPairOnboardingSheet = false
    @Published public var celebrationToast: String?
    @Published public var hangoutPrompt: HangoutConfirmPrompt?
    /// Friend name for post-connect mission chip copy (first / latest accept).
    @Published public var postConnectFriendName: String?
    /// Optional day to focus on Who's Free when the mission chip is tapped.
    @Published public var missionFocusDate: Date?

    /// Duration before celebration toast clears (and optional weekend CTA presents).
    public var celebrationToastDurationNanoseconds: UInt64 = 2_500_000_000
    
    // Feature ViewModels for navigation and cross-feature state
    @Published public var friendsScheduleViewModel: FriendsScheduleViewModel?
    @Published public var friendsViewModel: FriendsViewModel?
    
    public let authRepository: AuthRepository
    /// `nonisolated(unsafe)` so `deinit` can cancel without hopping to the MainActor.
    /// A non-empty `@MainActor deinit` trips a Swift 6.2 / iOS 26.2 XCTest bug
    /// (`swift_task_deinitOnExecutorImpl` → "pointer being freed was not allocated").
    nonisolated(unsafe) private var authStateTask: Task<Void, Never>?
    nonisolated(unsafe) private var celebrationDismissTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    /// Bumped on every explicit sign-in / sign-out / delete so a lagged
    /// `authState` emission cannot overwrite a newer local assignment.
    private var authEpoch = 0
    
    public init(authRepository: AuthRepository) {
        self.authRepository = authRepository
        setupAuthStateListener()
        setupDeepLinkObserver()
    }

    // MARK: - Onboarding celebration

    /// Single post-accept entry for Notification Center and Add Friends.
    public func handlePostAccept(
        friendName: String,
        wasFirstFriend: Bool,
        store: OnboardingProgressStore = .shared
    ) {
        postConnectFriendName = friendName
        if wasFirstFriend {
            celebrateFirstConnection(friendName: friendName, store: store)
        } else {
            HapticManager.success()
            activeTab = .feed
            presentCelebrationToast(
                OnboardingProgressStore.subsequentConnectionToast(friendName: friendName)
            )
        }
    }

    /// Shared inviter + acceptor first-connection toast + haptic.
    /// Smart branch: weekend CTA path lands on Schedule; already-free lands on Who's Free + mission.
    @discardableResult
    public func celebrateFirstConnection(
        friendName: String? = nil,
        store: OnboardingProgressStore = .shared
    ) -> Bool {
        guard !store.hasCelebratedFirstAccept else { return false }
        store.markCelebratedFirstAccept()
        HapticManager.success()
        showPairOnboardingBanner = false
        showPairOnboardingSheet = false
        if let friendName, !friendName.isEmpty {
            postConnectFriendName = friendName
        }

        let offerWeekendCTA = store.shouldPresentWeekendCTAAfterConnection
        if offerWeekendCTA {
            // Need a free day before Who's Free is useful.
            activeTab = .schedule
        } else {
            activeTab = .feed
            store.activatePostConnectCoach()
        }

        let toast = OnboardingProgressStore.firstConnectionToast(friendName: friendName)
        presentCelebrationToast(toast) { [weak self] in
            guard let self else { return }
            if offerWeekendCTA && store.shouldPresentWeekendCTAAfterConnection {
                self.showWeekendCTA = true
            } else if store.pendingWeekendCTA && store.hasMarkedFreeDay {
                store.consumeWeekendCTA()
            }
        }
        return true
    }

    public func dismissPostConnectCoach(store: OnboardingProgressStore = .shared) {
        store.dismissPostConnectCoach()
        missionFocusDate = nil
    }

    public func postConnectMissionSubtitle(store: OnboardingProgressStore = .shared) -> String {
        if activeTab == .schedule && !store.hasMarkedFreeDay {
            return OnboardingProgressStore.postConnectMissionMarkFree
        }
        if let name = postConnectFriendName,
           let friendsVM = friendsScheduleViewModel,
           let friendId = friendsVM.friendId(named: name),
           let date = friendsVM.nextFreeDate(forFriendId: friendId) {
            let weekday = date.formatted(.dateTime.weekday(.abbreviated))
            return OnboardingProgressStore.postConnectNudgeMission(friendName: name, weekday: weekday)
        }
        if let name = postConnectFriendName, !name.isEmpty {
            return "See when you and \(name) are free — then nudge a day."
        }
        return OnboardingProgressStore.postConnectMissionSeeBothFree
    }

    public func handlePostConnectMissionTap(store: OnboardingProgressStore = .shared) {
        if activeTab == .schedule && !store.hasMarkedFreeDay {
            showWeekendCTA = true
            return
        }

        activeTab = .feed
        if let name = postConnectFriendName,
           let friendsVM = friendsScheduleViewModel,
           let friendId = friendsVM.friendId(named: name),
           let date = friendsVM.nextFreeDate(forFriendId: friendId) {
            friendsVM.focusDate(date)
            missionFocusDate = date
        }
    }

    /// Light haptic + brief toast for first-time invite / free-day steps (banner stays; no sheet).
    public func presentOnboardingStepFeedback(_ message: String) {
        HapticManager.light()
        presentCelebrationToast(message)
    }

    public func presentCelebrationToast(
        _ message: String,
        afterDismiss: (() -> Void)? = nil
    ) {
        celebrationDismissTask?.cancel()
        celebrationToast = message
        let nanoseconds = celebrationToastDurationNanoseconds
        celebrationDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            self?.celebrationToast = nil
            afterDismiss?()
        }
    }

    private func setupDeepLinkObserver() {
        NotificationCenter.default.publisher(for: .didReceiveProfileDeepLink)
            .compactMap { $0.object as? String }
            .sink { [weak self] userId in
                self?.deepLinkProfileId = userId
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .didReceiveLocalRoute)
            .compactMap { $0.object as? String }
            .sink { [weak self] route in
                if route == LocalNotificationScheduler.routeWhosFree {
                    self?.activeTab = .feed
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .didDeleteAccount)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.commitAuthUser(nil)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Auth State Setup
    
    private func setupAuthStateListener() {
        authStateTask = Task { [weak self] in
            guard let authRepository = self?.authRepository else { return }
            for await _ in authRepository.authState {
                guard let self else { return }
                // Re-read after the await so a buffered init-nil / sign-in
                // value cannot win over a sign-in or sign-out that committed
                // while this task was suspended.
                let epoch = self.authEpoch
                let latest = await authRepository.currentUser
                guard epoch == self.authEpoch else { continue }
                self.applyAuthUser(latest)
                self.isSigningIn = false
            }
        }
    }

    private func commitAuthUser(_ user: User?) {
        authEpoch += 1
        applyAuthUser(user)
    }

    private func applyAuthUser(_ user: User?) {
        currentUser = user
        authPhase = user != nil ? .authenticated : .unauthenticated
    }
    
    // MARK: - Actions
    
    @discardableResult
    public func signInAnonymously() -> Task<Void, Never> {
        return Task {
            isSigningIn = true
            errorMessage = nil
            
            do {
                let user = try await authRepository.signInAnonymously()
                self.commitAuthUser(user)
            } catch {
                self.errorMessage = error.localizedDescription
            }
            
            isSigningIn = false
        }
    }
    
    @discardableResult
    public func signOut() -> Task<Void, Never> {
        return Task {
            do {
                try await authRepository.signOut()
                // Clear immediately for UI. A lagged auth-state emission is
                // ignored once `authEpoch` moves.
                self.commitAuthUser(nil)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    nonisolated deinit {
        authStateTask?.cancel()
        celebrationDismissTask?.cancel()
    }
}

// MARK: - Helper for Sheet Identification
extension String: @retroactive Identifiable {
    public var id: String { self }
}

public struct HangoutConfirmPrompt: Identifiable, Equatable {
    public let friendId: String
    public let friendName: String
    public let dayKey: String

    public var id: String { "\(friendId)|\(dayKey)" }

    public init(friendId: String, friendName: String, dayKey: String) {
        self.friendId = friendId
        self.friendName = friendName
        self.dayKey = dayKey
    }
}
