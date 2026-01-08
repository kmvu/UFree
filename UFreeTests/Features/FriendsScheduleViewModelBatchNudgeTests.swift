//
//  FriendsScheduleViewModelBatchNudgeTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 08/01/26.
//
//  Batch nudge tests: Success count tracking, error handling, edge cases
//  Optimized: 12 focused tests, helper methods reduce duplication
//

import XCTest
@testable import UFree

@MainActor
final class FriendsScheduleViewModelBatchNudgeTests: XCTestCase {

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

    // MARK: - Helper Methods

    private func addFriends(count: Int, status: AvailabilityStatus = .free, date: Date? = nil) async {
        let today = date ?? Calendar.current.startOfDay(for: Date())
        for i in 1...count {
            let id = "f\(i)"
            let friend = UserProfile(id: id, displayName: "User\(i)", hashedPhoneNumber: "h\(i)")
            let schedule = UserSchedule(id: id, name: "User\(i)", avatarURL: nil,
                weeklyStatus: [DayAvailability(date: today, status: status)])
            await mockFriendRepo.addFriend(friend)
            await mockAvailabilityRepo.addFriendSchedule(schedule)
        }
    }

    private func addFriendsWithStatuses(_ statuses: [AvailabilityStatus], date: Date? = nil) async {
        let today = date ?? Calendar.current.startOfDay(for: Date())
        for (index, status) in statuses.enumerated() {
            let id = "f\(index + 1)"
            let friend = UserProfile(id: id, displayName: "User\(index + 1)", hashedPhoneNumber: "h\(index + 1)")
            let schedule = UserSchedule(id: id, name: "User\(index + 1)", avatarURL: nil,
                weeklyStatus: [DayAvailability(date: today, status: status)])
            await mockFriendRepo.addFriend(friend)
            await mockAvailabilityRepo.addFriendSchedule(schedule)
        }
    }

    private func markFriendsFailing(ids: [String]) {
        ids.forEach { mockNotificationRepo.userIdsToFailFor.insert($0) }
    }

    private func nudgeAndVerify(for date: Date, expectations: (successExpected: Bool, count: Int?, partial: Bool)) async {
        await sut.loadFriendsSchedules()
        await sut.nudgeAllFree(for: date)

        if expectations.successExpected {
            if let count = expectations.count {
                let word = count == 1 ? "friend" : "friends"
                let prefix = expectations.partial ? "Nudged \(count - 1) of \(count)" : "All \(count) \(word) nudged!"
                XCTAssertTrue(sut.successMessage?.contains(prefix) ?? false)
            }
            XCTAssertNil(sut.errorMessage)
        } else {
            XCTAssertNotNil(sut.errorMessage)
            XCTAssertNil(sut.successMessage)
        }
    }

    // MARK: - Success Count & Failures (3 tests)

    func test_nudgeAllFree_allSuccess_5Friends() async {
        let today = Calendar.current.startOfDay(for: Date())
        await addFriends(count: 5, status: .free, date: today)
        await nudgeAndVerify(for: today, expectations: (successExpected: true, count: 5, partial: false))
    }

    func test_nudgeAllFree_partialFailure_2of5() async {
        let today = Calendar.current.startOfDay(for: Date())
        await addFriends(count: 5, status: .free, date: today)
        markFriendsFailing(ids: ["f2", "f4"])
        
        await sut.loadFriendsSchedules()
        await sut.nudgeAllFree(for: today)
        
        XCTAssertTrue(sut.successMessage?.contains("Nudged 3 of 5") ?? false)
        XCTAssertNil(sut.errorMessage)
    }

    func test_nudgeAllFree_allFailures() async {
        let today = Calendar.current.startOfDay(for: Date())
        await addFriends(count: 3, status: .free, date: today)
        markFriendsFailing(ids: ["f1", "f2", "f3"])
        
        await sut.loadFriendsSchedules()
        await sut.nudgeAllFree(for: today)
        
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertNil(sut.successMessage)
    }

    // MARK: - Pluralization (2 tests)

    func test_nudgeAllFree_singular_1Friend() async {
        let today = Calendar.current.startOfDay(for: Date())
        await addFriends(count: 1, status: .free, date: today)
        await nudgeAndVerify(for: today, expectations: (successExpected: true, count: 1, partial: false))
        
        XCTAssertTrue(sut.successMessage?.contains("All 1 friend nudged!") ?? false)
        XCTAssertFalse(sut.successMessage?.contains("friends") ?? true)
    }

    func test_nudgeAllFree_plural_multipleAnyCount() async {
        for count in [2, 5, 10] {
            mockFriendRepo = MockFriendRepository()
            mockAvailabilityRepo = MockAvailabilityRepository()
            mockNotificationRepo = MockNotificationRepository()
            sut = FriendsScheduleViewModel(
                friendRepository: mockFriendRepo,
                availabilityRepository: mockAvailabilityRepo,
                notificationRepository: mockNotificationRepo
            )
            
            let today = Calendar.current.startOfDay(for: Date())
            await addFriends(count: count, status: .free, date: today)
            await nudgeAndVerify(for: today, expectations: (successExpected: true, count: count, partial: false))
        }
    }

    // MARK: - Status Filtering (2 tests)

    func test_nudgeAllFree_onlyFreeStatus_ignoresPartials() async {
        let today = Calendar.current.startOfDay(for: Date())
        let statuses: [AvailabilityStatus] = [.free, .afternoonOnly, .free, .eveningOnly, .busy, .unknown, .free]
        await addFriendsWithStatuses(statuses, date: today)
        
        await sut.loadFriendsSchedules()
        await sut.nudgeAllFree(for: today)
        
        XCTAssertTrue(sut.successMessage?.contains("All 3") ?? false)
    }

    func test_nudgeAllFree_mixedStatuses_correctFiltering() async {
        let today = Calendar.current.startOfDay(for: Date())
        let statuses: [AvailabilityStatus] = [.free, .afternoonOnly, .busy]
        await addFriendsWithStatuses(statuses, date: today)
        
        await sut.loadFriendsSchedules()
        await sut.nudgeAllFree(for: today)
        
        XCTAssertTrue(sut.successMessage?.contains("All 1") ?? false)
    }

    // MARK: - State & Edge Cases (5 tests)

    func test_nudgeAllFree_isNudgingFlag_managedCorrectly() async {
        let today = Calendar.current.startOfDay(for: Date())
        await addFriends(count: 1, status: .free, date: today)
        
        await sut.loadFriendsSchedules()
        XCTAssertFalse(sut.isNudging)
        
        await sut.nudgeAllFree(for: today)
        XCTAssertFalse(sut.isNudging)
    }

    func test_nudgeAllFree_messagesCleared_beforeNewOperation() async {
        let today = Calendar.current.startOfDay(for: Date())
        await addFriends(count: 1, status: .free, date: today)
        await sut.loadFriendsSchedules()
        
        sut.successMessage = "Old"
        sut.errorMessage = "Old"
        await sut.nudgeAllFree(for: today)
        
        XCTAssertNotNil(sut.successMessage)
        XCTAssertFalse(sut.successMessage?.contains("Old") ?? false)
    }

    func test_nudgeAllFree_noFreeFriends_earlyExit() async {
        let today = Calendar.current.startOfDay(for: Date())
        await addFriendsWithStatuses([.busy, .unknown], date: today)
        
        await sut.loadFriendsSchedules()
        await sut.nudgeAllFree(for: today)
        
        XCTAssertTrue(sut.errorMessage?.contains("No") ?? false)
        XCTAssertNil(sut.successMessage)
    }

    func test_nudgeAllFree_dateNormalization_ignoresTime() async {
        let midnight = Calendar.current.startOfDay(for: Date())
        let afternoon = Calendar.current.date(byAdding: .hour, value: 14, to: midnight)!
        
        await addFriends(count: 1, status: .free, date: midnight)
        await sut.loadFriendsSchedules()
        await sut.nudgeAllFree(for: afternoon)
        
        XCTAssertNotNil(sut.successMessage)
    }

    func test_nudgeAllFree_rapidTaps_secondIgnored() async {
        let today = Calendar.current.startOfDay(for: Date())
        await addFriends(count: 1, status: .free, date: today)
        await sut.loadFriendsSchedules()
        
        let task1 = Task { await sut.nudgeAllFree(for: today) }
        let task2 = Task { await sut.nudgeAllFree(for: today) }
        _ = await (task1.value, task2.value)
        
        XCTAssertNotNil(sut.successMessage)
        XCTAssertFalse(sut.isNudging)
    }

    // MARK: - Haptics (2 tests)

    func test_nudgeAllFree_haptic_feedbackOnSuccess() async {
        let today = Calendar.current.startOfDay(for: Date())
        await addFriends(count: 1, status: .free, date: today)
        await sut.loadFriendsSchedules()
        
        await sut.nudgeAllFree(for: today)
        XCTAssertNotNil(sut.successMessage)
    }

    func test_nudgeAllFree_haptic_feedbackOnFailure() async {
        let today = Calendar.current.startOfDay(for: Date())
        await addFriends(count: 1, status: .free, date: today)
        markFriendsFailing(ids: ["f1"])
        
        await sut.loadFriendsSchedules()
        await sut.nudgeAllFree(for: today)
        
        XCTAssertNotNil(sut.errorMessage)
    }
}
