//
//  NotificationTestAssertions.swift
//  UFreeTests
//
//  Created by Khang Vu on 08/01/26.
//

import XCTest
@testable import UFree

/// Helper assertions for notification tests
struct NotificationTestAssertions {
    
    static func assertFriendRequestMessage(
        _ message: String,
        senderName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expected = "\(senderName) sent you a friend request."
        XCTAssertEqual(message, expected, file: file, line: line)
    }
    
    static func assertNudgeMessage(
        _ message: String,
        senderName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expected = "\(senderName) nudged you! 👋"
        XCTAssertEqual(message, expected, file: file, line: line)
    }
    
    static func assertContainsSenderName(
        _ message: String,
        senderName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(message.contains(senderName), file: file, line: line)
    }
}
