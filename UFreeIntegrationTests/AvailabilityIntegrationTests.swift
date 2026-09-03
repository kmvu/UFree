//
//  AvailabilityIntegrationTests.swift
//  UFreeIntegrationTests
//
//  Friend-gated availability: writer’s free day is visible to an accepted friend.
//

import XCTest
import FirebaseAuth
@testable import UFree

@MainActor
final class AvailabilityIntegrationTests: XCTestCase {
    override func setUp() async throws {
        try requireIntegrationEnvironment()
        try await EmulatorHarness.resetEmulatorData()
    }

    func test_availability_writeVisibleToFriend() async throws {
        let friends = FirebaseFriendRepository()
        let availability = FirebaseAvailabilityRepository()

        let aliceId = try await EmulatorHarness.signInUser(
            email: "alice-avail@test.ufree",
            displayName: "Alice"
        )
        try await friends.saveUserProfile(displayName: "Alice", hashedPhoneNumbers: [])

        let bobId = try await EmulatorHarness.signInUser(
            email: "bob-avail@test.ufree",
            displayName: "Bob"
        )
        try await friends.saveUserProfile(displayName: "Bob", hashedPhoneNumbers: [])

        // Connect Alice ↔ Bob
        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(email: "alice-avail@test.ufree", displayName: "Alice")
        let bobProfileOptional = try await friends.findUserById(bobId)
        let bobProfile = try XCTUnwrap(bobProfileOptional)
        try await friends.sendFriendRequest(to: bobProfile)

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(email: "bob-avail@test.ufree", displayName: "Bob")
        let pendingOptional = try await friends.pendingFriendRequest(from: aliceId)
        let pending = try XCTUnwrap(pendingOptional)
        try await friends.acceptFriendRequest(pending)

        // Alice marks tomorrow free
        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(email: "alice-avail@test.ufree", displayName: "Alice")
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        var day = DayAvailability(date: tomorrow, status: .free)
        day.note = "integration"
        try await availability.updateMySchedule(for: day)

        // Bob can read Alice’s schedule
        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(email: "bob-avail@test.ufree", displayName: "Bob")
        let schedules = try await availability.getSchedules(for: [aliceId])
        let aliceSchedule = try XCTUnwrap(schedules.first)
        let targetKey = DateFormatter.yyyyMMdd.string(from: tomorrow)
        let matching = aliceSchedule.weeklyStatus.first {
            DateFormatter.yyyyMMdd.string(from: $0.date) == targetKey
        }
        XCTAssertEqual(matching?.overallStatus, .free)
    }
}
