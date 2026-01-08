//
//  MockNotificationRepositoryTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 08/01/26.
//

import XCTest
@testable import UFree

final class MockNotificationRepositoryTests: XCTestCase {
    var sut: MockNotificationRepository!
    
    override func setUp() {
        super.setUp()
        sut = MockNotificationRepository()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Listen to Notifications
    
    func test_listenToNotifications_returnsAsyncStream() async {
        // Act: subscribe to stream
        let stream = sut.listenToNotifications()
        
        // Assert: can iterate at least once
        var iterationCount = 0
        for await _ in stream {
            iterationCount += 1
            break
        }
        XCTAssertEqual(iterationCount, 1)
    }
    
    // MARK: - Mark as Read
    
    func test_markAsRead_doesNotThrow() async throws {
        // Arrange
        let notification = TestNotificationBuilder.friendRequest().build()
        
        // Act & Assert: no error
        try await sut.markAsRead(notification)
        XCTAssertTrue(true)
    }
    
    // MARK: - Send Nudge
    
    func test_sendNudge_doesNotThrow() async throws {
        // Act & Assert
        try await sut.sendNudge(to: "user_123")
        XCTAssertTrue(true)
    }
}
