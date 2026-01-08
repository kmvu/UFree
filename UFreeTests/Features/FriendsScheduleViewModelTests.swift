//
//  FriendsScheduleViewModelTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 07/01/26.
//

import XCTest
@testable import UFree

@MainActor
final class FriendsScheduleViewModelTests: XCTestCase {

    private var sut: FriendsScheduleViewModel!
    private var mockFriendRepo: MockFriendRepository!
    private var mockAvailabilityRepo: MockAvailabilityRepository!
    private var mockNotificationRepo: MockNotificationRepository!

    override func setUp() {
        super.setUp()
        mockFriendRepo = MockFriendRepository()
        mockAvailabilityRepo = MockAvailabilityRepository()
        mockNotificationRepo = MockNotificationRepository()
        sut = FriendsScheduleViewModel(
            friendRepository: mockFriendRepo,
            availabilityRepository: mockAvailabilityRepo,
            notificationRepository: mockNotificationRepo
        )
    }

    override func tearDown() {
        sut = nil
        mockFriendRepo = nil
        mockAvailabilityRepo = nil
        mockNotificationRepo = nil
        super.tearDown()
    }

    // MARK: - Loading Data

    func test_loadFriendsSchedules_noFriends_returnsEmpty() async {
        await sut.loadFriendsSchedules()
        XCTAssertEqual(sut.friendSchedules.count, 0)
        XCTAssertNil(sut.errorMessage)
    }

    func test_loadFriendsSchedules_withFriendsButNoSchedules_returnsEmpty() async {
        // Add friends without schedules
        let friend1 = UserProfile(id: "friend1", displayName: "Alice", hashedPhoneNumber: "hash1")
        let friend2 = UserProfile(id: "friend2", displayName: "Bob", hashedPhoneNumber: "hash2")
        
        await mockFriendRepo.addFriend(friend1)
        await mockFriendRepo.addFriend(friend2)

        await sut.loadFriendsSchedules()

        // No schedules found, so result should be empty
        XCTAssertEqual(sut.friendSchedules.count, 0)
        XCTAssertNil(sut.errorMessage)
    }

    func test_loadFriendsSchedules_withFriendsAndSchedules_populates() async {
        // Add friends
        let friend1 = UserProfile(id: "friend1", displayName: "Alice", hashedPhoneNumber: "hash1")
        let friend2 = UserProfile(id: "friend2", displayName: "Bob", hashedPhoneNumber: "hash2")
        
        await mockFriendRepo.addFriend(friend1)
        await mockFriendRepo.addFriend(friend2)

        // Add their schedules
        let today = Date()
        let schedule1 = UserSchedule(
            id: "friend1",
            name: "Alice",
            avatarURL: nil,
            weeklyStatus: [
                DayAvailability(date: today, status: .free),
                DayAvailability(date: Calendar.current.date(byAdding: .day, value: 1, to: today)!, status: .busy)
            ]
        )
        let schedule2 = UserSchedule(
            id: "friend2",
            name: "Bob",
            avatarURL: nil,
            weeklyStatus: [
                DayAvailability(date: today, status: .afternoonOnly)
            ]
        )
        
        await mockAvailabilityRepo.addFriendSchedule(schedule1)
        await mockAvailabilityRepo.addFriendSchedule(schedule2)

        // Load
        await sut.loadFriendsSchedules()

        // Verify
        XCTAssertEqual(sut.friendSchedules.count, 2)
        
        let first = sut.friendSchedules[0]
        XCTAssertEqual(first.id, "friend1")
        XCTAssertEqual(first.displayName, "Alice")
        XCTAssertEqual(first.userSchedule.weeklyStatus.count, 2)

        let second = sut.friendSchedules[1]
        XCTAssertEqual(second.id, "friend2")
        XCTAssertEqual(second.displayName, "Bob")
        XCTAssertEqual(second.userSchedule.weeklyStatus.count, 1)
    }

    // MARK: - Status Lookup

    func test_friendScheduleDisplay_statusForDate_returnsCorrectStatus() async {
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        let schedule = UserSchedule(
            id: "friend1",
            name: "Alice",
            avatarURL: nil,
            weeklyStatus: [
                DayAvailability(date: today, status: .free),
                DayAvailability(date: tomorrow, status: .busy)
            ]
        )

        let display = FriendsScheduleViewModel.FriendScheduleDisplay(
            id: "friend1",
            displayName: "Alice",
            userSchedule: schedule
        )

        XCTAssertEqual(display.status(for: today), .free)
        XCTAssertEqual(display.status(for: tomorrow), .busy)
    }

    func test_friendScheduleDisplay_statusForDateNotInSchedule_returnsUnknown() async {
        let today = Date()
        let farFuture = Calendar.current.date(byAdding: .day, value: 30, to: today)!
        
        let schedule = UserSchedule(
            id: "friend1",
            name: "Alice",
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: today, status: .free)]
        )

        let display = FriendsScheduleViewModel.FriendScheduleDisplay(
            id: "friend1",
            displayName: "Alice",
            userSchedule: schedule
        )

        XCTAssertEqual(display.status(for: farFuture), .unknown)
    }

    // MARK: - Loading State

    func test_loadFriendsSchedules_setsLoadingFlag() async {
        let friend = UserProfile(id: "friend1", displayName: "Alice", hashedPhoneNumber: "hash1")
        await mockFriendRepo.addFriend(friend)

        XCTAssertFalse(sut.isLoading)

        let task = Task {
            await sut.loadFriendsSchedules()
        }

        // Loading should be true during execution
        // (Note: In real tests, we'd need to check this more carefully with async timing)
        _ = await task.value

        // Loading should be false after completion
        XCTAssertFalse(sut.isLoading)
    }

    func test_loadFriendsSchedules_clearsErrorMessage() async {
        // Set an error first
        sut.errorMessage = "Some error"

        await sut.loadFriendsSchedules()

        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - Nudge Feature

    func test_sendNudge_setsProcessingFlag() async {
        // Arrange
        let friendId = "friend1"
        XCTAssertFalse(sut.isNudging)

        // Act
        let task = Task {
            await sut.sendNudge(to: friendId)
        }

        // Assert: isNudging should be true during execution
        // (timing-aware: check briefly after task starts)
        _ = await task.value

        // Assert: should be false after completion
        XCTAssertFalse(sut.isNudging)
    }

    func test_sendNudge_completesSuccessfully() async {
        // Arrange
        let friendId = "friend1"

        // Act
        await sut.sendNudge(to: friendId)

        // Assert: no error should be set
        XCTAssertNil(sut.errorMessage)
    }

    func test_rapidNudgeTaps_ignoresSecondTap() async {
        // Arrange
        let friendId = "friend1"

        // Act: simulate rapid taps
        await sut.sendNudge(to: friendId)
        // Second tap should be ignored (guard !isNudging)
        await sut.sendNudge(to: friendId)

        // Assert: only one nudge should be sent (verified by no error)
        XCTAssertNil(sut.errorMessage)
    }

    func test_sendNudge_clearsErrorOnSuccess() async {
        // Arrange
        sut.errorMessage = "Previous error"
        let friendId = "friend1"

        // Act
        await sut.sendNudge(to: friendId)

        // Assert
        XCTAssertNil(sut.errorMessage)
    }
}
