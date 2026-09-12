//
//  LocalNotificationScheduler.swift
//  UFree
//
//  On-device weekend planning reminders. No APNs / FCM.
//

import Foundation
import UserNotifications

@MainActor
public final class LocalNotificationScheduler {
    public static let shared = LocalNotificationScheduler()

    public static let thursdayIdentifier = "ufree.weekend.planning.thursday"
    public static let fridayIdentifier = "ufree.weekend.planning.friday"
    public static let routeWhosFree = "whosFree"
    public static let kindWeekendPlanning = "weekend_planning"
    public static let staleActivityInterval: TimeInterval = 3 * 24 * 60 * 60

    public private(set) var lastFriendCount: Int = 0

    public init() {}

    public static func shouldSchedule(
        lastWeekendActivityAt: Date?,
        friendCount: Int,
        remindersEnabled: Bool,
        now: Date = Date(),
        allowInTests: Bool = false
    ) -> Bool {
        guard remindersEnabled else { return false }
        guard friendCount > 0 else { return false }
        guard allowInTests || !TestConfiguration.isTesting else { return false }
        if let last = lastWeekendActivityAt,
           now.timeIntervalSince(last) < staleActivityInterval {
            return false
        }
        return true
    }

    public func refresh(
        friendCount: Int,
        store: OnboardingProgressStore = .shared,
        now: Date = Date(),
        center: UNUserNotificationCenter = .current()
    ) {
        lastFriendCount = friendCount
        let should = Self.shouldSchedule(
            lastWeekendActivityAt: store.lastWeekendActivityAt,
            friendCount: friendCount,
            remindersEnabled: store.weekendRemindersEnabled,
            now: now
        )
        if should {
            scheduleWeekendReminders(center: center)
        } else {
            cancelAll(center: center)
        }
    }

    public func refreshUsingLastFriendCount(
        store: OnboardingProgressStore = .shared,
        center: UNUserNotificationCenter = .current()
    ) {
        refresh(friendCount: lastFriendCount, store: store, center: center)
    }

    public func cancelAll(center: UNUserNotificationCenter = .current()) {
        center.removePendingNotificationRequests(withIdentifiers: [
            Self.thursdayIdentifier,
            Self.fridayIdentifier
        ])
    }

    private func scheduleWeekendReminders(center: UNUserNotificationCenter) {
        let thursday = dateComponents(weekday: 5, hour: 18, minute: 0)
        let friday = dateComponents(weekday: 6, hour: 10, minute: 0)
        addRepeating(
            identifier: Self.thursdayIdentifier,
            dateComponents: thursday,
            center: center
        )
        addRepeating(
            identifier: Self.fridayIdentifier,
            dateComponents: friday,
            center: center
        )
    }

    private func addRepeating(
        identifier: String,
        dateComponents: DateComponents,
        center: UNUserNotificationCenter
    ) {
        let content = UNMutableNotificationContent()
        content.title = "UFree"
        content.body = "Weekend’s coming — who’s free?"
        content.sound = .default
        content.userInfo = [
            "route": Self.routeWhosFree,
            "kind": Self.kindWeekendPlanning
        ]

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    /// Calendar weekday: 1 = Sunday … 5 = Thursday, 6 = Friday.
    private func dateComponents(weekday: Int, hour: Int, minute: Int) -> DateComponents {
        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = minute
        return components
    }
}

enum LocalEngagementReset {
    @MainActor
    static func resetAll() {
        OnboardingProgressStore.shared.resetAllProgress()
        BondProgressStore.shared.resetAll()
        NudgeReplyStore.shared.resetAll()
        LocalNotificationScheduler.shared.cancelAll()
    }
}
