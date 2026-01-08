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
    case friendRequestSent
    
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
            
        case .friendRequestSent:
            Analytics.logEvent("friend_request_sent", parameters: [
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
    
    /// Log "Batch Nudge" - Tests if heatmap feature is used
    static func logBatchNudge(recipientCount: Int) {
        Analytics.logEvent("batch_nudge_sent", parameters: [
            "recipient_count": recipientCount,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Log "Phone Search Success" - Tests if blind-index search works
    static func logPhoneSearchSuccess(friendName: String? = nil) {
        Analytics.logEvent("phone_search_success", parameters: [
            "timestamp": Date().timeIntervalSince1970
        ])
    }
}
