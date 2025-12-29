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
    
    private var spy: AvailabilityRepositorySpy!
    private var sut: UpdateMyStatusUseCase!
    
    override func setUp() async throws {
        try await super.setUp()
        spy = AvailabilityRepositorySpy()
        sut = UpdateMyStatusUseCase(repository: spy)
    }
    
    // MARK: - Core Functionality Tests
    
    func test_execute_callsRepositoryAndPassesDay() async throws {
        let day = DayAvailability(date: Date(), status: .free)
        
        try await sut.execute(day: day)
        
        XCTAssertEqual(spy.updateCallCount, 1)
        XCTAssertEqual(spy.updatedDay?.id, day.id)
        XCTAssertEqual(spy.updatedDay?.status, day.status)
    }
    
    // MARK: - Date Validation Tests
    
    func test_execute_rejectsPastDates() async {
        guard let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else {
            XCTFail("Could not create past date")
            return
        }
        let pastDay = DayAvailability(date: pastDate, status: .free)
        
        do {
            try await sut.execute(day: pastDay)
            XCTFail("Should reject past dates")
        } catch UpdateMyStatusUseCaseError.cannotUpdatePastDate {
            XCTAssertEqual(spy.updateCallCount, 0, "Should not call repository for past dates")
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
    
    func test_execute_acceptsTodayAndFutureDates() async throws {
        let today = Calendar.current.startOfDay(for: Date())
        let todayDay = DayAvailability(date: today, status: .busy)
        
        try await sut.execute(day: todayDay)
        XCTAssertEqual(spy.updateCallCount, 1)
        
        spy.reset()
        
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else {
            XCTFail("Could not create future date")
            return
        }
        let tomorrowDay = DayAvailability(date: tomorrow, status: .eveningOnly)
        
        try await sut.execute(day: tomorrowDay)
        XCTAssertEqual(spy.updateCallCount, 1)
    }
    
    // MARK: - Error Handling Tests
    
    func test_execute_propagatesRepositoryErrors() async {
        spy.shouldThrowError = true
        let day = DayAvailability(date: Date(), status: .free)
        
        do {
            try await sut.execute(day: day)
            XCTFail("Should propagate repository error")
        } catch {
            XCTAssertEqual(spy.updateCallCount, 1)
        }
    }
    
    // MARK: - Test Helpers
    
    /// Test spy for AvailabilityRepository
    /// Uses a class (not actor) because:
    /// - Test mocks don't need concurrent safety (tests run sequentially)
    /// - Easier property access from test assertions
    /// - No risk of actual concurrent access in test environment
    private final class AvailabilityRepositorySpy: AvailabilityRepository {
        private(set) var updateCallCount = 0
        private(set) var updatedDay: DayAvailability?
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
        
        func reset() {
            updateCallCount = 0
            updatedDay = nil
        }
    }
}
