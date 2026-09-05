//
//  UITestingBootstrap.swift
//  UFree
//
//  Seeds mock repositories when launched with UI_TESTING_MODE.
//

import Foundation
import SwiftData

enum UITestingBootstrap {
    static let uiTestUserId = "ui-test-user"
    static let alexFriendId = "alex-ui-test"

    static func makeAuthRepository() -> MockAuthRepository {
        MockAuthRepository(
            user: User(
                id: uiTestUserId,
                isAnonymous: false,
                displayName: "UI Tester"
            )
        )
    }

    static let caseyFriendId = "casey-ui-test"

    static func makeFriendRepository() -> MockFriendRepository {
        let alex = UserProfile(
            id: alexFriendId,
            displayName: "Alex",
            hashedPhoneNumber: "ui_test_alex_hash"
        )
        let caseyRequest = FriendRequest(
            id: FriendRequest.documentId(fromId: caseyFriendId, toId: uiTestUserId),
            fromId: caseyFriendId,
            fromName: "Casey",
            toId: uiTestUserId,
            status: .pending,
            timestamp: Date()
        )
        return MockFriendRepository(
            myFriends: [alex],
            incomingRequests: [caseyRequest],
            allUsers: [alex]
        )
    }

    static func makeAvailabilityRemote() -> MockAvailabilityRepository {
        let repo = MockAvailabilityRepository()
        let saturday = nextSaturdayInUpcomingWeek()
        let weeklyStatus = (0..<7).compactMap { offset -> DayAvailability? in
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) else {
                return nil
            }
            let isSaturday = Calendar.current.isDate(date, inSameDayAs: saturday)
            return DayAvailability(date: date, status: isSaturday ? .free : .unknown)
        }
        repo.addFriendSchedule(
            UserSchedule(
                id: alexFriendId,
                name: "Alex",
                avatarURL: nil,
                weeklyStatus: weeklyStatus
            )
        )
        return repo
    }

    static func makeNotificationRepository() -> MockNotificationRepository {
        let saturday = nextSaturdayInUpcomingWeek()
        var requestNote = AppNotification(
            recipientId: uiTestUserId,
            senderId: caseyFriendId,
            senderName: "Casey",
            type: .friendRequest,
            date: Date(),
            isRead: false,
            relatedRequestId: FriendRequest.documentId(fromId: caseyFriendId, toId: uiTestUserId)
        )
        requestNote.id = "ui-test-casey-request"

        var nudgeNote = AppNotification(
            recipientId: uiTestUserId,
            senderId: alexFriendId,
            senderName: "Alex",
            type: .nudge,
            date: Date(),
            isRead: false,
            targetDateString: AppNotification.dateString(from: saturday)
        )
        nudgeNote.id = "ui-test-alex-nudge"

        return MockNotificationRepository(notifications: [requestNote, nudgeNote])
    }

    static func makeLocalAvailability(container: ModelContainer) -> SwiftDataAvailabilityRepository {
        let local = SwiftDataAvailabilityRepository(container: container)
        local.bind(userId: uiTestUserId)
        return local
    }

    /// Next Saturday within the next 7 days (including today when today is Saturday).
    static func nextSaturdayInUpcomingWeek(from reference: Date = Date()) -> Date {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: reference)
        // Gregorian: Sunday = 1 … Saturday = 7
        let daysUntilSaturday = (Calendar.saturdayWeekday - weekday + 7) % 7
        let saturday = calendar.date(byAdding: .day, value: daysUntilSaturday, to: reference)
            ?? reference.addingTimeInterval(TimeInterval(daysUntilSaturday) * 86_400)
        return calendar.startOfDay(for: saturday)
    }
}

private extension Calendar {
    static let saturdayWeekday = 7
}
