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
    @Published public var activeTab: Tab = .feed
    @Published public var showWeekendCTA = false
    /// Soft bottom banner on Who's Free (does not auto-present the sheet).
    @Published public var showPairOnboardingBanner = false
    /// Checklist bottom sheet — opened only when the user taps the banner.
    @Published public var showPairOnboardingSheet = false
    @Published public var celebrationToast: String?

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
    
    public init(authRepository: AuthRepository) {
        self.authRepository = authRepository
        setupAuthStateListener()
        setupDeepLinkObserver()
    }

    // MARK: - Onboarding celebration

    /// Shared inviter + acceptor first-connection toast + haptic.
    /// Weekend CTA (if any) is presented only after the toast dismisses.
    @discardableResult
    public func celebrateFirstConnection(
        store: OnboardingProgressStore = .shared
    ) -> Bool {
        guard !store.hasCelebratedFirstAccept else { return false }
        store.markCelebratedFirstAccept()
        HapticManager.success()
        showPairOnboardingBanner = false
        showPairOnboardingSheet = false
        // Land on Schedule so both people can mark free days next.
        activeTab = .schedule

        let offerWeekendCTA = store.shouldPresentWeekendCTAAfterConnection
        presentCelebrationToast(OnboardingProgressStore.firstConnectionToastMessage) { [weak self] in
            guard let self else { return }
            if offerWeekendCTA && store.shouldPresentWeekendCTAAfterConnection {
                self.showWeekendCTA = true
            } else if store.pendingWeekendCTA && store.hasMarkedFreeDay {
                store.consumeWeekendCTA()
            }
        }
        return true
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
    }
    
    // MARK: - Auth State Setup
    
    private func setupAuthStateListener() {
        authStateTask = Task {
            for await user in authRepository.authState {
                self.currentUser = user
                self.isSigningIn = false
                
                // Update authPhase based on whether user exists
                if user != nil {
                    self.authPhase = .authenticated
                } else {
                    self.authPhase = .unauthenticated
                }
            }
        }
    }
    
    // MARK: - Actions
    
    @discardableResult
    public func signInAnonymously() -> Task<Void, Never> {
        return Task {
            isSigningIn = true
            errorMessage = nil
            
            do {
                let user = try await authRepository.signInAnonymously()
                self.currentUser = user
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
                self.currentUser = nil
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
