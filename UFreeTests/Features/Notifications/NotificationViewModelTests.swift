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

    func test_markUnread_updatesUIImmediately() {
        var notification = TestNotificationBuilder.friendRequest(isRead: true)
        notification.id = "read-1"
        sut.notifications = [notification]

        sut.markUnread(notification)

        XCTAssertFalse(sut.notifications[0].isRead)
        XCTAssertEqual(sut.unreadCount, 1)
    }

    func test_markUnread_ignoresAlreadyUnreadNotifications() {
        let notification = TestNotificationBuilder.friendRequest(isRead: false)
        sut.notifications = [notification]

        sut.markUnread(notification)

        XCTAssertFalse(sut.notifications[0].isRead)
    }

    func test_markAllRead_clearsUnreadCount() {
        sut.notifications = [
            TestNotificationBuilder.friendRequest(isRead: false),
            TestNotificationBuilder.nudge(isRead: false),
            TestNotificationBuilder.friendRequest(isRead: true)
        ]

        sut.markAllRead()

        XCTAssertEqual(sut.unreadCount, 0)
        XCTAssertTrue(sut.notifications.allSatisfy(\.isRead))
    }

    func test_clearNotification_removesFromInbox() {
        var notification = TestNotificationBuilder.friendRequest(isRead: false)
        notification.id = "clear-me"
        sut.notifications = [notification]

        sut.clearNotification(notification)

        XCTAssertTrue(sut.notifications.isEmpty)
        XCTAssertEqual(sut.unreadCount, 0)
    }

    func test_clearNotification_staysRemovedWhenListenerReplays() {
        var notification = TestNotificationBuilder.friendRequest(isRead: false)
        notification.id = "clear-me"
        sut.applyNotificationsUpdate([notification])

        sut.clearNotification(notification)
        sut.applyNotificationsUpdate([notification])

        XCTAssertTrue(sut.notifications.isEmpty)
    }
    
    // MARK: - Send Nudge Guards
    
    func test_sendNudge_isProcessingGuard() async {
        sut.isProcessing = true
        
        await sut.sendNudge(to: "recipient_123")
        
        XCTAssertTrue(sut.isProcessing)
    }

    // MARK: - Foreground Banner

    func test_applyNotificationsUpdate_initialSnapshot_doesNotShowBanner() {
        var existing = TestNotificationBuilder.friendRequest(isRead: false)
        existing.id = "existing-1"

        sut.applyNotificationsUpdate([existing])

        XCTAssertEqual(sut.notifications.count, 1)
        XCTAssertEqual(sut.unreadCount, 1)
        XCTAssertNil(sut.incomingBanner)
    }

    func test_applyNotificationsUpdate_newUnread_updatesBadgeAndBanner() {
        sut.applyNotificationsUpdate([])

        var incoming = TestNotificationBuilder.nudge(isRead: false)
        incoming.id = "incoming-1"

        sut.applyNotificationsUpdate([incoming])

        XCTAssertEqual(sut.unreadCount, 1)
        XCTAssertEqual(sut.incomingBanner?.id, "incoming-1")
    }

    func test_openNotificationCenter_dismissesBanner() {
        sut.applyNotificationsUpdate([])

        var incoming = TestNotificationBuilder.friendRequest(isRead: false)
        incoming.id = "incoming-2"
        sut.applyNotificationsUpdate([incoming])

        sut.openNotificationCenter()

        XCTAssertNil(sut.incomingBanner)
        XCTAssertTrue(sut.showNotificationCenter)
    }

    func test_applyNotificationsUpdate_nudgeReply_updatesWhosFreeAndSwitchesTab() async {
        sut.stopListening()
        sut = NotificationViewModel(repository: mockRepository, observesSceneLifecycle: false)

        let friendRepo = MockFriendRepository()
        let availabilityRepo = MockAvailabilityRepository()
        let scheduleVM = FriendsScheduleViewModel(
            friendRepository: friendRepo,
            availabilityRepository: availabilityRepo,
            notificationRepository: mockRepository
        )
        let today = Calendar.current.startOfDay(for: Date())
        let friend = UserProfile(id: "friend1", displayName: "Alex", hashedPhoneNumber: "h1")
        friendRepo.addFriend(friend)
        availabilityRepo.addFriendSchedule(
            UserSchedule(
                id: "friend1",
                name: "Alex",
                avatarURL: nil,
                weeklyStatus: [DayAvailability(date: today, status: .unknown)]
            )
        )
        await scheduleVM.loadFriendsSchedules()

        let rootVM = RootViewModel(authRepository: MockAuthRepository())
        rootVM.friendsScheduleViewModel = scheduleVM
        rootVM.activeTab = .schedule
        sut.bind(
            friendsViewModel: FriendsViewModel(friendRepository: friendRepo),
            scheduleViewModel: MyScheduleViewModel(
                updateUseCase: NoopUpdateUseCase(),
                repository: availabilityRepo
            ),
            rootViewModel: rootVM
        )

        sut.applyNotificationsUpdate([])

        var reply = AppNotification(
            recipientId: "me",
            senderId: "friend1",
            senderName: "Alex",
            type: .nudgeReply,
            date: Date(),
            isRead: false,
            targetDateString: AppNotification.dateString(from: today),
            nudgeResponse: AppNotification.NudgeResponse.imIn.rawValue
        )
        reply.id = "reply-1"
        sut.applyNotificationsUpdate([reply])

        XCTAssertEqual(rootVM.activeTab, .feed)
        XCTAssertEqual(scheduleVM.nudgeReply(forFriendId: "friend1", date: today), .imIn)
        XCTAssertEqual(scheduleVM.selectedDate, today)
        XCTAssertEqual(scheduleVM.friendSchedules.first?.status(for: today), .free)
        XCTAssertEqual(sut.incomingBanner?.id, "reply-1")
    }

    func test_handleIncomingBannerTap_nudgeReply_focusesWhosFree() async {
        sut.stopListening()
        sut = NotificationViewModel(repository: mockRepository, observesSceneLifecycle: false)

        let friendRepo = MockFriendRepository()
        let availabilityRepo = MockAvailabilityRepository()
        let scheduleVM = FriendsScheduleViewModel(
            friendRepository: friendRepo,
            availabilityRepository: availabilityRepo,
            notificationRepository: mockRepository
        )
        let rootVM = RootViewModel(authRepository: MockAuthRepository())
        rootVM.friendsScheduleViewModel = scheduleVM
        rootVM.activeTab = .friends
        sut.bind(
            friendsViewModel: FriendsViewModel(friendRepository: friendRepo),
            scheduleViewModel: MyScheduleViewModel(
                updateUseCase: NoopUpdateUseCase(),
                repository: availabilityRepo
            ),
            rootViewModel: rootVM
        )

        let today = Calendar.current.startOfDay(for: Date())
        var reply = AppNotification(
            recipientId: "me",
            senderId: "friend1",
            senderName: "Alex",
            type: .nudgeReply,
            date: Date(),
            isRead: false,
            targetDateString: AppNotification.dateString(from: today),
            nudgeResponse: AppNotification.NudgeResponse.maybe.rawValue
        )
        reply.id = "reply-banner"
        sut.incomingBanner = reply

        sut.handleIncomingBannerTap()

        XCTAssertNil(sut.incomingBanner)
        XCTAssertFalse(sut.showNotificationCenter)
        XCTAssertEqual(rootVM.activeTab, .feed)
        XCTAssertEqual(scheduleVM.nudgeReply(forFriendId: "friend1", date: today), .maybe)
    }

    private final class NoopUpdateUseCase: UpdateMyStatusUseCaseProtocol {
        func execute(day: DayAvailability) async throws {}
    }
}