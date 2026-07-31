//
//  TestScene.swift
//  UFreeTests
//

import Foundation
@testable import UFree

/// A fully wired object graph of mock-backed ViewModels for hosting Views.
///
/// Views reach across ViewModels (`MyScheduleView` reads `rootViewModel.friendsScheduleViewModel`,
/// for instance), so building them one at a time in each test is both verbose and easy to
/// get subtly wrong. This assembles the whole graph the way `UFreeApp` does, but with mocks.
@MainActor
final class TestScene {

    let authRepository: MockAuthRepository
    let friendRepository: MockFriendRepository
    let availabilityRepository: MockAvailabilityRepository
    let notificationRepository: MockNotificationRepository
    let contactsRepository: ContactsRepositoryStub

    let rootViewModel: RootViewModel
    let scheduleViewModel: MyScheduleViewModel
    let friendsViewModel: FriendsViewModel
    let friendsScheduleViewModel: FriendsScheduleViewModel
    let notificationViewModel: NotificationViewModel

    init(
        user: User? = User(id: "me", isAnonymous: false, displayName: "Alice"),
        notifications: [AppNotification] = []
    ) {
        authRepository = MockAuthRepository(user: user)
        friendRepository = MockFriendRepository()
        availabilityRepository = MockAvailabilityRepository()
        notificationRepository = MockNotificationRepository(notifications: notifications)
        contactsRepository = ContactsRepositoryStub()

        rootViewModel = RootViewModel(authRepository: authRepository)
        rootViewModel.currentUser = user

        scheduleViewModel = MyScheduleViewModel(
            updateUseCase: UpdateMyStatusUseCase(repository: availabilityRepository),
            repository: availabilityRepository
        )
        friendsViewModel = FriendsViewModel(
            friendRepository: friendRepository,
            contactsRepository: contactsRepository
        )
        friendsScheduleViewModel = FriendsScheduleViewModel(
            friendRepository: friendRepository,
            availabilityRepository: availabilityRepository,
            notificationRepository: notificationRepository
        )
        notificationViewModel = NotificationViewModel(repository: notificationRepository)

        rootViewModel.friendsViewModel = friendsViewModel
        rootViewModel.friendsScheduleViewModel = friendsScheduleViewModel
    }

    // MARK: - Fixtures

    /// The seven consecutive days `MyScheduleViewModel` generates on init.
    var week: [Date] {
        scheduleViewModel.weeklySchedule.map(\.date)
    }

    func setMyStatus(_ status: AvailabilityStatus, onDayAt index: Int) {
        var day = scheduleViewModel.weeklySchedule[index]
        day.status = status
        scheduleViewModel.weeklySchedule[index] = day
    }

    /// Populates `friendsScheduleViewModel` with friends whose whole week uses `status`.
    @discardableResult
    func addFriendSchedules(count: Int, status: AvailabilityStatus = .free) -> [UserProfile] {
        let profiles = (0..<count).map { index in
            UserProfile(id: "friend_\(index)", displayName: "Friend \(index)")
        }

        friendsScheduleViewModel.friendSchedules = profiles.map { profile in
            FriendsScheduleViewModel.FriendScheduleDisplay(
                id: profile.id ?? "",
                displayName: profile.displayName,
                userSchedule: UserSchedule(
                    id: profile.id ?? "",
                    name: profile.displayName,
                    weeklyStatus: week.map { DayAvailability(date: $0, status: status) }
                )
            )
        }

        friendsViewModel.friends = profiles
        for profile in profiles {
            friendRepository.addFriend(profile)
        }
        return profiles
    }

    func makeFriendRequests(count: Int) -> [FriendRequest] {
        (0..<count).map { index in
            FriendRequest(
                id: "request_\(index)",
                fromId: "sender_\(index)",
                fromName: "Sender \(index)",
                toId: "me",
                status: .pending,
                timestamp: Date()
            )
        }
    }

    /// Static so fixtures can be built before a `TestScene` exists, which matters for
    /// anything passed to `init(notifications:)`.
    static func makeNudge(
        id: String = "n1",
        senderId: String = "friend_0",
        type: AppNotification.NotificationType = .nudge,
        isRead: Bool = false
    ) -> AppNotification {
        var notification = AppNotification(
            recipientId: "me",
            senderId: senderId,
            senderName: "Friend 0",
            type: type,
            date: Date(),
            isRead: isRead
        )
        notification.id = id
        return notification
    }

    func tearDown() {
        friendsViewModel.stopListening()
        notificationViewModel.stopListening()
    }
}
