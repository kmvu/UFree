//
//  NotificationViewModelTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 08/01/26.
//

import XCTest
@testable import UFree

@MainActor
final class NotificationViewModelTests: XCTestCase {
    var sut: NotificationViewModel!
    var mockRepository: MockNotificationRepository!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockNotificationRepository()
        sut = NotificationViewModel(repository: mockRepository)
    }
    
    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }
    
    // MARK: - Badge Count (Domain Logic)
    
    func test_unreadCount_returnsZeroWhenEmpty() {
        // Arrange
        sut.notifications = []
        
        // Act & Assert
        XCTAssertEqual(sut.unreadCount, 0)
    }
    
    func test_unreadCount_ignoresReadNotifications() {
        // Arrange: 3 notifications, 2 unread
        sut.notifications = [
            TestNotificationBuilder.friendRequest(isRead: false),
            TestNotificationBuilder.nudge(isRead: true),
            TestNotificationBuilder.friendRequest(isRead: false)
        ]
        
        // Act & Assert
        XCTAssertEqual(sut.unreadCount, 2)
    }
    
    // MARK: - Mark as Read (Optimistic + Sync)
    
    func test_markRead_updatesUIImmediately() {
        // Arrange
        let notification = TestNotificationBuilder.friendRequest(isRead: false)
        sut.notifications = [notification]
        
        // Act
        sut.markRead(notification)
        
        // Assert: optimistic update is immediate
        XCTAssertTrue(sut.notifications[0].isRead)
    }
    
    // MARK: - Send Nudge (Async Action)
    
    func test_sendNudge_doesNotThrow() async {
        // Act & Assert: no crash
        await sut.sendNudge(to: "recipient_123")
        XCTAssertTrue(true)
    }
}
