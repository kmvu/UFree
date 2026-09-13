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
    static let caseyFriendId = "casey-ui-test"
    static let danaFriendId = "dana-ui-test"
    static let jordanFriendId = "jordan-ui-test"
    static let jordanPhone = "+15551234567"

    static func makeAuthRepository() -> MockAuthRepository {
        if TestConfiguration.uiTestingScenario == .login {
            return MockAuthRepository()
        }
        return MockAuthRepository(
            user: User(
                id: uiTestUserId,
                isAnonymous: false,
                displayName: "UI Tester"
            )
        )
    }

    static func makeFriendRepository() -> MockFriendRepository {
        let alex = alexProfile
        let casey = caseyProfile
        let dana = danaProfile
        let jordan = jordanProfile
        let caseyRequest = makeCaseyRequest()

        switch TestConfiguration.uiTestingScenario {
        case .login, .empty:
            return MockFriendRepository(
                myFriends: [],
                incomingRequests: [],
                allUsers: [jordan]
            )
        case .firstConnect:
            return MockFriendRepository(
                myFriends: [],
                incomingRequests: [caseyRequest],
                allUsers: [casey, jordan]
            )
        case .batchNudge:
            return MockFriendRepository(
                myFriends: [alex, dana],
                incomingRequests: [],
                allUsers: [alex, dana, jordan]
            )
        case .default, .partialDay, .busyUnknown, .unreadInbox, .offline:
            return MockFriendRepository(
                myFriends: [alex],
                incomingRequests: [caseyRequest],
                allUsers: [alex, jordan]
            )
        }
    }

    static func makeAvailabilityRemote() -> MockAvailabilityRepository {
        let repo = MockAvailabilityRepository()
        if TestConfiguration.uiTestingScenario == .offline {
            repo.shouldFailUpdates = true
        }

        switch TestConfiguration.uiTestingScenario {
        case .login, .empty, .firstConnect, .busyUnknown:
            return repo
        case .partialDay:
            repo.addFriendSchedule(schedule(for: alexFriendId, name: "Alex", saturday: .partialAfternoon, alsoToday: true))
            return repo
        case .batchNudge:
            repo.addFriendSchedule(schedule(for: alexFriendId, name: "Alex", saturday: .free, alsoToday: true))
            repo.addFriendSchedule(schedule(for: danaFriendId, name: "Dana", saturday: .partialAfternoon, alsoToday: true))
            return repo
        case .default, .unreadInbox, .offline:
            repo.addFriendSchedule(schedule(for: alexFriendId, name: "Alex", saturday: .free, alsoToday: true))
            return repo
        }
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

        let repo: MockNotificationRepository
        switch TestConfiguration.uiTestingScenario {
        case .login, .empty, .batchNudge, .busyUnknown:
            repo = MockNotificationRepository(notifications: [])
        case .firstConnect:
            repo = MockNotificationRepository(notifications: [requestNote])
        case .default, .partialDay, .unreadInbox, .offline:
            repo = MockNotificationRepository(notifications: [requestNote, nudgeNote])
        }
        if TestConfiguration.uiTestingScenario == .offline {
            repo.userIdsToFailFor = [alexFriendId]
        }
        return repo
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
        let daysUntilSaturday = (Calendar.saturdayWeekday - weekday + 7) % 7
        let saturday = calendar.date(byAdding: .day, value: daysUntilSaturday, to: reference)
            ?? reference.addingTimeInterval(TimeInterval(daysUntilSaturday) * 86_400)
        return calendar.startOfDay(for: saturday)
    }

    private static var alexProfile: UserProfile {
        UserProfile(id: alexFriendId, displayName: "Alex", hashedPhoneNumber: "ui_test_alex_hash")
    }

    private static var caseyProfile: UserProfile {
        UserProfile(id: caseyFriendId, displayName: "Casey", hashedPhoneNumber: "ui_test_casey_hash")
    }

    private static var danaProfile: UserProfile {
        UserProfile(id: danaFriendId, displayName: "Dana", hashedPhoneNumber: "ui_test_dana_hash")
    }

    private static var jordanProfile: UserProfile {
        UserProfile(
            id: jordanFriendId,
            displayName: "Jordan",
            hashedPhoneNumber: nil,
            hashedPhoneNumbers: CryptoUtils.phoneNumberHashes(for: jordanPhone)
        )
    }

    private static func makeCaseyRequest() -> FriendRequest {
        FriendRequest(
            id: FriendRequest.documentId(fromId: caseyFriendId, toId: uiTestUserId),
            fromId: caseyFriendId,
            fromName: "Casey",
            toId: uiTestUserId,
            status: .pending,
            timestamp: Date()
        )
    }

    private enum SaturdaySeed {
        case free
        case partialAfternoon
    }

    private static func schedule(
        for friendId: String,
        name: String,
        saturday: SaturdaySeed,
        alsoToday: Bool = false
    ) -> UserSchedule {
        let saturdayDate = nextSaturdayInUpcomingWeek()
        let weeklyStatus = (0..<7).compactMap { offset -> DayAvailability? in
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) else {
                return nil
            }
            let isSaturday = Calendar.current.isDate(date, inSameDayAs: saturdayDate)
            let isToday = Calendar.current.isDateInToday(date)
            guard isSaturday || (alsoToday && isToday) else {
                return DayAvailability(date: date, status: .unknown)
            }
            switch saturday {
            case .free:
                return DayAvailability(date: date, status: .free)
            case .partialAfternoon:
                let start = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
                let end = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: date) ?? date
                return DayAvailability(
                    date: date,
                    timeBlocks: [TimeBlock(startTime: start, endTime: end, status: .free)]
                )
            }
        }
        return UserSchedule(
            id: friendId,
            name: name,
            avatarURL: nil,
            weeklyStatus: weeklyStatus
        )
    }
}

private extension Calendar {
    static let saturdayWeekday = 7
}
