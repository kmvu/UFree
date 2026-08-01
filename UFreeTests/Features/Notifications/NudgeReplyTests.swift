//
//  NudgeReplyTests.swift
//  UFreeTests
//

import XCTest
@testable import UFree

@MainActor
final class NudgeReplyTests: XCTestCase {
    private var mockRepo: MockNotificationRepository!
    private var sut: NotificationViewModel!
    private var scheduleVM: MyScheduleViewModel!
    private var friendsVM: FriendsViewModel!
    private var rootVM: RootViewModel!
    private var updateSpy: UpdateSpy!

    override func setUp() {
        super.setUp()
        mockRepo = MockNotificationRepository()
        sut = NotificationViewModel(repository: mockRepo, observesSceneLifecycle: false)
        trackForMemoryLeaks(sut)

        updateSpy = UpdateSpy()
        let availabilityRepo = MockAvailabilityRepository()
        scheduleVM = MyScheduleViewModel(updateUseCase: updateSpy, repository: availabilityRepo)
        friendsVM = FriendsViewModel(friendRepository: MockFriendRepository())
        rootVM = RootViewModel(authRepository: MockAuthRepository())
        sut.bind(friendsViewModel: friendsVM, scheduleViewModel: scheduleVM, rootViewModel: rootVM)
    }

    override func tearDown() {
        sut.stopListening()
        sut = nil
        mockRepo = nil
        scheduleVM = nil
        friendsVM = nil
        rootVM = nil
        updateSpy = nil
        super.tearDown()
    }

    func test_replyToNudge_sendsReply() async {
        let today = Calendar.current.startOfDay(for: Date())
        let note = AppNotification(
            recipientId: "me",
            senderId: "friend1",
            senderName: "Alex",
            type: .nudge,
            date: Date(),
            targetDateString: AppNotification.dateString(from: today)
        )
        mockRepo.mockNotifications = [note]
        sut.notifications = [note]

        await sut.replyToNudge(note, response: .imIn)

        XCTAssertEqual(mockRepo.sentReplies.count, 1)
        XCTAssertEqual(mockRepo.sentReplies.first?.response, .imIn)
        XCTAssertEqual(mockRepo.sentReplies.first?.userId, "friend1")
        XCTAssertEqual(updateSpy.executeCallCount, 1)
        XCTAssertEqual(updateSpy.executedDay?.status, .free)
    }

    func test_sendNudge_includesTargetDate() async throws {
        let day = Calendar.current.startOfDay(for: Date())
        try await mockRepo.sendNudge(to: "friend2", targetDate: day)
        XCTAssertEqual(mockRepo.sentNudges.count, 1)
        XCTAssertEqual(
            mockRepo.sentNudges.first?.targetDate.map { Calendar.current.startOfDay(for: $0) },
            day
        )
    }

    private final class UpdateSpy: UpdateMyStatusUseCaseProtocol {
        var executeCallCount = 0
        var executedDay: DayAvailability?

        func execute(day: DayAvailability) async throws {
            executeCallCount += 1
            executedDay = day
        }
    }
}
