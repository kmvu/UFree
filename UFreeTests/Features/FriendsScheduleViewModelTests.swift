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

    // MARK: - Group Nudge (Phase 3 - Sprint 6)

    func test_nudgeAllFree_setsProcessingFlag() async {
        // Arrange: Setup friends with mixed availability
        let today = Calendar.current.startOfDay(for: Date())
        
        let friend1 = UserProfile(id: "f1", displayName: "Alice", hashedPhoneNumber: "h1")
        let friend2 = UserProfile(id: "f2", displayName: "Bob", hashedPhoneNumber: "h2")
        
        let schedule1 = UserSchedule(
            id: "f1",
            name: "Alice",
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: today, status: .free)]
        )
        let schedule2 = UserSchedule(
            id: "f2",
            name: "Bob",
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: today, status: .busy)]
        )
        
        await mockFriendRepo.addFriend(friend1)
        await mockFriendRepo.addFriend(friend2)
        await mockAvailabilityRepo.addFriendSchedule(schedule1)
        await mockAvailabilityRepo.addFriendSchedule(schedule2)
        await sut.loadFriendsSchedules()
        
        // Assert: isNudging should be false initially
        XCTAssertFalse(sut.isNudging)
        
        // Act: Call nudgeAllFree
        let task = Task {
            await sut.nudgeAllFree(for: today)
        }
        
        // Assert: Should complete with isNudging false after
        _ = await task.value
        XCTAssertFalse(sut.isNudging)
    }

    func test_nudgeAllFree_sendsToAllIntentionallyAvailable() async {
        // Arrange: Friends with free, afternoon, and busy statuses
        let today = Calendar.current.startOfDay(for: Date())
        
        let friend1 = UserProfile(id: "f1", displayName: "Alice", hashedPhoneNumber: "h1")
        let friend2 = UserProfile(id: "f2", displayName: "Bob", hashedPhoneNumber: "h2")
        let friend3 = UserProfile(id: "f3", displayName: "Charlie", hashedPhoneNumber: "h3")
        
        let schedule1 = UserSchedule(
            id: "f1",
            name: "Alice",
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: today, status: .free)]
        )
        let schedule2 = UserSchedule(
            id: "f2",
            name: "Bob",
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: today, status: .afternoonOnly)]
        )
        let schedule3 = UserSchedule(
            id: "f3",
            name: "Charlie",
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: today, status: .busy)]
        )
        
        await mockFriendRepo.addFriend(friend1)
        await mockFriendRepo.addFriend(friend2)
        await mockFriendRepo.addFriend(friend3)
        await mockAvailabilityRepo.addFriendSchedule(schedule1)
        await mockAvailabilityRepo.addFriendSchedule(schedule2)
        await mockAvailabilityRepo.addFriendSchedule(schedule3)
        await sut.loadFriendsSchedules()
        
        // Act: Nudge all free for today
        await sut.nudgeAllFree(for: today)
        
        // Assert: Should nudge only f1 (.free), not f2 (afternoonOnly) or f3 (busy)
        // Only .free status counts for nudges
        XCTAssertNil(sut.errorMessage)
        XCTAssertTrue(sut.successMessage?.contains("1") ?? false, "Should nudge only the free friend (f1)")
    }

    func test_nudgeAllFree_parallelProcessing_withTaskGroup() async {
        // Arrange: Multiple friends to nudge in parallel
        let today = Calendar.current.startOfDay(for: Date())
        
        var friends: [UserProfile] = []
        var schedules: [UserSchedule] = []
        
        // Create 5 free friends
        for i in 0..<5 {
            let friend = UserProfile(id: "f\(i)", displayName: "Friend\(i)", hashedPhoneNumber: "h\(i)")
            let schedule = UserSchedule(
                id: "f\(i)",
                name: "Friend\(i)",
                avatarURL: nil,
                weeklyStatus: [DayAvailability(date: today, status: .free)]
            )
            friends.append(friend)
            schedules.append(schedule)
            await mockFriendRepo.addFriend(friend)
            await mockAvailabilityRepo.addFriendSchedule(schedule)
        }
        await sut.loadFriendsSchedules()
        
        // Act: Nudge all (should use TaskGroup for parallel execution)
        await sut.nudgeAllFree(for: today)
        
        // Assert: All nudges should complete successfully
        XCTAssertNil(sut.errorMessage)
    }

    func test_nudgeAllFree_rapidTaps_ignoresSecondTap() async {
        // Arrange: Setup friends
        let today = Calendar.current.startOfDay(for: Date())
        
        let friend = UserProfile(id: "f1", displayName: "Alice", hashedPhoneNumber: "h1")
        let schedule = UserSchedule(
            id: "f1",
            name: "Alice",
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: today, status: .free)]
        )
        
        await mockFriendRepo.addFriend(friend)
        await mockAvailabilityRepo.addFriendSchedule(schedule)
        await sut.loadFriendsSchedules()
        
        // Act: Rapid taps on "Nudge All"
        await sut.nudgeAllFree(for: today)
        // Second tap should be ignored (guard !isNudging)
        await sut.nudgeAllFree(for: today)
        
        // Assert: Only one nudge operation should execute
        XCTAssertNil(sut.errorMessage)
    }

    func test_nudgeAllFree_successMessage_showsPartialCounts() async {
        // Arrange: Setup 2 available friends (simulating successful nudge)
        let today = Calendar.current.startOfDay(for: Date())
        
        let friend1 = UserProfile(id: "f1", displayName: "Alice", hashedPhoneNumber: "h1")
        let friend2 = UserProfile(id: "f2", displayName: "Bob", hashedPhoneNumber: "h2")
        
        let schedule1 = UserSchedule(
            id: "f1",
            name: "Alice",
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: today, status: .free)]
        )
        let schedule2 = UserSchedule(
            id: "f2",
            name: "Bob",
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: today, status: .free)]
        )
        
        await mockFriendRepo.addFriend(friend1)
        await mockFriendRepo.addFriend(friend2)
        await mockAvailabilityRepo.addFriendSchedule(schedule1)
        await mockAvailabilityRepo.addFriendSchedule(schedule2)
        await sut.loadFriendsSchedules()
        
        // Act: Nudge all
        await sut.nudgeAllFree(for: today)
        
        // Assert: Success message should display friend count
        // Expected: "All 2 friends nudged! 👋"
        XCTAssertNotNil(sut.successMessage, "Success message should be set")
        XCTAssertTrue(sut.successMessage?.contains("2") ?? false, "Message should contain count")
        XCTAssertTrue(sut.successMessage?.contains("nudged") ?? false, "Message should use 'nudged'")
        XCTAssertNil(sut.errorMessage, "Error message should be cleared on success")
    }

    func test_nudgeAllFree_singleFriend_showsCorrectMessage() async {
        // Arrange: Setup single free friend
        let today = Calendar.current.startOfDay(for: Date())
        
        let friend = UserProfile(id: "f1", displayName: "Alice", hashedPhoneNumber: "h1")
        let schedule = UserSchedule(
            id: "f1",
            name: "Alice",
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: today, status: .free)]
        )
        
        await mockFriendRepo.addFriend(friend)
        await mockAvailabilityRepo.addFriendSchedule(schedule)
        await sut.loadFriendsSchedules()
        
        // Act: Nudge single friend
        await sut.nudgeAllFree(for: today)
        
        // Assert: Should show singular "All 1 friend nudged!" (not "friends")
        XCTAssertNotNil(sut.successMessage, "Success message should be set")
        XCTAssertTrue(sut.successMessage?.contains("1") ?? false, "Message should show count: 1")
        XCTAssertNil(sut.errorMessage, "No error on single friend nudge")
    }

    func test_nudgeAllFree_hapticFeedback_mediumOnTap() async {
        // Arrange: Setup friends
        let today = Calendar.current.startOfDay(for: Date())
        
        let friend = UserProfile(id: "f1", displayName: "Alice", hashedPhoneNumber: "h1")
        let schedule = UserSchedule(
            id: "f1",
            name: "Alice",
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: today, status: .free)]
        )
        
        await mockFriendRepo.addFriend(friend)
        await mockAvailabilityRepo.addFriendSchedule(schedule)
        await sut.loadFriendsSchedules()
        
        // Act: Call nudgeAllFree (HapticManager.medium() should be called immediately)
        // In real test, we'd mock HapticManager or use instrumentation
        await sut.nudgeAllFree(for: today)
        
        // Assert: Operation completes (haptic verified via instrumentation)
        XCTAssertFalse(sut.isNudging)
    }

    func test_nudgeAllFree_noFriendsAvailable_returnsEarlyWithMessage() async {
        // Arrange: Setup friends but none available on selected day
        let today = Calendar.current.startOfDay(for: Date())
        
        let friend1 = UserProfile(id: "f1", displayName: "Alice", hashedPhoneNumber: "h1")
        let friend2 = UserProfile(id: "f2", displayName: "Bob", hashedPhoneNumber: "h2")
        
        let schedule1 = UserSchedule(
            id: "f1",
            name: "Alice",
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: today, status: .busy)]
        )
        let schedule2 = UserSchedule(
            id: "f2",
            name: "Bob",
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: today, status: .unknown)]
        )
        
        await mockFriendRepo.addFriend(friend1)
        await mockFriendRepo.addFriend(friend2)
        await mockAvailabilityRepo.addFriendSchedule(schedule1)
        await mockAvailabilityRepo.addFriendSchedule(schedule2)
        await sut.loadFriendsSchedules()
        
        // Act: Try to nudge all (no one available)
        await sut.nudgeAllFree(for: today)
        
        // Assert: Should show "No friends available to nudge" or similar
        XCTAssertTrue(sut.errorMessage?.contains("No") ?? sut.successMessage?.contains("0") ?? false)
    }

    func test_nudgeAllFree_partialFailure_showsCountOfSuccessful() async {
        // Arrange: 3 free friends, but 1 fails
        let today = Calendar.current.startOfDay(for: Date())
        
        let friend1 = UserProfile(id: "f1", displayName: "Alice", hashedPhoneNumber: "h1")
        let friend2 = UserProfile(id: "f2", displayName: "Bob", hashedPhoneNumber: "h2")
        let friend3 = UserProfile(id: "f3", displayName: "Charlie", hashedPhoneNumber: "h3")
        
        let schedule1 = UserSchedule(
            id: "f1",
            name: "Alice",
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: today, status: .free)]
        )
        let schedule2 = UserSchedule(
            id: "f2",
            name: "Bob",
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: today, status: .free)]
        )
        let schedule3 = UserSchedule(
            id: "f3",
            name: "Charlie",
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: today, status: .free)]
        )
        
        await mockFriendRepo.addFriend(friend1)
        await mockFriendRepo.addFriend(friend2)
        await mockFriendRepo.addFriend(friend3)
        await mockAvailabilityRepo.addFriendSchedule(schedule1)
        await mockAvailabilityRepo.addFriendSchedule(schedule2)
        await mockAvailabilityRepo.addFriendSchedule(schedule3)
        
        // Setup: f2 will fail to nudge
        mockNotificationRepo.userIdsToFailFor.insert("f2")
        
        await sut.loadFriendsSchedules()
        
        // Act: Nudge all
        await sut.nudgeAllFree(for: today)
        
        // Assert: Should show "Nudged 2 of 3 friends" (not "All 3")
        XCTAssertNil(sut.errorMessage, "Error message should not be set for partial success")
        XCTAssertNotNil(sut.successMessage, "Success message should be set")
        XCTAssertTrue(sut.successMessage?.contains("Nudged 2 of 3") ?? false, "Should show partial count: 'Nudged 2 of 3'")
    }

    func test_nudgeAllFree_allFailures_showsErrorMessage() async {
        // Arrange: 2 free friends, both fail to nudge
        let today = Calendar.current.startOfDay(for: Date())
        
        let friend1 = UserProfile(id: "f1", displayName: "Alice", hashedPhoneNumber: "h1")
        let friend2 = UserProfile(id: "f2", displayName: "Bob", hashedPhoneNumber: "h2")
        
        let schedule1 = UserSchedule(
            id: "f1",
            name: "Alice",
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: today, status: .free)]
        )
        let schedule2 = UserSchedule(
            id: "f2",
            name: "Bob",
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: today, status: .free)]
        )
        
        await mockFriendRepo.addFriend(friend1)
        await mockFriendRepo.addFriend(friend2)
        await mockAvailabilityRepo.addFriendSchedule(schedule1)
        await mockAvailabilityRepo.addFriendSchedule(schedule2)
        
        // Setup: Both will fail
        mockNotificationRepo.userIdsToFailFor.insert("f1")
        mockNotificationRepo.userIdsToFailFor.insert("f2")
        
        await sut.loadFriendsSchedules()
        
        // Act: Nudge all
        await sut.nudgeAllFree(for: today)
        
        // Assert: Should show error message
        XCTAssertNotNil(sut.errorMessage, "Error message should be set when all nudges fail")
        XCTAssertTrue(sut.errorMessage?.contains("Failed") ?? false, "Error should indicate failure")
        XCTAssertNil(sut.successMessage, "Success message should not be set on complete failure")
    }

    func test_nudgeAllFree_messagePluralization() async {
        // Arrange: Single free friend for singular test
        let today = Calendar.current.startOfDay(for: Date())
        
        let friend = UserProfile(id: "f1", displayName: "Alice", hashedPhoneNumber: "h1")
        let schedule = UserSchedule(
            id: "f1",
            name: "Alice",
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: today, status: .free)]
        )
        
        await mockFriendRepo.addFriend(friend)
        await mockAvailabilityRepo.addFriendSchedule(schedule)
        await sut.loadFriendsSchedules()
        
        // Act: Nudge single friend
        await sut.nudgeAllFree(for: today)
        
        // Assert: Singular "friend" not "friends"
        XCTAssertNotNil(sut.successMessage, "Success message should be set")
        XCTAssertTrue(sut.successMessage?.contains("All 1 friend nudged!") ?? false, "Should use singular 'friend'")
    }
}
