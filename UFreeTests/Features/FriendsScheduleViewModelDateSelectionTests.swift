//
//  FriendsScheduleViewModelDateSelectionTests.swift
//  UFreeTests
//

import XCTest
@testable import UFree

/// Covers `toggleDate`, the day-filter half of `FriendsScheduleViewModel`.
@MainActor
final class FriendsScheduleViewModelDateSelectionTests: XCTestCase {

    private var sut: FriendsScheduleViewModel!

    override func setUp() {
        super.setUp()
        sut = FriendsScheduleViewModel(
            friendRepository: MockFriendRepository(),
            availabilityRepository: MockAvailabilityRepository(),
            notificationRepository: MockNotificationRepository()
        )
        trackForMemoryLeaks(sut)
    }

    override func tearDown() async throws {
        sut = nil
        await drainPendingTasks()
        verifyNoMemoryLeaks()
        try await super.tearDown()
    }

    func test_init_selectsToday() {
        XCTAssertEqual(sut.selectedDate, Calendar.current.startOfDay(for: Date()))
    }

    func test_toggleDate_normalisesToStartOfDay() {
        let afternoon = Calendar.current.date(bySettingHour: 15, minute: 30, second: 0, of: Date())!
        sut.selectedDate = nil

        sut.toggleDate(afternoon)

        XCTAssertEqual(sut.selectedDate, Calendar.current.startOfDay(for: afternoon))
    }

    func test_toggleDate_onTheSelectedDay_clearsTheFilter() {
        // `init` already selects today, so the first tap on today is the deselecting one.
        XCTAssertNotNil(sut.selectedDate)

        sut.toggleDate(Date())

        XCTAssertNil(sut.selectedDate)
    }

    func test_toggleDate_twiceOnTheSameDay_endsUpSelected() {
        sut.toggleDate(Date())

        sut.toggleDate(Date())

        XCTAssertEqual(sut.selectedDate, Calendar.current.startOfDay(for: Date()))
    }

    func test_toggleDate_atADifferentTimeOnTheSameDay_stillClearsTheFilter() {
        // The comparison is day-granular, so a different clock time on the selected day
        // counts as re-tapping the same day rather than selecting a new one.
        let morning = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        let evening = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date())!
        sut.selectedDate = nil
        sut.toggleDate(morning)

        sut.toggleDate(evening)

        XCTAssertNil(sut.selectedDate)
    }

    func test_toggleDate_onADifferentDay_movesTheFilter() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

        sut.toggleDate(tomorrow)

        XCTAssertEqual(sut.selectedDate, Calendar.current.startOfDay(for: tomorrow))
    }

    func test_toggleDate_fromClearedState_selectsTheDay() {
        let target = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        sut.selectedDate = nil

        sut.toggleDate(target)

        XCTAssertEqual(sut.selectedDate, Calendar.current.startOfDay(for: target))
    }
}
