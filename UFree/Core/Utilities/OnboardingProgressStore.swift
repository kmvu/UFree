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
    /// Firebase Auth UID — scopes keys so account switch / sign-out cannot leak progress.
    private var userId: String?

    private enum KeyBase {
        static let hasInvitedFriend = "ufree.onboarding.hasInvitedFriend"
        static let hasMarkedFreeDay = "ufree.onboarding.hasMarkedFreeDay"
        static let hasCompletedFirstHandshake = "ufree.onboarding.hasCompletedFirstHandshake"
        static let hasDismissedPairChecklist = "ufree.onboarding.hasDismissedPairChecklist"
        static let hasShownWeekendCTA = "ufree.onboarding.hasShownWeekendCTA"
        static let hasCelebratedFirstAccept = "ufree.onboarding.hasCelebratedFirstAccept"
        static let firstLaunchAt = "ufree.onboarding.firstLaunchAt"
        static let firstFriendAt = "ufree.onboarding.firstFriendAt"
        static let firstFreeMarkAt = "ufree.onboarding.firstFreeMarkAt"
        static let lastWeekendActivityAt = "ufree.retention.lastWeekendActivityAt"
        static let pendingWeekendCTA = "ufree.onboarding.pendingWeekendCTA"
        static let pendingPostConnectCoach = "ufree.onboarding.pendingPostConnectCoach"
        static let hasDismissedPostConnectCoach = "ufree.onboarding.hasDismissedPostConnectCoach"
        static let didMigrateLegacy = "ufree.onboarding.didMigrateLegacy"
    }

    private static let allBases: [String] = [
        KeyBase.hasInvitedFriend,
        KeyBase.hasMarkedFreeDay,
        KeyBase.hasCompletedFirstHandshake,
        KeyBase.hasDismissedPairChecklist,
        KeyBase.hasShownWeekendCTA,
        KeyBase.hasCelebratedFirstAccept,
        KeyBase.firstLaunchAt,
        KeyBase.firstFriendAt,
        KeyBase.firstFreeMarkAt,
        KeyBase.lastWeekendActivityAt,
        KeyBase.pendingWeekendCTA,
        KeyBase.pendingPostConnectCoach,
        KeyBase.hasDismissedPostConnectCoach
    ]

    @Published public private(set) var hasInvitedFriend: Bool
    @Published public private(set) var hasMarkedFreeDay: Bool
    @Published public private(set) var hasCompletedFirstHandshake: Bool
    @Published public private(set) var hasDismissedPairChecklist: Bool
    @Published public private(set) var hasShownWeekendCTA: Bool
    @Published public private(set) var hasCelebratedFirstAccept: Bool
    @Published public private(set) var pendingWeekendCTA: Bool
    @Published public private(set) var pendingPostConnectCoach: Bool
    @Published public private(set) var hasDismissedPostConnectCoach: Bool

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasInvitedFriend = false
        self.hasMarkedFreeDay = false
        self.hasCompletedFirstHandshake = false
        self.hasDismissedPairChecklist = false
        self.hasShownWeekendCTA = false
        self.hasCelebratedFirstAccept = false
        self.pendingWeekendCTA = false
        self.pendingPostConnectCoach = false
        self.hasDismissedPostConnectCoach = false
        ensureFirstLaunchStamp()
        reloadPublishedState()
    }

    /// Bind progress to a Firebase UID (or clear on sign-out).
    public func bind(userId: String?) {
        self.userId = userId
        if let userId, !userId.isEmpty {
            migrateLegacyKeysIfNeeded(for: userId)
            ensureFirstLaunchStamp()
        }
        reloadPublishedState()
    }

    public func markCelebratedFirstAccept() {
        hasCelebratedFirstAccept = true
        defaults.set(true, forKey: scoped(KeyBase.hasCelebratedFirstAccept))
    }

    /// Soft bottom banner: incomplete first hangout, not permanently dismissed, no friends yet.
    public func shouldShowPairOnboardingBanner(friendCount: Int) -> Bool {
        !hasDismissedPairChecklist && !hasCompletedFirstHandshake && friendCount == 0
    }

    /// Prefer `shouldShowPairOnboardingBanner(friendCount:)` for UI.
    public var shouldShowPairChecklist: Bool {
        shouldShowPairOnboardingBanner(friendCount: 0)
    }

    public func shouldShowPairChecklist(friendCount: Int) -> Bool {
        shouldShowPairOnboardingBanner(friendCount: friendCount)
    }

    /// Permanently hide banner + checklist sheet (“Don’t show again”).
    public func dismissPairChecklistPermanently() {
        hasDismissedPairChecklist = true
        defaults.set(true, forKey: scoped(KeyBase.hasDismissedPairChecklist))
    }

    public var pairOnboardingCompletedSteps: Int {
        [hasInvitedFriend, hasMarkedFreeDay, hasCompletedFirstHandshake].filter(\.self).count
    }

    /// Primary banner line — next incomplete step.
    public var pairOnboardingBannerTitle: String {
        if !hasInvitedFriend { return "Invite 1 friend to start" }
        if !hasMarkedFreeDay { return "Mark when you're free" }
        return "Waiting for them to accept"
    }

    /// Quest-style progress under the banner title.
    public var pairOnboardingBannerSubtitle: String {
        let nextHint: String
        if !hasInvitedFriend {
            nextHint = "Next: Invite a friend"
        } else if !hasMarkedFreeDay {
            nextHint = "Next: Mark a free day"
        } else {
            nextHint = "Next: Wait for accept"
        }
        return "\(pairOnboardingCompletedSteps)/3 done · \(nextHint)"
    }

    public static let inviteStepToastMessage = "1/3 — Invite sent"
    public static let freeDayStepToastMessage = "2/3 — Weekend marked"
    public static let firstConnectionToastMessage = "You're connected — find a free night!"
    public static let postConnectMissionTitle = "Next mission"
    public static let postConnectMissionSeeBothFree = "See when you're both free — then nudge a day."
    public static let postConnectMissionMarkFree = "Mark a free day, then open Who's Free."

    public static func firstConnectionToast(friendName: String?) -> String {
        guard let friendName, !friendName.isEmpty else {
            return firstConnectionToastMessage
        }
        return "Connected with \(friendName)!"
    }

    public static func subsequentConnectionToast(friendName: String) -> String {
        "You're connected with \(friendName)! See when they're free."
    }

    public static func postConnectNudgeMission(friendName: String, weekday: String) -> String {
        "Nudge \(friendName) for \(weekday)."
    }

    /// Soft post-connect coach on Who's Free / Schedule after first connection.
    public var shouldShowPostConnectCoach: Bool {
        pendingPostConnectCoach && !hasDismissedPostConnectCoach
    }

    public func activatePostConnectCoach() {
        guard !hasDismissedPostConnectCoach else { return }
        pendingPostConnectCoach = true
        defaults.set(true, forKey: scoped(KeyBase.pendingPostConnectCoach))
    }

    public func dismissPostConnectCoach() {
        pendingPostConnectCoach = false
        hasDismissedPostConnectCoach = true
        defaults.set(false, forKey: scoped(KeyBase.pendingPostConnectCoach))
        defaults.set(true, forKey: scoped(KeyBase.hasDismissedPostConnectCoach))
    }

    /// Live 0→1 while this install has not celebrated yet.
    /// Does not require `hasCompletedFirstHandshake` — silent `acknowledgeExistingFriends`
    /// must not block the inviter’s live accept celebration.
    public func shouldCelebrateFirstConnection(previousFriendCount: Int, newFriendCount: Int) -> Bool {
        previousFriendCount == 0
            && newFriendCount >= 1
            && !hasCelebratedFirstAccept
    }

    /// Weekend sheet after connection toast — skip if free day already marked.
    public var shouldPresentWeekendCTAAfterConnection: Bool {
        pendingWeekendCTA && !hasMarkedFreeDay && !hasShownWeekendCTA
    }

    /// Sync progress when friends already exist without firing weekend CTA.
    public func acknowledgeExistingFriends() {
        guard !hasCompletedFirstHandshake else { return }
        hasCompletedFirstHandshake = true
        defaults.set(true, forKey: scoped(KeyBase.hasCompletedFirstHandshake))
    }

    public var firstLaunchAt: Date? {
        let key = scoped(KeyBase.firstLaunchAt)
        guard defaults.object(forKey: key) != nil else { return nil }
        return Date(timeIntervalSince1970: defaults.double(forKey: key))
    }

    /// - Returns: `true` the first time invite progress is recorded.
    @discardableResult
    public func markInvitedFriend() -> Bool {
        guard !hasInvitedFriend else { return false }
        hasInvitedFriend = true
        defaults.set(true, forKey: scoped(KeyBase.hasInvitedFriend))
        return true
    }

    /// - Returns: `true` the first time a free day is recorded.
    @discardableResult
    public func markFreeDay() -> Bool {
        let isFirst = !hasMarkedFreeDay
        if isFirst {
            hasMarkedFreeDay = true
            defaults.set(true, forKey: scoped(KeyBase.hasMarkedFreeDay))
            defaults.set(Date().timeIntervalSince1970, forKey: scoped(KeyBase.firstFreeMarkAt))
            if let launch = firstLaunchAt {
                let seconds = Int(Date().timeIntervalSince(launch))
                AnalyticsManager.logTimeToFirstFreeMark(seconds: seconds)
            }
        }
        recordWeekendActivity()
        return isFirst
    }

    public func markFirstHandshake() {
        if !hasCompletedFirstHandshake {
            hasCompletedFirstHandshake = true
            defaults.set(true, forKey: scoped(KeyBase.hasCompletedFirstHandshake))
            defaults.set(Date().timeIntervalSince1970, forKey: scoped(KeyBase.firstFriendAt))
            if let launch = firstLaunchAt {
                let seconds = Int(Date().timeIntervalSince(launch))
                AnalyticsManager.logTimeToFirstFriend(seconds: seconds)
            }
        }
        // Only queue weekend CTA when a free day is still needed.
        if !hasShownWeekendCTA && !hasMarkedFreeDay {
            pendingWeekendCTA = true
            defaults.set(true, forKey: scoped(KeyBase.pendingWeekendCTA))
        }
        recordWeekendActivity()
    }

    public func consumeWeekendCTA() {
        pendingWeekendCTA = false
        hasShownWeekendCTA = true
        defaults.set(false, forKey: scoped(KeyBase.pendingWeekendCTA))
        defaults.set(true, forKey: scoped(KeyBase.hasShownWeekendCTA))
    }

    public func recordWeekendActivity() {
        defaults.set(Date().timeIntervalSince1970, forKey: scoped(KeyBase.lastWeekendActivityAt))
    }

    public var lastWeekendActivityAt: Date? {
        let key = scoped(KeyBase.lastWeekendActivityAt)
        guard defaults.object(forKey: key) != nil else { return nil }
        return Date(timeIntervalSince1970: defaults.double(forKey: key))
    }

    /// Call on app launch to emit Friday/D7 reopen if prior weekend activity exists.
    public func trackReopenIfNeeded() {
        guard let last = lastWeekendActivityAt else { return }
        let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        if days >= 5 {
            AnalyticsManager.logD7Reopen(daysSinceActivity: days)
        }
    }

    /// Clears onboarding / retention prefs for the currently bound user after account deletion.
    public func resetAllProgress() {
        for base in Self.allBases {
            defaults.removeObject(forKey: scoped(base))
        }
        defaults.set(Date().timeIntervalSince1970, forKey: scoped(KeyBase.firstLaunchAt))
        reloadPublishedState()
    }

    // MARK: - Private

    private func scoped(_ base: String) -> String {
        guard let userId, !userId.isEmpty else { return base }
        return "\(base).\(userId)"
    }

    private func ensureFirstLaunchStamp() {
        let key = scoped(KeyBase.firstLaunchAt)
        if defaults.object(forKey: key) == nil {
            defaults.set(Date().timeIntervalSince1970, forKey: key)
        }
    }

    private func reloadPublishedState() {
        hasInvitedFriend = defaults.bool(forKey: scoped(KeyBase.hasInvitedFriend))
        hasMarkedFreeDay = defaults.bool(forKey: scoped(KeyBase.hasMarkedFreeDay))
        hasCompletedFirstHandshake = defaults.bool(forKey: scoped(KeyBase.hasCompletedFirstHandshake))
        hasDismissedPairChecklist = defaults.bool(forKey: scoped(KeyBase.hasDismissedPairChecklist))
        hasShownWeekendCTA = defaults.bool(forKey: scoped(KeyBase.hasShownWeekendCTA))
        hasCelebratedFirstAccept = defaults.bool(forKey: scoped(KeyBase.hasCelebratedFirstAccept))
        pendingWeekendCTA = defaults.bool(forKey: scoped(KeyBase.pendingWeekendCTA))
        pendingPostConnectCoach = defaults.bool(forKey: scoped(KeyBase.pendingPostConnectCoach))
        hasDismissedPostConnectCoach = defaults.bool(forKey: scoped(KeyBase.hasDismissedPostConnectCoach))
    }

    /// One-time copy of pre-UID keys into the first bound user's namespace.
    private func migrateLegacyKeysIfNeeded(for userId: String) {
        let flag = "\(KeyBase.didMigrateLegacy).\(userId)"
        guard defaults.object(forKey: flag) == nil else { return }

        let scopedMarked = "\(KeyBase.hasMarkedFreeDay).\(userId)"
        let alreadyScoped = defaults.object(forKey: scopedMarked) != nil
            || defaults.object(forKey: "\(KeyBase.hasInvitedFriend).\(userId)") != nil
            || defaults.object(forKey: "\(KeyBase.hasCompletedFirstHandshake).\(userId)") != nil

        if !alreadyScoped {
            for base in Self.allBases {
                if let value = defaults.object(forKey: base) {
                    defaults.set(value, forKey: "\(base).\(userId)")
                }
            }
        }
        defaults.set(true, forKey: flag)
    }
}
