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
        trackForMemoryLeaks(sut)
    }
    
    override func tearDown() {
        sut.stopListening()
        sut = nil
        mockRepository = nil
        verifyNoMemoryLeaks()
        super.tearDown()
    }
    
    // MARK: - Badge Count (Domain Logic)
    
    func test_unreadCount_returnsZeroWhenEmpty() {
        sut.notifications = []
        XCTAssertEqual(sut.unreadCount, 0)
    }
    
    func test_unreadCount_ignoresReadNotifications() {
        sut.notifications = [
            TestNotificationBuilder.friendRequest(isRead: false),
            TestNotificationBuilder.nudge(isRead: true),
            TestNotificationBuilder.friendRequest(isRead: false)
        ]
        XCTAssertEqual(sut.unreadCount, 2)
    }
    
    // MARK: - Mark as Read (Optimistic + Sync)
    
    func test_markRead_updatesUIImmediately() {
        let notification = TestNotificationBuilder.friendRequest(isRead: false)
        sut.notifications = [notification]
        
        sut.markRead(notification)
        
        XCTAssertTrue(sut.notifications[0].isRead)
    }
    
    // MARK: - Lifecycle and Listening
    
    func test_startListening_cancelsPreviousTask() {
        sut.startListening()
        let _ = sut.task
        
        sut.startListening()
        let newTask = sut.task
        
        XCTAssertNotNil(newTask)
    }
    
    func test_stopListening_cancelsTask() {
        sut.startListening()
        sut.stopListening()
        
        XCTAssertNil(sut.task)
    }
    
    // MARK: - Mark as Read Guards
    
    func test_markRead_ignoresAlreadyReadNotifications() {
        let notification = TestNotificationBuilder.friendRequest(isRead: true)
        sut.notifications = [notification]
        
        sut.markRead(notification)
        
        XCTAssertTrue(sut.notifications[0].isRead)
    }
    
    // MARK: - Send Nudge Guards
    
    func test_sendNudge_isProcessingGuard() async {
        sut.isProcessing = true
        
        await sut.sendNudge(to: "recipient_123")
        
        XCTAssertTrue(sut.isProcessing)
    }
}