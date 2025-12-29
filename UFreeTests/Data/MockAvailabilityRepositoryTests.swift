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
    
    private var repository: MockAvailabilityRepository!
    
    override func setUp() async throws {
        try await super.setUp()
        repository = MockAvailabilityRepository()
    }
    
    // MARK: - Initial State Tests
    
    func test_getMySchedule_returnsSeven_Days_WithUnknownStatusByDefault() async throws {
        let schedule = try await repository.getMySchedule()
        
        XCTAssertEqual(schedule.weeklyStatus.count, 7)
        XCTAssertTrue(schedule.weeklyStatus.allSatisfy { $0.status == .unknown })
        XCTAssertEqual(schedule.id, "me_123")
        XCTAssertEqual(schedule.name, "User")
    }
    
    func test_getMySchedule_generatesConsecutiveDaysFromToday() async throws {
        let schedule = try await repository.getMySchedule()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for (index, day) in schedule.weeklyStatus.enumerated() {
            guard let expectedDate = calendar.date(byAdding: .day, value: index, to: today) else {
                XCTFail("Could not create expected date for day \(index)")
                return
            }
            XCTAssertTrue(
                calendar.isDate(day.date, inSameDayAs: expectedDate),
                "Day \(index) should be \(index) days from today"
            )
        }
    }
    
    // MARK: - Update Tests
    
    func test_updateMySchedule_persistsStatusChanges() async throws {
        let initialSchedule = try await repository.getMySchedule()
        let firstDay = initialSchedule.weeklyStatus[0]
        
        var updatedDay = firstDay
        updatedDay.status = .free
        updatedDay.note = "Available for lunch"
        
        try await repository.updateMySchedule(for: updatedDay)
        
        let retrievedSchedule = try await repository.getMySchedule()
        let foundDay = retrievedSchedule.weeklyStatus.first { $0.id == firstDay.id }
        
        XCTAssertEqual(foundDay?.status, .free)
        XCTAssertEqual(foundDay?.note, "Available for lunch")
    }
    
    func test_updateMySchedule_handlesMultipleUpdates() async throws {
        let schedule = try await repository.getMySchedule()
        
        var day1 = schedule.weeklyStatus[0]
        day1.status = .free
        try await repository.updateMySchedule(for: day1)
        
        var day2 = schedule.weeklyStatus[1]
        day2.status = .busy
        try await repository.updateMySchedule(for: day2)
        
        let updated = try await repository.getMySchedule()
        XCTAssertEqual(updated.weeklyStatus[0].status, .free)
        XCTAssertEqual(updated.weeklyStatus[1].status, .busy)
    }
    
    // MARK: - Protocol Conformance Tests
    
    func test_getFriendsSchedules_returnsEmptyArray() async throws {
        let friends = try await repository.getFriendsSchedules()
        XCTAssertTrue(friends.isEmpty)
    }
    
    func test_conformsToAvailabilityRepository() {
        let proto: AvailabilityRepository = repository
        XCTAssertNotNil(proto)
    }
    
    // MARK: - Cleanup Tests
    
    func test_actorProperlyDeallocates() {
        var repo: MockAvailabilityRepository? = MockAvailabilityRepository()
        weak var weakRef = repo
        
        repo = nil
        XCTAssertNil(weakRef, "Actor should be deallocated")
    }
}
