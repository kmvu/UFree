//
//  MockNotificationRepository.swift
//  UFree
//
//  Created by Khang Vu on 08/01/26.
//

import Foundation

public class MockNotificationRepository: NotificationRepository {
    public var mockNotifications: [AppNotification]
    
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
}
