//
//  FirebaseAvailabilityRepositoryTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 07/01/26.
//

import XCTest
@testable import UFree

final class FirebaseAvailabilityRepositoryTests: XCTestCase {

    // MARK: - Unit Tests (Mock-based, no Firestore emulator needed)

    func test_getSchedules_emptyList_returnsEmpty() async throws {
        let repo = MockAvailabilityRepository()
        
        let result = try await repo.getSchedules(for: [])
        
        XCTAssertEqual(result.count, 0)
    }

    func test_getSchedules_singleFriend_returnsSchedule() async throws {
        let repo = MockAvailabilityRepository()
        let today = Date()
        
        // Add a mock friend schedule
        let schedule = UserSchedule(
            id: "friend1",
            name: "Alice",
            avatarURL: nil,
            weeklyStatus: [
                DayAvailability(date: today, status: .free),
                DayAvailability(date: Calendar.current.date(byAdding: .day, value: 1, to: today)!, status: .busy)
            ]
        )
        await repo.addFriendSchedule(schedule)
        
        let result = try await repo.getSchedules(for: ["friend1"])
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, "friend1")
        XCTAssertEqual(result[0].weeklyStatus.count, 2)
    }

    func test_getSchedules_multipleFriends_returnsAllSchedules() async throws {
        let repo = MockAvailabilityRepository()
        let today = Date()
        
        // Add mock schedules for multiple friends
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
        
        await repo.addFriendSchedule(schedule1)
        await repo.addFriendSchedule(schedule2)
        await repo.addFriendSchedule(schedule3)
        
        let result = try await repo.getSchedules(for: ["friend1", "friend2", "friend3"])
        
        XCTAssertEqual(result.count, 3)
        let ids = Set(result.map { $0.id })
        XCTAssertEqual(ids, ["friend1", "friend2", "friend3"])
    }

    func test_getSchedules_partialMatch_returnsOnlyFound() async throws {
        let repo = MockAvailabilityRepository()
        let today = Date()
        
        // Only add schedule for friend1, not friend2
        let schedule1 = UserSchedule(
            id: "friend1",
            name: "Alice",
            avatarURL: nil,
            weeklyStatus: [DayAvailability(date: today, status: .free)]
        )
        await repo.addFriendSchedule(schedule1)
        
        let result = try await repo.getSchedules(for: ["friend1", "friend2"])
        
        // Should only return friend1 since friend2 has no schedule
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, "friend1")
    }

    func test_getSchedules_largeList_handlesBatching() async throws {
        let repo = MockAvailabilityRepository()
        let today = Date()
        
        // Add schedules for 25 friends (tests chunking at 10)
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
            await repo.addFriendSchedule(schedule)
        }
        
        let result = try await repo.getSchedules(for: friendIds)
        
        XCTAssertEqual(result.count, 25)
        let resultIds = Set(result.map { $0.id })
        XCTAssertEqual(resultIds.count, 25)
    }

    func test_getSchedules_withDataGaps_preservesOnlyFetchedData() async throws {
        let repo = MockAvailabilityRepository()
        let today = Date()
        
        // Add schedule with only 2 days (not full week)
        let schedule = UserSchedule(
            id: "friend1",
            name: "Alice",
            avatarURL: nil,
            weeklyStatus: [
                DayAvailability(date: today, status: .free),
                DayAvailability(date: Calendar.current.date(byAdding: .day, value: 1, to: today)!, status: .busy)
            ]
        )
        await repo.addFriendSchedule(schedule)
        
        let result = try await repo.getSchedules(for: ["friend1"])
        
        XCTAssertEqual(result.count, 1)
        // Should preserve the exact data without filling gaps
        XCTAssertEqual(result[0].weeklyStatus.count, 2)
    }

    // MARK: - Note: Integration tests with Firebase emulator
    // These would require running: firebase emulators:start --only firestore
    // For now, we use the mock repository for unit testing.
    //
    // Integration tests would test:
    // - Actual Firestore document structure
    // - Date string formatting (YYYY-MM-DD)
    // - Subcollection queries
    // - Network failure scenarios
}
