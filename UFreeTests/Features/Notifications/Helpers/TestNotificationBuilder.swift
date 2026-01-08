//
//  TestNotificationBuilder.swift
//  UFreeTests
//
//  Created by Khang Vu on 08/01/26.
//

import Foundation
@testable import UFree

/// Factory for creating test notifications with sensible defaults
struct TestNotificationBuilder {
    var recipientId: String = "test_recipient"
    var senderId: String = "test_sender"
    var senderName: String = "Test Sender"
    var type: AppNotification.NotificationType = .friendRequest
    var date: Date = Date()
    var isRead: Bool = false
    
    func build() -> AppNotification {
        AppNotification(
            recipientId: recipientId,
            senderId: senderId,
            senderName: senderName,
            type: type,
            date: date,
            isRead: isRead
        )
    }
    
    // Convenience builders
    static func friendRequest(
        senderName: String = "Alice",
        isRead: Bool = false,
        date: Date = Date()
    ) -> AppNotification {
        TestNotificationBuilder(
            senderName: senderName,
            type: .friendRequest,
            date: date,
            isRead: isRead
        ).build()
    }
    
    static func nudge(
        senderName: String = "Bob",
        isRead: Bool = false,
        date: Date = Date()
    ) -> AppNotification {
        TestNotificationBuilder(
            senderName: senderName,
            type: .nudge,
            date: date,
            isRead: isRead
        ).build()
    }
}
