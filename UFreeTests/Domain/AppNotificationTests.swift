//
//  AppNotificationTests.swift
//  UFreeTests
//

import XCTest
@testable import UFree

final class AppNotificationTests: XCTestCase {
    func test_dateString_roundTrips() {
        let date = Calendar.current.startOfDay(for: Date())
        let string = AppNotification.dateString(from: date)
        let parsed = AppNotification.date(from: string)
        XCTAssertNotNil(parsed)
        XCTAssertTrue(Calendar.current.isDate(parsed!, inSameDayAs: date))
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
