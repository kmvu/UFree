//
//  MockNotificationRepository.swift
//  UFree
//
//  Created by Khang Vu on 08/01/26.
//

import Foundation

@MainActor
public class MockNotificationRepository: NotificationRepository {
    public var mockNotifications: [AppNotification]
    public var sentNudges: [(userId: String, targetDate: Date?)] = []
    public var sentReplies: [(userId: String, targetDateString: String?, response: AppNotification.NudgeResponse)] = []
    public var userIdsToFailFor: Set<String> = []  // Test hook: cause sendNudge to fail for these user IDs
    public var shouldThrowRateLimit = false
    public var simulatedDelay: UInt64 = 0 // Nanoseconds
    /// Mirrors Auth.displayName. Empty / nil throws the same error as production.
    public var senderDisplayName: String? = "You"
    
    public init(notifications: [AppNotification] = []) {
        self.mockNotifications = notifications
    }

    /// Empty `nonisolated` deinit works around a Swift 6.2 / iOS 26.2 XCTest bug where
    /// MainActor-isolated class teardown aborts with "pointer being freed was not allocated".
    nonisolated deinit {}
    
    public func listenToNotifications() -> AsyncStream<[AppNotification]> {
        AsyncStream { continuation in
            continuation.yield(mockNotifications)
            continuation.finish()
        }
    }
    
    public func markAsRead(_ notification: AppNotification) async throws {
        if let index = mockNotifications.firstIndex(where: { $0.id == notification.id }) {
            mockNotifications[index].isRead = true
        }
    }

    public func markAsUnread(_ notification: AppNotification) async throws {
        if let index = mockNotifications.firstIndex(where: { $0.id == notification.id }) {
            mockNotifications[index].isRead = false
        }
    }

    public func deleteNotification(_ notification: AppNotification) async throws {
        mockNotifications.removeAll { $0.id == notification.id }
    }
    
    public func sendNudge(to userId: String, targetDate: Date?) async throws {
        _ = try NotificationSenderIdentity.requireDisplayName(senderDisplayName)
        if simulatedDelay > 0 {
            try? await Task.sleep(nanoseconds: simulatedDelay)
        }
        
        if shouldThrowRateLimit {
            throw NSError(domain: "FirebaseError", code: 429, userInfo: [NSLocalizedDescriptionKey: "Quota exceeded (429)"])
        }
        
        // Test hook: fail if user ID is in failure set
        if userIdsToFailFor.contains(userId) {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Simulated nudge failure"])
        }

        sentNudges.append((userId, targetDate))
        
        let nudge = AppNotification(
            recipientId: userId,
            senderId: "current_user",
            senderName: "You",
            type: .nudge,
            date: Date(),
            isRead: false,
            targetDateString: targetDate.map { AppNotification.dateString(from: $0) }
        )
        mockNotifications.insert(nudge, at: 0)
    }

    public func sendNudgeReply(
        to userId: String,
        targetDateString: String?,
        response: AppNotification.NudgeResponse
    ) async throws {
        _ = try NotificationSenderIdentity.requireDisplayName(senderDisplayName)
        sentReplies.append((userId, targetDateString, response))
        let reply = AppNotification(
            recipientId: userId,
            senderId: "current_user",
            senderName: "You",
            type: .nudgeReply,
            date: Date(),
            isRead: false,
            targetDateString: targetDateString,
            nudgeResponse: response.rawValue
        )
        mockNotifications.insert(reply, at: 0)
    }

    public func markNudgeResponded(
        _ notification: AppNotification,
        response: AppNotification.NudgeResponse
    ) async throws {
        if let index = mockNotifications.firstIndex(where: { $0.id == notification.id }) {
            mockNotifications[index].isRead = true
            mockNotifications[index].nudgeResponse = response.rawValue
        }
    }
    
    public func updatePushToken(_ token: String) async throws {
        // No-op for mock
    }
}
