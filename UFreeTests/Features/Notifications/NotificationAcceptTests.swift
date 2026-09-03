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
        let requestId = "alice_me"
        friendRepo.addIncomingRequest(
            FriendRequest(
                id: requestId,
                fromId: "alice",
                fromName: "Alice",
                toId: "me",
                status: .pending,
                timestamp: Date()
            )
        )
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
        XCTAssertFalse(sut.isFriendRequestActionable(sut.notifications[0]))
        XCTAssertEqual(sut.notifications[0].type, .friendAccepted)
        XCTAssertTrue(sut.notifications[0].isRead)
        XCTAssertEqual(sut.unreadCount, 0)
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

    func test_acceptFriendRequest_subsequentFriend_navigatesToFeed() async {
        friendsVM.friends = [
            UserProfile(id: "existing", displayName: "Existing", hashedPhoneNumber: "hash")
        ]
        let rootVM = RootViewModel(authRepository: MockAuthRepository())
        friendsVM.onAcceptCompleted = { friendName, wasFirstFriend in
            rootVM.handlePostAccept(friendName: friendName, wasFirstFriend: wasFirstFriend)
        }
        sut.bind(
            friendsViewModel: friendsVM,
            scheduleViewModel: scheduleVM,
            rootViewModel: rootVM
        )

        let requestId = "bob_me"
        friendRepo.addIncomingRequest(
            FriendRequest(
                id: requestId,
                fromId: "bob",
                fromName: "Bob",
                toId: "me",
                status: .pending,
                timestamp: Date()
            )
        )

        var note = AppNotification(
            recipientId: "me",
            senderId: "bob",
            senderName: "Bob",
            type: .friendRequest,
            date: Date(),
            relatedRequestId: requestId
        )
        note.id = "note-bob"
        sut.notifications = [note]
        sut.applyNotificationsUpdate([note])

        await sut.acceptFriendRequest(from: note)

        XCTAssertEqual(friendsVM.friends.count, 2)
        XCTAssertEqual(rootVM.activeTab, .feed)
        XCTAssertEqual(
            rootVM.celebrationToast,
            OnboardingProgressStore.subsequentConnectionToast(friendName: "Bob")
        )
        XCTAssertEqual(sut.notifications[0].type, .friendAccepted)
    }

    func test_acceptFriendRequest_worksWhileFriendsLoading() async {
        let requestId = "cara_me"
        friendRepo.addIncomingRequest(
            FriendRequest(
                id: requestId,
                fromId: "cara",
                fromName: "Cara",
                toId: "me",
                status: .pending,
                timestamp: Date()
            )
        )
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

    func test_acceptFriendRequest_clearsProcessingKeyAfterCompletion() async {
        let requestId = "dana_me"
        friendRepo.addIncomingRequest(
            FriendRequest(
                id: requestId,
                fromId: "dana",
                fromName: "Dana",
                toId: "me",
                status: .pending,
                timestamp: Date()
            )
        )
        let note = AppNotification(
            recipientId: "me",
            senderId: "dana",
            senderName: "Dana",
            type: .friendRequest,
            date: Date(),
            relatedRequestId: requestId
        )
        sut.notifications = [note]

        await sut.acceptFriendRequest(from: note)

        XCTAssertNil(sut.processingNotificationKey)
    }

    private final class NoopUpdateUseCase: UpdateMyStatusUseCaseProtocol {
        func execute(day: DayAvailability) async throws {}
    }
}
