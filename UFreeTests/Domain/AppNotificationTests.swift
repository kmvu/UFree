//
//  AppNotificationTests.swift
//  UFreeTests
//

import XCTest
@testable import UFree

final class AppNotificationTests: XCTestCase {
    func test_dateString_usesUTCFormatter_roundTrips() {
        let date = Date()
        let string = AppNotification.dateString(from: date)
        XCTAssertEqual(string, DateFormatter.yyyyMMdd.string(from: date))
        let parsed = AppNotification.date(from: string)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(DateFormatter.yyyyMMdd.string(from: parsed!), string)
    }

    func test_targetWeekdayLabel_presentWhenDateSet() {
        let note = AppNotification(
            recipientId: "r",
            senderId: "s",
            senderName: "Sam",
            type: .nudge,
            date: Date(),
            targetDateString: AppNotification.dateString(from: Date())
        )
        XCTAssertNotNil(note.targetWeekdayLabel)
        XCTAssertFalse(note.hasResponded)
    }

    func test_hasResponded_whenNudgeResponseSet() {
        let note = AppNotification(
            recipientId: "r",
            senderId: "s",
            senderName: "Sam",
            type: .nudge,
            date: Date(),
            nudgeResponse: AppNotification.NudgeResponse.imIn.rawValue
        )
        XCTAssertTrue(note.hasResponded)
    }
}
