//
//  AnalyticsManager.swift
//  UFree
//
//  Created by Khang Vu on 8/1/26.
//
//  Firebase Analytics wrapper for clean event tracking.
//  Keeps ViewModels decoupled from Firebase SDK.

import FirebaseAnalytics

// MARK: - Analytics Events
enum AnalyticsEvent {
    /// User sent a nudge (single or batch)
    case nudgeSent(type: String) // "single" or "batch"
    
    /// User sent a friend request
    case friendRequestSent(source: String) // e.g., "contact_sync", "qr_code", "deep_link", "manual"
    
    /// User performed a phone-based search for friends
    case searchPerformed(success: Bool)
    
    /// User changed their availability status
    case availabilityUpdated(status: String) // "free", "busy", "offline"
    
    /// User viewed the heatmap
    case heatmapViewed(friendCount: Int)
    
    /// User completed the handshake process
    case handshakeCompleted(duration: Int) // seconds
    
    /// User opened the app
    case appLaunched

    /// User opened a universal link or deep link (route type only — no UID/URL).
    case linkOpened(route: String)

    /// Seconds from first launch to first mutual friend
    case timeToFirstFriend(seconds: Int)

    /// Seconds from first launch to first free-day mark
    case timeToFirstFreeMark(seconds: Int)

    /// User sent a nudge reply
    case nudgeReplySent(response: String)

    /// User received a nudge reply (opened inbox)
    case nudgeReplyReceived(response: String)

    /// App reopen after prior weekend activity (D7 / Friday habit)
    case d7Reopen(daysSinceActivity: Int)

    /// Pair-onboarding checklist sheet became visible
    case onboardingChecklistShown

    /// First-time pair-onboarding step completed (`invite` / `free_day` / `handshake`)
    case onboardingStepCompleted(step: String)

    /// User permanently dismissed the pair-onboarding checklist
    case onboardingChecklistDismissed

    /// Post-connect mission chip tapped
    case missionChipTapped

    /// Weekend Sat/Sun CTA accepted
    case weekendCTAAccepted

    /// Weekend Sat/Sun CTA dismissed
    case weekendCTADismissed

    /// User opened a scheduled local notification (`weekend_planning`)
    case localNotificationOpened(kind: String)

    /// User confirmed a hangout happened
    case hangoutConfirmed

    /// User dismissed the hangout-confirm prompt without confirming
    case hangoutConfirmDismissed

    /// Per-friend hang milestone (1 / 5 / 10)
    case bondMilestoneReached(count: Int)
}

// MARK: - Analytics Manager
struct AnalyticsManager {
    /// Log an analytics event to Firebase
    /// - Parameter event: The event to track
    static func log(_ event: AnalyticsEvent) {
        switch event {
        case .nudgeSent(let type):
            Analytics.logEvent("nudge_performed", parameters: [
                "nudge_type": type,
                "timestamp": Date().timeIntervalSince1970
            ])
            
        case .friendRequestSent(let source):
            Analytics.logEvent("friend_request_sent", parameters: [
                "source": source,
                "timestamp": Date().timeIntervalSince1970
            ])
            
        case .searchPerformed(let success):
            Analytics.logEvent("phone_search", parameters: [
                "found_match": success ? 1 : 0,
                "timestamp": Date().timeIntervalSince1970
            ])
            
        case .availabilityUpdated(let status):
            Analytics.logEvent("status_change", parameters: [
                "new_status": status,
                "timestamp": Date().timeIntervalSince1970
            ])
            
        case .heatmapViewed(let friendCount):
            Analytics.logEvent("heatmap_viewed", parameters: [
                "friend_count": friendCount,
                "timestamp": Date().timeIntervalSince1970
            ])
            
        case .handshakeCompleted(let duration):
            Analytics.logEvent("handshake_completed", parameters: [
                "duration_seconds": duration,
                "timestamp": Date().timeIntervalSince1970
            ])
            
        case .appLaunched:
            Analytics.logEvent("app_launched", parameters: [
                "timestamp": Date().timeIntervalSince1970
            ])

        case .linkOpened(let route):
            Analytics.logEvent("link_opened", parameters: [
                "route": route,
                "timestamp": Date().timeIntervalSince1970
            ])

        case .timeToFirstFriend(let seconds):
            Analytics.logEvent("time_to_first_friend", parameters: [
                "seconds": seconds,
                "timestamp": Date().timeIntervalSince1970
            ])

        case .timeToFirstFreeMark(let seconds):
            Analytics.logEvent("time_to_first_free_mark", parameters: [
                "seconds": seconds,
                "timestamp": Date().timeIntervalSince1970
            ])

        case .nudgeReplySent(let response):
            Analytics.logEvent("nudge_reply_sent", parameters: [
                "response": response,
                "timestamp": Date().timeIntervalSince1970
            ])

        case .nudgeReplyReceived(let response):
            Analytics.logEvent("nudge_reply_received", parameters: [
                "response": response,
                "timestamp": Date().timeIntervalSince1970
            ])

        case .d7Reopen(let days):
            Analytics.logEvent("d7_reopen", parameters: [
                "days_since_activity": days,
                "timestamp": Date().timeIntervalSince1970
            ])

        case .onboardingChecklistShown:
            Analytics.logEvent("onboarding_checklist_shown", parameters: [
                "timestamp": Date().timeIntervalSince1970
            ])

        case .onboardingStepCompleted(let step):
            Analytics.logEvent("onboarding_step_completed", parameters: [
                "step": step,
                "timestamp": Date().timeIntervalSince1970
            ])

        case .onboardingChecklistDismissed:
            Analytics.logEvent("onboarding_checklist_dismissed", parameters: [
                "timestamp": Date().timeIntervalSince1970
            ])

        case .missionChipTapped:
            Analytics.logEvent("mission_chip_tapped", parameters: [
                "timestamp": Date().timeIntervalSince1970
            ])

        case .weekendCTAAccepted:
            Analytics.logEvent("weekend_cta_accepted", parameters: [
                "timestamp": Date().timeIntervalSince1970
            ])

        case .weekendCTADismissed:
            Analytics.logEvent("weekend_cta_dismissed", parameters: [
                "timestamp": Date().timeIntervalSince1970
            ])

        case .localNotificationOpened(let kind):
            Analytics.logEvent("local_notification_opened", parameters: [
                "kind": kind,
                "timestamp": Date().timeIntervalSince1970
            ])

        case .hangoutConfirmed:
            Analytics.logEvent("hangout_confirmed", parameters: [
                "timestamp": Date().timeIntervalSince1970
            ])

        case .hangoutConfirmDismissed:
            Analytics.logEvent("hangout_confirm_dismissed", parameters: [
                "timestamp": Date().timeIntervalSince1970
            ])

        case .bondMilestoneReached(let count):
            Analytics.logEvent("bond_milestone_reached", parameters: [
                "count": count,
                "timestamp": Date().timeIntervalSince1970
            ])
        }
    }
    
    /// Enable/disable analytics collection (for debug mode)
    /// - Parameter enabled: If true, Firebase Analytics collects events
    static func setCollectionEnabled(_ enabled: Bool) {
        Analytics.setAnalyticsCollectionEnabled(enabled)
    }
}

// MARK: - Success Actions (Key Metrics for Testing Phase)
extension AnalyticsManager {
    /// Log "Nudge Sent" - Core success metric
    static func logNudgeSent(isBatch: Bool) {
        AnalyticsManager.log(.nudgeSent(type: isBatch ? "batch" : "single"))
    }

    /// Log "Friend Request Sent" - Tracks social growth sources
    static func logFriendRequestSent(source: String) {
        AnalyticsManager.log(.friendRequestSent(source: source))
    }
    
    /// Log "Batch Nudge" - Tests if heatmap feature is used
    static func logBatchNudge(recipientCount: Int) {
        Analytics.logEvent("batch_nudge_sent", parameters: [
            "recipient_count": recipientCount,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Log \"Phone Search Success\" - Tests if blind-index search works
    static func logPhoneSearchSuccess(friendName: String? = nil) {
        Analytics.logEvent("phone_search_success", parameters: [
            "timestamp": Date().timeIntervalSince1970
        ])
    }

    /// Log "Link Opened" — route type only (never full URL / UID).
    static func logLinkOpened(route: String) {
        AnalyticsManager.log(.linkOpened(route: route))
    }

    static func logTimeToFirstFriend(seconds: Int) {
        AnalyticsManager.log(.timeToFirstFriend(seconds: seconds))
    }

    static func logTimeToFirstFreeMark(seconds: Int) {
        AnalyticsManager.log(.timeToFirstFreeMark(seconds: seconds))
    }

    static func logNudgeReplySent(response: String) {
        AnalyticsManager.log(.nudgeReplySent(response: response))
    }

    static func logNudgeReplyReceived(response: String) {
        AnalyticsManager.log(.nudgeReplyReceived(response: response))
    }

    static func logD7Reopen(daysSinceActivity: Int) {
        AnalyticsManager.log(.d7Reopen(daysSinceActivity: daysSinceActivity))
    }

    static func logOnboardingChecklistShown() {
        AnalyticsManager.log(.onboardingChecklistShown)
    }

    static func logOnboardingStepCompleted(step: String) {
        AnalyticsManager.log(.onboardingStepCompleted(step: step))
    }

    static func logOnboardingChecklistDismissed() {
        AnalyticsManager.log(.onboardingChecklistDismissed)
    }

    static func logMissionChipTapped() {
        AnalyticsManager.log(.missionChipTapped)
    }

    static func logWeekendCTAAccepted() {
        AnalyticsManager.log(.weekendCTAAccepted)
    }

    static func logWeekendCTADismissed() {
        AnalyticsManager.log(.weekendCTADismissed)
    }

    static func logLocalNotificationOpened(kind: String) {
        AnalyticsManager.log(.localNotificationOpened(kind: kind))
    }

    static func logHangoutConfirmed() {
        AnalyticsManager.log(.hangoutConfirmed)
    }

    static func logHangoutConfirmDismissed() {
        AnalyticsManager.log(.hangoutConfirmDismissed)
    }

    static func logBondMilestoneReached(count: Int) {
        AnalyticsManager.log(.bondMilestoneReached(count: count))
    }
}
