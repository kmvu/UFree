//
//  MockAvailabilityRepositoryTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 22/12/25.
//

import XCTest
@testable import UFree

final class MockAvailabilityRepositoryTests: XCTestCase {
    
    private var repository: MockAvailabilityRepository!
    
    override func setUp() {
        super.setUp()
        repository = MockAvailabilityRepository()
    }
    
    // MARK: - Initial State
    
    func test_init_createsWeeklyScheduleWith7Days() async throws {
        let schedule = try await repository.getMySchedule()
        
        XCTAssertEqual(schedule.weeklyStatus.count, 7)
    }
    
    // MARK: - Get My Schedule
    
    func test_getMySchedule_returnsUserSchedule() async throws {
        let schedule = try await repository.getMySchedule()
        
        XCTAssertEqual(schedule.id, "me_123")
        XCTAssertEqual(schedule.name, "User")
        XCTAssertNil(schedule.avatarURL)
    }
    
    func test_getMySchedule_returnsCorrectDayCount() async throws {
        let schedule = try await repository.getMySchedule()
        
        XCTAssertEqual(schedule.weeklyStatus.count, 7)
    }
    
    // MARK: - Update Schedule
    
    func test_updateMySchedule_modifiesDay() async throws {
        let originalSchedule = try await repository.getMySchedule()
        let firstDay = originalSchedule.weeklyStatus[0]
        
        let updatedDay = DayAvailability(
            id: firstDay.id,
            date: firstDay.date,
            status: .busy
        )
        
        try await repository.updateMySchedule(for: updatedDay)
        
        let newSchedule = try await repository.getMySchedule()
        let newFirstDay = newSchedule.weeklyStatus[0]
        
        XCTAssertEqual(newFirstDay.status, .busy)
    }
    
    func test_updateMySchedule_persistsChanges() async throws {
        let originalSchedule = try await repository.getMySchedule()
        let firstDay = originalSchedule.weeklyStatus[0]
        
        try await repository.updateMySchedule(
            for: DayAvailability(id: firstDay.id, date: firstDay.date, status: .free)
        )
        
        let refreshedSchedule = try await repository.getMySchedule()
        
        XCTAssertEqual(refreshedSchedule.weeklyStatus[0].status, .free)
    }
    
    // MARK: - Get Friends Schedules
    
    func test_getSchedules_emptyList_returnsEmpty() async throws {
        let schedules = try await repository.getSchedules(for: [])
        
        XCTAssertEqual(schedules.count, 0)
    }

    func test_getSchedules_singleFriend_returnsSchedule() async throws {
        let today = Date()
        
        let schedule = UserSchedule(
            id: "friend1",
            name: "Alice",
            avatarURL: nil,
            weeklyStatus: [
                DayAvailability(date: today, status: .free),
                DayAvailability(date: Calendar.current.date(byAdding: .day, value: 1, to: today)!, status: .busy)
            ]
        )
        await repository.addFriendSchedule(schedule)
        
        let result = try await repository.getSchedules(for: ["friend1"])
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, "friend1")
        XCTAssertEqual(result[0].weeklyStatus.count, 2)
    }

    func test_getSchedules_multipleFriends_returnsAllSchedules() async throws {
        let today = Date()
        
        let schedule1 = UserSchedule(
            id: "friend1",
            name: "Alice",
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: today, status: .free)]
        )
        let schedule2 = UserSchedule(
            id: "friend2",
            name: "Bob",
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: today, status: .busy)]
        )
        let schedule3 = UserSchedule(
            id: "friend3",
            name: "Charlie",
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: today, status: .afternoonOnly)]
        )
        
        await repository.addFriendSchedule(schedule1)
        await repository.addFriendSchedule(schedule2)
        await repository.addFriendSchedule(schedule3)
        
        let result = try await repository.getSchedules(for: ["friend1", "friend2", "friend3"])
        
        XCTAssertEqual(result.count, 3)
        let ids = Set(result.map { $0.id })
        XCTAssertEqual(ids, ["friend1", "friend2", "friend3"])
    }

    func test_getSchedules_partialMatch_returnsOnlyFound() async throws {
        let today = Date()
        
        let schedule1 = UserSchedule(
            id: "friend1",
            name: "Alice",
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: today, status: .free)]
        )
        await repository.addFriendSchedule(schedule1)
        
        let result = try await repository.getSchedules(for: ["friend1", "friend2"])
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, "friend1")
    }

    func test_getSchedules_largeList_handlesBatching() async throws {
        let today = Date()
        
        var friendIds: [String] = []
        for i in 0..<25 {
            let friendId = "friend\(i)"
            friendIds.append(friendId)
            let schedule = UserSchedule(
                id: friendId,
                name: "Friend \(i)",
                avatarURL: nil,
                weeklyStatus: [DayAvailability(date: today, status: .free)]
            )
            await repository.addFriendSchedule(schedule)
        }
        
        let result = try await repository.getSchedules(for: friendIds)
        
        XCTAssertEqual(result.count, 25)
        let resultIds = Set(result.map { $0.id })
        XCTAssertEqual(resultIds.count, 25)
    }

    func test_getSchedules_withDataGaps_preservesOnlyFetchedData() async throws {
        let today = Date()
        
        let schedule = UserSchedule(
            id: "friend1",
            name: "Alice",
            avatarURL: nil,
            weeklyStatus: [
                DayAvailability(date: today, status: .free),
                DayAvailability(date: Calendar.current.date(byAdding: .day, value: 1, to: today)!, status: .busy)
            ]
        )
        await repository.addFriendSchedule(schedule)
        
        let result = try await repository.getSchedules(for: ["friend1"])
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].weeklyStatus.count, 2)
    }
}
