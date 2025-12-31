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
    
    override func setUp() async throws {
        try await super.setUp()
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
    
    func test_getFriendsSchedules_returnsEmptyArray() async throws {
        let schedules = try await repository.getFriendsSchedules()
        
        XCTAssertEqual(schedules.count, 0)
    }
}
