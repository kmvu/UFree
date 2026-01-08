//
//  NotificationCenterViewTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 08/01/26.
//

import XCTest
import SwiftUI
@testable import UFree

final class NotificationCenterViewTests: XCTestCase {
    
    // MARK: - Message Generation (View Logic)
    
    func test_notificationRowMessage_friendRequest_formatsCorrectly() {
        // Arrange
        let notification = TestNotificationBuilder.friendRequest(senderName: "Alice").build()
        let row = NotificationRow(note: notification)
        
        // Act
        let message = row.message
        
        // Assert
        NotificationTestAssertions.assertFriendRequestMessage(message, senderName: "Alice")
    }
    
    func test_notificationRowMessage_nudge_formatsCorrectly() {
        // Arrange
        let notification = TestNotificationBuilder.nudge(senderName: "Bob").build()
        let row = NotificationRow(note: notification)
        
        // Act
        let message = row.message
        
        // Assert
        NotificationTestAssertions.assertNudgeMessage(message, senderName: "Bob")
    }
    
    func test_notificationRowMessage_alwaysIncludesSenderName() {
        // Arrange: multiple senders
        let senders = ["Alice", "Bob", "Carol"]
        
        // Act & Assert
        for sender in senders {
            let notification = TestNotificationBuilder
                .friendRequest(senderName: sender)
                .build()
            let row = NotificationRow(note: notification)
            
            NotificationTestAssertions.assertContainsSenderName(row.message, senderName: sender)
        }
    }
}
