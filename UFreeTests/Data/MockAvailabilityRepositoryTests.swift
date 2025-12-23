//
//  MockAvailabilityRepositoryTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 22/12/25.
//

import XCTest
import Foundation
@testable import UFree

final class MockAvailabilityRepositoryTests: XCTestCase {
    
    func test_init_prepopulatesSevenDaysWithUnknownStatus() async throws {
        let repository = MockAvailabilityRepository()
        let schedule = try await repository.getMySchedule()
        
        XCTAssertEqual(schedule.weeklyStatus.count, 7)
        schedule.weeklyStatus.forEach { day in
            XCTAssertEqual(day.status, .unknown)
        }
    }
    
    func test_init_generatesNextSevenDaysFromToday() async throws {
        let repository = MockAvailabilityRepository()
        let schedule = try await repository.getMySchedule()
        let calendar = Calendar.current
        let today = Date()
        
        for (index, day) in schedule.weeklyStatus.enumerated() {
            guard let expectedDate = calendar.date(byAdding: .day, value: index, to: today) else {
                XCTFail("Failed to create expected date for day \(index)")
                continue
            }
            XCTAssertTrue(calendar.isDate(day.date, inSameDayAs: expectedDate), 
                         "Day \(index) should be \(index) days from today")
        }
    }
    
    func test_getMySchedule_returnsUserScheduleWithCorrectId() async throws {
        let repository = MockAvailabilityRepository()
        let schedule = try await repository.getMySchedule()
        
        XCTAssertEqual(schedule.id, "me_123")
        XCTAssertEqual(schedule.name, "User")
        XCTAssertNil(schedule.avatarURL)
    }
    
    func test_getMySchedule_simulatesNetworkDelay() async throws {
        let repository = MockAvailabilityRepository()
        let startTime = Date()
        
        _ = try await repository.getMySchedule()
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        XCTAssertGreaterThanOrEqual(elapsedTime, 0.4, "Should simulate at least 0.4 seconds delay")
        XCTAssertLessThan(elapsedTime, 1.0, "Should complete within reasonable time")
    }
    
    func test_updateMySchedule_updatesExistingDay() async throws {
        let repository = MockAvailabilityRepository()
        let schedule = try await repository.getMySchedule()
        let firstDay = schedule.weeklyStatus[0]
        
        var updatedDay = firstDay
        updatedDay.status = .free
        updatedDay.note = "Free for dinner"
        
        try await repository.updateMySchedule(for: updatedDay)
        
        let updatedSchedule = try await repository.getMySchedule()
        let foundDay = updatedSchedule.weeklyStatus.first { $0.id == firstDay.id }
        
        XCTAssertNotNil(foundDay)
        XCTAssertEqual(foundDay?.status, .free)
        XCTAssertEqual(foundDay?.note, "Free for dinner")
    }
    
    func test_updateMySchedule_simulatesNetworkDelay() async throws {
        let repository = MockAvailabilityRepository()
        let schedule = try await repository.getMySchedule()
        let day = schedule.weeklyStatus[0]
        var updatedDay = day
        updatedDay.status = .busy
        
        let startTime = Date()
        try await repository.updateMySchedule(for: updatedDay)
        let elapsedTime = Date().timeIntervalSince(startTime)
        
        XCTAssertGreaterThanOrEqual(elapsedTime, 0.2, "Should simulate at least 0.2 seconds delay")
        XCTAssertLessThan(elapsedTime, 0.6, "Should complete within reasonable time")
    }
    
    func test_updateMySchedule_doesNotUpdateNonExistentDay() async throws {
        let repository = MockAvailabilityRepository()
        guard let futureDate = Calendar.current.date(byAdding: .day, value: 10, to: Date()) else {
            XCTFail("Failed to create future date")
            return
        }
        let nonExistentDay = DayAvailability(date: futureDate, status: .free)
        
        // Should not throw, but also should not update anything
        try await repository.updateMySchedule(for: nonExistentDay)
        
        let schedule = try await repository.getMySchedule()
        let foundDay = schedule.weeklyStatus.first { $0.id == nonExistentDay.id }
        
        XCTAssertNil(foundDay, "Non-existent day should not be in schedule")
    }
    
    func test_getFriendsSchedules_returnsEmptyArray() async throws {
        let repository = MockAvailabilityRepository()
        let friends = try await repository.getFriendsSchedules()
        
        XCTAssertTrue(friends.isEmpty, "Mock repository should return empty array for friends")
    }
    
    func test_conformsToAvailabilityRepository() {
        let repository = MockAvailabilityRepository()
        
        // Verify it conforms to protocol by checking it can be assigned
        let repositoryProtocol: AvailabilityRepository = repository
        XCTAssertNotNil(repositoryProtocol)
    }
    
    @MainActor
    func test_memoryLeak_repositoryDoesNotLeak() {
        let repository = MockAvailabilityRepository()
        trackForMemoryLeaks(repository)
    }
    
    func test_multipleUpdates_persistCorrectly() async throws {
        let repository = MockAvailabilityRepository()
        let schedule = try await repository.getMySchedule()
        
        // Update first day
        var day1 = schedule.weeklyStatus[0]
        day1.status = .free
        try await repository.updateMySchedule(for: day1)
        
        // Update second day
        var day2 = schedule.weeklyStatus[1]
        day2.status = .busy
        try await repository.updateMySchedule(for: day2)
        
        // Verify both updates persisted
        let updatedSchedule = try await repository.getMySchedule()
        let foundDay1 = updatedSchedule.weeklyStatus.first { $0.id == day1.id }
        let foundDay2 = updatedSchedule.weeklyStatus.first { $0.id == day2.id }
        
        XCTAssertEqual(foundDay1?.status, .free)
        XCTAssertEqual(foundDay2?.status, .busy)
    }
}

