//
//  UpdateMyStatusUseCaseTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 22/12/25.
//

import XCTest
import Foundation
@testable import UFree

final class UpdateMyStatusUseCaseTests: XCTestCase {
    
    func test_init_createsUseCaseWithRepository() {
        let repository = MockAvailabilityRepository()
        let sut = UpdateMyStatusUseCase(repository: repository)
        
        XCTAssertNotNil(sut)
    }
    
    func test_execute_callsRepositoryUpdateMySchedule() async throws {
        let repository = AvailabilityRepositorySpy()
        let sut = UpdateMyStatusUseCase(repository: repository)
        let day = DayAvailability(date: Date(), status: .free)
        
        try await sut.execute(day: day)
        
        XCTAssertEqual(repository.updateCallCount, 1)
        XCTAssertEqual(repository.updatedDay?.id, day.id)
        XCTAssertEqual(repository.updatedDay?.status, day.status)
    }
    
    func test_execute_withPastDate_throwsError() async {
        let repository = AvailabilityRepositorySpy()
        let sut = UpdateMyStatusUseCase(repository: repository)
        
        // Create a date in the past
        guard let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else {
            XCTFail("Failed to create past date")
            return
        }
        let pastDay = DayAvailability(date: pastDate, status: .free)
        
        do {
            try await sut.execute(day: pastDay)
            XCTFail("Expected error for past date")
        } catch UpdateMyStatusUseCaseError.cannotUpdatePastDate {
            // Expected error
            XCTAssertEqual(repository.updateCallCount, 0, "Repository should not be called for past dates")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_execute_withTodayDate_succeeds() async throws {
        let repository = AvailabilityRepositorySpy()
        let sut = UpdateMyStatusUseCase(repository: repository)
        let today = Calendar.current.startOfDay(for: Date())
        let todayDay = DayAvailability(date: today, status: .busy)
        
        try await sut.execute(day: todayDay)
        
        XCTAssertEqual(repository.updateCallCount, 1)
    }
    
    func test_execute_withFutureDate_succeeds() async throws {
        let repository = AvailabilityRepositorySpy()
        let sut = UpdateMyStatusUseCase(repository: repository)
        guard let futureDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else {
            XCTFail("Failed to create future date")
            return
        }
        let futureDay = DayAvailability(date: futureDate, status: .eveningOnly)
        
        try await sut.execute(day: futureDay)
        
        XCTAssertEqual(repository.updateCallCount, 1)
    }
    
    func test_execute_propagatesRepositoryError() async {
        let repository = AvailabilityRepositorySpy()
        repository.shouldThrowError = true
        let sut = UpdateMyStatusUseCase(repository: repository)
        let day = DayAvailability(date: Date(), status: .free)
        
        do {
            try await sut.execute(day: day)
            XCTFail("Expected error from repository")
        } catch {
            XCTAssertEqual(repository.updateCallCount, 1, "Repository should still be called")
        }
    }
    
    // MARK: - Helpers
    
    private class AvailabilityRepositorySpy: AvailabilityRepository {
        var updateCallCount = 0
        var updatedDay: DayAvailability?
        var shouldThrowError = false
        
        func getFriendsSchedules() async throws -> [UserSchedule] {
            return []
        }
        
        func updateMySchedule(for day: DayAvailability) async throws {
            updateCallCount += 1
            updatedDay = day
            
            if shouldThrowError {
                throw NSError(domain: "test", code: 1)
            }
        }
        
        func getMySchedule() async throws -> UserSchedule {
            return UserSchedule(id: "test", name: "Test", weeklyStatus: [])
        }
    }
}
