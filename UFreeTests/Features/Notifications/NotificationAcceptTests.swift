//
//  NotificationAcceptTests.swift
//  UFreeTests
//

import XCTest
@testable import UFree

@MainActor
final class NotificationAcceptTests: XCTestCase {
    private var notificationRepo: MockNotificationRepository!
    private var friendRepo: MockFriendRepository!
    private var friendsVM: FriendsViewModel!
    private var scheduleVM: MyScheduleViewModel!
    private var sut: NotificationViewModel!

    override func setUp() {
        super.setUp()
        notificationRepo = MockNotificationRepository()
        friendRepo = MockFriendRepository()
        friendsVM = FriendsViewModel(friendRepository: friendRepo)
        scheduleVM = MyScheduleViewModel(
            updateUseCase: NoopUpdateUseCase(),
            repository: MockAvailabilityRepository()
        )
        sut = NotificationViewModel(repository: notificationRepo, observesSceneLifecycle: false)
        sut.bind(
            friendsViewModel: friendsVM,
            scheduleViewModel: scheduleVM,
            rootViewModel: RootViewModel(authRepository: MockAuthRepository())
        )
        trackForMemoryLeaks(sut)
        trackForMemoryLeaks(friendsVM)
    }

    override func tearDown() {
        sut.stopListening()
        friendsVM.stopListening()
        sut = nil
        friendsVM = nil
        scheduleVM = nil
        friendRepo = nil
        notificationRepo = nil
        verifyNoMemoryLeaks()
        super.tearDown()
    }

    func test_acceptFriendRequest_usesRelatedRequestId_withoutIncomingCache() async {
        let requestId = "req_abc"
        let note = AppNotification(
            recipientId: "me",
            senderId: "alice",
            senderName: "Alice",
            type: .friendRequest,
            date: Date(),
            relatedRequestId: requestId
        )
        sut.notifications = [note]

        // Intentionally leave friendsVM.incomingRequests empty.
        await sut.acceptFriendRequest(from: note)

        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(friendsVM.friends.count, 1)
        XCTAssertEqual(friendsVM.friends.first?.id, "alice")
        XCTAssertTrue(sut.notifications[0].isRead)
    }

    func test_acceptFriendRequest_fallsBackToPendingFetch() async {
        let request = FriendRequest(
            id: "req_fetch",
            fromId: "bob",
            fromName: "Bob",
            toId: "me",
            status: .pending,
            timestamp: Date()
        )
        friendRepo.addIncomingRequest(request)
        // Do not call listenToRequests / populate friendsVM.incomingRequests.

        let note = AppNotification(
            recipientId: "me",
            senderId: "bob",
            senderName: "Bob",
            type: .friendRequest,
            date: Date()
        )
        sut.notifications = [note]

        await sut.acceptFriendRequest(from: note)

        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(friendsVM.friends.first?.id, "bob")
        XCTAssertTrue(sut.notifications[0].isRead)
    }

    func test_acceptFriendRequest_missingRequest_setsError() async {
        let note = AppNotification(
            recipientId: "me",
            senderId: "ghost",
            senderName: "Ghost",
            type: .friendRequest,
            date: Date()
        )

        await sut.acceptFriendRequest(from: note)

        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(friendsVM.friends.isEmpty)
    }

    func test_acceptFriendRequest_worksWhileFriendsLoading() async {
        let requestId = "req_busy"
        let note = AppNotification(
            recipientId: "me",
            senderId: "cara",
            senderName: "Cara",
            type: .friendRequest,
            date: Date(),
            relatedRequestId: requestId
        )
        sut.notifications = [note]

        // Simulate loadFriends holding the shared isProcessing flag.
        friendsVM.isProcessing = true
        await sut.acceptFriendRequest(from: note)

        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(friendsVM.friends.first?.id, "cara")
    }

    private final class NoopUpdateUseCase: UpdateMyStatusUseCaseProtocol {
        func execute(day: DayAvailability) async throws {}
    }
}
