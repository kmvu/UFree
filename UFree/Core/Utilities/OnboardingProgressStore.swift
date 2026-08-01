//
//  OnboardingProgressStore.swift
//  UFree
//
//  Lightweight first-run / dyad onboarding progress (UserDefaults).
//

import Foundation
import Combine

@MainActor
public final class OnboardingProgressStore: ObservableObject {
    public static let shared = OnboardingProgressStore()

    private let defaults: UserDefaults

    private enum Key {
        static let hasInvitedFriend = "ufree.onboarding.hasInvitedFriend"
        static let hasMarkedFreeDay = "ufree.onboarding.hasMarkedFreeDay"
        static let hasCompletedFirstHandshake = "ufree.onboarding.hasCompletedFirstHandshake"
        static let hasShownWeekendCTA = "ufree.onboarding.hasShownWeekendCTA"
        static let hasCelebratedFirstAccept = "ufree.onboarding.hasCelebratedFirstAccept"
        static let firstLaunchAt = "ufree.onboarding.firstLaunchAt"
        static let firstFriendAt = "ufree.onboarding.firstFriendAt"
        static let firstFreeMarkAt = "ufree.onboarding.firstFreeMarkAt"
        static let lastWeekendActivityAt = "ufree.retention.lastWeekendActivityAt"
        static let pendingWeekendCTA = "ufree.onboarding.pendingWeekendCTA"
    }

    @Published public private(set) var hasInvitedFriend: Bool
    @Published public private(set) var hasMarkedFreeDay: Bool
    @Published public private(set) var hasCompletedFirstHandshake: Bool
    @Published public private(set) var hasShownWeekendCTA: Bool
    @Published public private(set) var hasCelebratedFirstAccept: Bool
    @Published public private(set) var pendingWeekendCTA: Bool

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Key.firstLaunchAt) == nil {
            defaults.set(Date().timeIntervalSince1970, forKey: Key.firstLaunchAt)
        }
        self.hasInvitedFriend = defaults.bool(forKey: Key.hasInvitedFriend)
        self.hasMarkedFreeDay = defaults.bool(forKey: Key.hasMarkedFreeDay)
        self.hasCompletedFirstHandshake = defaults.bool(forKey: Key.hasCompletedFirstHandshake)
        self.hasShownWeekendCTA = defaults.bool(forKey: Key.hasShownWeekendCTA)
        self.hasCelebratedFirstAccept = defaults.bool(forKey: Key.hasCelebratedFirstAccept)
        self.pendingWeekendCTA = defaults.bool(forKey: Key.pendingWeekendCTA)
    }

    public func markCelebratedFirstAccept() {
        hasCelebratedFirstAccept = true
        defaults.set(true, forKey: Key.hasCelebratedFirstAccept)
    }

    /// Prefer `shouldShowPairChecklist(friendCount:)` so returning users with friends
    /// (or cleared UserDefaults) are not shown a first-run overlay.
    public var shouldShowPairChecklist: Bool {
        shouldShowPairChecklist(friendCount: 0)
    }

    public func shouldShowPairChecklist(friendCount: Int) -> Bool {
        !hasCompletedFirstHandshake && friendCount == 0
    }

    /// Sync progress when friends already exist without firing weekend CTA.
    public func acknowledgeExistingFriends() {
        guard !hasCompletedFirstHandshake else { return }
        hasCompletedFirstHandshake = true
        defaults.set(true, forKey: Key.hasCompletedFirstHandshake)
    }

    public var firstLaunchAt: Date? {
        guard defaults.object(forKey: Key.firstLaunchAt) != nil else { return nil }
        return Date(timeIntervalSince1970: defaults.double(forKey: Key.firstLaunchAt))
    }

    public func markInvitedFriend() {
        hasInvitedFriend = true
        defaults.set(true, forKey: Key.hasInvitedFriend)
    }

    public func markFreeDay() {
        if !hasMarkedFreeDay {
            hasMarkedFreeDay = true
            defaults.set(true, forKey: Key.hasMarkedFreeDay)
            defaults.set(Date().timeIntervalSince1970, forKey: Key.firstFreeMarkAt)
            if let launch = firstLaunchAt {
                let seconds = Int(Date().timeIntervalSince(launch))
                AnalyticsManager.logTimeToFirstFreeMark(seconds: seconds)
            }
        }
        recordWeekendActivity()
    }

    public func markFirstHandshake() {
        if !hasCompletedFirstHandshake {
            hasCompletedFirstHandshake = true
            defaults.set(true, forKey: Key.hasCompletedFirstHandshake)
            defaults.set(Date().timeIntervalSince1970, forKey: Key.firstFriendAt)
            if let launch = firstLaunchAt {
                let seconds = Int(Date().timeIntervalSince(launch))
                AnalyticsManager.logTimeToFirstFriend(seconds: seconds)
            }
        }
        if !hasShownWeekendCTA {
            pendingWeekendCTA = true
            defaults.set(true, forKey: Key.pendingWeekendCTA)
        }
        recordWeekendActivity()
    }

    public func consumeWeekendCTA() {
        pendingWeekendCTA = false
        hasShownWeekendCTA = true
        defaults.set(false, forKey: Key.pendingWeekendCTA)
        defaults.set(true, forKey: Key.hasShownWeekendCTA)
    }

    public func recordWeekendActivity() {
        defaults.set(Date().timeIntervalSince1970, forKey: Key.lastWeekendActivityAt)
    }

    public var lastWeekendActivityAt: Date? {
        guard defaults.object(forKey: Key.lastWeekendActivityAt) != nil else { return nil }
        return Date(timeIntervalSince1970: defaults.double(forKey: Key.lastWeekendActivityAt))
    }

    /// Call on app launch to emit Friday/D7 reopen if prior weekend activity exists.
    public func trackReopenIfNeeded() {
        guard let last = lastWeekendActivityAt else { return }
        let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        if days >= 5 {
            AnalyticsManager.logD7Reopen(daysSinceActivity: days)
        }
    }
}
