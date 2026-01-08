//
//  DayFilterViewModelTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 01/01/26.
//

import XCTest
@testable import UFree

@MainActor
final class DayFilterViewModelTests: XCTestCase {
    var viewModel: DayFilterViewModel!
    var mockFriendRepo: MockFriendRepository!
    var mockAvailabilityRepo: MockAvailabilityRepository!

    override func setUp() {
        super.setUp()
        mockFriendRepo = MockFriendRepository()
        mockAvailabilityRepo = MockAvailabilityRepository()
        viewModel = DayFilterViewModel(
            friendRepository: mockFriendRepo,
            availabilityRepository: mockAvailabilityRepo
        )
    }

    override func tearDown() {
        viewModel = nil
        mockFriendRepo = nil
        mockAvailabilityRepo = nil
        super.tearDown()
    }
    
    // MARK: - Test Helpers
    
    /// Creates a UserSchedule with a single DayAvailability entry
    private func makeSchedule(id: String, name: String, date: Date, status: AvailabilityStatus) -> UserSchedule {
        UserSchedule(
            id: id,
            name: name,
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: date, status: status)]
        )
    }
    
    /// Creates a UserSchedule with multiple DayAvailability entries
    private func makeSchedule(id: String, name: String, entries: [(Date, AvailabilityStatus)]) -> UserSchedule {
        let dayAvails = entries.map { DayAvailability(date: $0.0, status: $0.1) }
        return UserSchedule(id: id, name: name, avatarURL: nil, weeklyStatus: dayAvails)
    }

    // MARK: - Day Selection (Existing)

    func test_initialSelectedDay_isNil() {
        XCTAssertNil(viewModel.selectedDay)
    }

    func test_toggleDay_selectsDay() {
        let date = Date()
        viewModel.toggleDay(date)
        XCTAssertEqual(viewModel.selectedDay, date)
    }

    func test_toggleDay_deselectsDay() {
        let date = Date()
        viewModel.toggleDay(date)
        viewModel.toggleDay(date)
        XCTAssertNil(viewModel.selectedDay)
    }

    func test_toggleDay_switchesBetweenDays() {
        let date1 = Date()
        let date2 = Date().addingTimeInterval(86400) // Next day

        viewModel.toggleDay(date1)
        XCTAssertEqual(viewModel.selectedDay, date1)

        viewModel.toggleDay(date2)
        XCTAssertEqual(viewModel.selectedDay, date2)
    }

    func test_rapidToggle_same_day() {
        let date = Date()

        // Rapid toggles on same day
        viewModel.toggleDay(date)
        viewModel.toggleDay(date)
        viewModel.toggleDay(date)

        // Final state should be selected (odd number of toggles)
        XCTAssertEqual(viewModel.selectedDay, date)
    }

    func test_clearSelection() {
        let date = Date()
        viewModel.toggleDay(date)
        XCTAssertEqual(viewModel.selectedDay, date)

        viewModel.clearSelection()
        XCTAssertNil(viewModel.selectedDay)
    }

    func test_multipleSelectionChanges() {
        let date1 = Date()
        let date2 = Date().addingTimeInterval(86400)
        let date3 = Date().addingTimeInterval(172800)

        viewModel.toggleDay(date1)
        XCTAssertEqual(viewModel.selectedDay, date1)

        viewModel.toggleDay(date2)
        XCTAssertEqual(viewModel.selectedDay, date2)

        viewModel.toggleDay(date3)
        XCTAssertEqual(viewModel.selectedDay, date3)

        viewModel.clearSelection()
        XCTAssertNil(viewModel.selectedDay)
    }

    // MARK: - Availability Heatmap (Phase 1 - Sprint 6)

    func test_freeFriendCount_noFriends_returnsZero() {
        // Arrange: No friends
        let today = Date()
        let schedules: [UserSchedule] = []
        
        // Act
        let count = viewModel.freeFriendCount(for: today, friendsSchedules: schedules)
        
        // Assert
        XCTAssertEqual(count, 0)
    }

    func test_freeFriendCount_countsFreeStatus() async {
        // Arrange: Friends with mixed availability
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        // Friend 1: Free today, busy tomorrow
        let schedule1 = makeSchedule(id: "f1", name: "Alice", entries: [
            (today, .free),
            (tomorrow, .busy)
        ])
        
        // Friend 2: Afternoon only today, free tomorrow
        let schedule2 = makeSchedule(id: "f2", name: "Bob", entries: [
            (today, .afternoonOnly),
            (tomorrow, .free)
        ])
        
        let schedules = [schedule1, schedule2]
        
        // Act: Count free on today and tomorrow
        let todayFreeCount = viewModel.freeFriendCount(for: today, friendsSchedules: schedules)
        let tomorrowFreeCount = viewModel.freeFriendCount(for: tomorrow, friendsSchedules: schedules)
        
        // Assert: Only .free status counts
        // Today: Only Alice is free = 1
        // Tomorrow: Only Bob is free = 1
        XCTAssertEqual(todayFreeCount, 1, "Today should have 1 free friend")
        XCTAssertEqual(tomorrowFreeCount, 1, "Tomorrow should have 1 free friend")
    }

    func test_freeFriendCount_excludesPartialAvailability() async {
        // Arrange: Mix of free and partial statuses
        let today = Calendar.current.startOfDay(for: Date())
        
        let schedules = [
            makeSchedule(id: "f1", name: "Alice", date: today, status: .free),
            makeSchedule(id: "f2", name: "Bob", date: today, status: .afternoonOnly),
            makeSchedule(id: "f3", name: "Charlie", date: today, status: .eveningOnly)
        ]
        
        // Act
        let count = viewModel.freeFriendCount(for: today, friendsSchedules: schedules)
        
        // Assert: Only Alice (free), not Bob/Charlie (partial)
        XCTAssertEqual(count, 1, "Partial availability should not be counted")
    }

    func test_freeFriendCount_excludesBusyAndUnknown() async {
        // Arrange: Mix of free, busy, unknown
        let today = Calendar.current.startOfDay(for: Date())
        
        let schedules = [
            makeSchedule(id: "f1", name: "Alice", date: today, status: .free),
            makeSchedule(id: "f2", name: "Bob", date: today, status: .busy),
            makeSchedule(id: "f3", name: "Charlie", date: today, status: .unknown)
        ]
        
        // Act
        let count = viewModel.freeFriendCount(for: today, friendsSchedules: schedules)
        
        // Assert: Only 1 (Alice is free)
        XCTAssertEqual(count, 1, "Busy and unknown should not be counted")
    }

    func test_freeFriendCount_multipleFreeFriends() async {
        // Arrange: Multiple free friends on same day
        let today = Calendar.current.startOfDay(for: Date())
        
        let schedules = [
            makeSchedule(id: "f1", name: "Alice", date: today, status: .free),
            makeSchedule(id: "f2", name: "Bob", date: today, status: .free),
            makeSchedule(id: "f3", name: "Charlie", date: today, status: .free)
        ]
        
        // Act
        let count = viewModel.freeFriendCount(for: today, friendsSchedules: schedules)
        
        // Assert: All 3 are free
        XCTAssertEqual(count, 3, "All free friends should be counted")
    }

    func test_freeFriendCount_dateNotInSchedule_returnsZero() async {
        // Arrange: Friends with schedule for different date
        let today = Calendar.current.startOfDay(for: Date())
        let farFuture = Calendar.current.date(byAdding: .day, value: 30, to: today)!
        
        let schedule = UserSchedule(
            id: "f1",
            name: "Alice",
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: today, status: .free)]
        )
        
        let schedules = [schedule]
        
        // Act: Query far future date
        let count = viewModel.freeFriendCount(for: farFuture, friendsSchedules: schedules)
        
        // Assert: Should be 0 (no data for that date)
        XCTAssertEqual(count, 0)
    }
}
