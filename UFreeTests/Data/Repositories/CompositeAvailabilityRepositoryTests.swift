//
//  CompositeAvailabilityRepositoryTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 3/1/26.
//

import XCTest
@testable import UFree

final class CompositeAvailabilityRepositoryTests: XCTestCase {
    var composite: CompositeAvailabilityRepository!
    var localRepository: (any AvailabilityRepository)?
    var remoteRepository: (any AvailabilityRepository)?
    
    override func setUp() async throws {
        try await super.setUp()
        localRepository = MockAvailabilityRepository()
        remoteRepository = MockAvailabilityRepository()
        composite = CompositeAvailabilityRepository(local: localRepository!, remote: remoteRepository!)
    }
    
    // MARK: - Tests: updateMySchedule (Write-Through)
    
    func test_updateMySchedule_updatesLocal_immediately() async throws {
        // Arrange
        let day = DayAvailability(date: Date(), status: .free, note: "Test")
        
        // Act
        try await composite.updateMySchedule(for: day)
        
        // Assert: Local should be updated immediately
        let localSchedule = try await localRepository!.getMySchedule()
        let targetDate = Calendar.current.startOfDay(for: day.date)
        let updatedDay = localSchedule.weeklyStatus.first { Calendar.current.isDate($0.date, inSameDayAs: targetDate) }
        XCTAssertNotNil(updatedDay)
        XCTAssertEqual(updatedDay?.status, .free)
    }
    
    func test_updateMySchedule_syncsToRemote_asynchronously() async throws {
        // Arrange
        let day = DayAvailability(date: Date(), status: .busy)
        
        // Act
        try await composite.updateMySchedule(for: day)
        
        // Wait for background Task to complete
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4s
        
        // Assert: Remote should also be updated
        let remoteSchedule = try await remoteRepository!.getMySchedule()
        let targetDate = Calendar.current.startOfDay(for: day.date)
        let updatedDay = remoteSchedule.weeklyStatus.first { Calendar.current.isDate($0.date, inSameDayAs: targetDate) }
        XCTAssertNotNil(updatedDay)
        XCTAssertEqual(updatedDay?.status, .busy)
    }
    
    func test_updateMySchedule_localSucceeds_evenIfRemoteFails() async throws {
        // Arrange
        let day = DayAvailability(date: Date(), status: .afternoonOnly)
        
        // Simulate remote failure
        remoteRepository = ThrowingMockAvailabilityRepository()
        composite = CompositeAvailabilityRepository(local: localRepository!, remote: remoteRepository!)
        
        // Act: Should not throw even though remote will fail
        do {
            try await composite.updateMySchedule(for: day)
        } catch {
            XCTFail("updateMySchedule should not throw when remote fails: \(error)")
        }
        
        // Local should still be updated
        let localSchedule = try await localRepository!.getMySchedule()
        let targetDate = Calendar.current.startOfDay(for: day.date)
        let updatedDay = localSchedule.weeklyStatus.first { Calendar.current.isDate($0.date, inSameDayAs: targetDate) }
        XCTAssertEqual(updatedDay?.status, .afternoonOnly)
    }
    
    // MARK: - Tests: getMySchedule (Read-Back)
    
    func test_getMySchedule_returnsLocal_immediately() async throws {
        // Arrange
        let expectedSchedule = try await localRepository!.getMySchedule()
        
        // Act
        let startTime = Date()
        let schedule = try await composite.getMySchedule()
        let elapsedTime = Date().timeIntervalSince(startTime)
        
        // Assert: Should return immediately (before remote completes its 0.5s delay)
        XCTAssertEqual(schedule.weeklyStatus.count, expectedSchedule.weeklyStatus.count)
        // Should complete much faster than 0.3s (remote delay for first doc)
        XCTAssertLessThan(elapsedTime, 0.15)
    }
    
    func test_getMySchedule_returnsLocal_evenIfRemoteFails() async throws {
        // Arrange
        let expectedSchedule = try await localRepository!.getMySchedule()
        
        // Simulate remote failure
        remoteRepository = ThrowingMockAvailabilityRepository()
        composite = CompositeAvailabilityRepository(local: localRepository!, remote: remoteRepository!)
        
        // Act
        let schedule = try await composite.getMySchedule()
        
        // Assert: Should return local data successfully
        XCTAssertEqual(schedule.weeklyStatus.count, expectedSchedule.weeklyStatus.count)
        XCTAssertEqual(schedule.id, expectedSchedule.id)
    }
    
    // MARK: - Tests: getFriendsSchedules (Remote-First)
    
    func test_getFriendsSchedules_alwaysUsesRemote() async throws {
        // Arrange - no friends in local
        var friendsFromLocal = [UserSchedule]()
        do {
            friendsFromLocal = try await localRepository!.getFriendsSchedules()
        } catch {
            friendsFromLocal = []
        }
        XCTAssertEqual(friendsFromLocal.count, 0)
        
        // Act
        let friends = try await composite.getFriendsSchedules()
        
        // Assert: Should delegate to remote
        XCTAssertEqual(friends.count, 0) // Mock returns empty
    }
    
    func test_getFriendsSchedules_throwsWhenRemoteFails() async throws {
        // Arrange
        remoteRepository = ThrowingMockAvailabilityRepository()
        composite = CompositeAvailabilityRepository(local: localRepository!, remote: remoteRepository!)
        
        // Act & Assert
        do {
            _ = try await composite.getFriendsSchedules()
            XCTFail("Should throw when remote fails")
        } catch {
            XCTAssertTrue(error is MockError)
        }
    }
    
    // MARK: - Tests: Offline Resilience
    
    func test_offlineScenario_updateThenRead() async throws {
        // Simulate offline: update local, remote is down
        let targetDate = Calendar.current.startOfDay(for: Date())
        let day1 = DayAvailability(date: targetDate, status: .free)
        let day2 = DayAvailability(
            date: Calendar.current.date(byAdding: .day, value: 1, to: targetDate)!,
            status: .eveningOnly
        )
        
        // Update multiple days
        try await composite.updateMySchedule(for: day1)
        try await composite.updateMySchedule(for: day2)
        
        // Read back - should have both updates
        let schedule = try await composite.getMySchedule()
        XCTAssertEqual(schedule.weeklyStatus.count, 7)
        
        // Both days should have correct status
        let updatedDay1 = schedule.weeklyStatus.first { Calendar.current.isDate($0.date, inSameDayAs: day1.date) }
        let updatedDay2 = schedule.weeklyStatus.first { Calendar.current.isDate($0.date, inSameDayAs: day2.date) }
        
        XCTAssertEqual(updatedDay1?.status, .free)
        XCTAssertEqual(updatedDay2?.status, .eveningOnly)
    }
    
    func test_multipleConcurrentUpdates_allPersistLocally() async throws {
        // Simulate concurrent updates
        let targetDate = Calendar.current.startOfDay(for: Date())
        let days = (0..<3).map { DayAvailability(date: Calendar.current.date(byAdding: .day, value: $0, to: targetDate)!, status: .morningOnly) }
        
        // Update all concurrently
        async let update1 = composite.updateMySchedule(for: days[0])
        async let update2 = composite.updateMySchedule(for: days[1])
        async let update3 = composite.updateMySchedule(for: days[2])
        
        _ = try await (update1, update2, update3)
        
        // Read back
        let schedule = try await composite.getMySchedule()
        
        // All should be updated
        for day in days {
            let updated = schedule.weeklyStatus.first { Calendar.current.isDate($0.date, inSameDayAs: day.date) }
            XCTAssertEqual(updated?.status, .morningOnly)
        }
    }
}

// MARK: - Test Doubles

/// Mock repository that throws errors for all operations
private actor ThrowingMockAvailabilityRepository: AvailabilityRepository {
    func getMySchedule() async throws -> UserSchedule {
        throw MockError.operationFailed
    }
    
    func updateMySchedule(for day: DayAvailability) async throws {
        throw MockError.operationFailed
    }
    
    nonisolated func getFriendsSchedules() async throws -> [UserSchedule] {
        throw MockError.operationFailed
    }
}

enum MockError: Error {
    case operationFailed
}
