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
    public var userIdsToFailFor: Set<String> = []  // Test hook: cause sendNudge to fail for these user IDs
    public var shouldThrowRateLimit = false
    public var simulatedDelay: UInt64 = 0 // Nanoseconds
    
    public init(notifications: [AppNotification] = []) {
        self.mockNotifications = notifications
    }
    
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
    
    public func sendNudge(to userId: String) async throws {
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
        
        let nudge = AppNotification(
            recipientId: userId,
            senderId: "current_user",
            senderName: "You",
            type: .nudge,
            date: Date(),
            isRead: false
        )
        mockNotifications.insert(nudge, at: 0)
    }
    
    public func updatePushToken(_ token: String) async throws {
        // No-op for mock
    }
}
