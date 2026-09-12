//
//  LocalNotificationSchedulerTests.swift
//  UFreeTests
//

import XCTest
@testable import UFree

@MainActor
final class LocalNotificationSchedulerTests: XCTestCase {
    func test_shouldSchedule_falseWhenRemindersDisabled() {
        XCTAssertFalse(
            LocalNotificationScheduler.shouldSchedule(
                lastWeekendActivityAt: nil,
                friendCount: 2,
                remindersEnabled: false
            )
        )
    }

    func test_shouldSchedule_falseWhenNoFriends() {
        XCTAssertFalse(
            LocalNotificationScheduler.shouldSchedule(
                lastWeekendActivityAt: nil,
                friendCount: 0,
                remindersEnabled: true
            )
        )
    }

    func test_shouldSchedule_falseWhenWeekendActivityIsFresh() {
        let now = Date()
        XCTAssertFalse(
            LocalNotificationScheduler.shouldSchedule(
                lastWeekendActivityAt: now.addingTimeInterval(-60 * 60),
                friendCount: 2,
                remindersEnabled: true,
                now: now
            )
        )
    }

    func test_shouldSchedule_falseUnderTestHost() {
        // XCTest is always present here, so TestConfiguration.isTesting is true.
        XCTAssertFalse(
            LocalNotificationScheduler.shouldSchedule(
                lastWeekendActivityAt: Date().addingTimeInterval(-10 * 24 * 60 * 60),
                friendCount: 3,
                remindersEnabled: true
            )
        )
    }

    func test_shouldSchedule_trueWhenFriendsExistAndActivityIsStale() {
        XCTAssertTrue(
            LocalNotificationScheduler.shouldSchedule(
                lastWeekendActivityAt: Date().addingTimeInterval(-10 * 24 * 60 * 60),
                friendCount: 2,
                remindersEnabled: true,
                allowInTests: true
            )
        )
    }
}
