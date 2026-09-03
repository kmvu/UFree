//
//  HandshakeIntegrationTests.swift
//  UFreeIntegrationTests
//
//  Full friend handshake against Auth + Firestore emulators + production rules.
//

import XCTest
import FirebaseAuth
@testable import UFree

@MainActor
final class HandshakeIntegrationTests: XCTestCase {
    override func setUp() async throws {
        try requireIntegrationEnvironment()
        try await EmulatorHarness.resetEmulatorData()
    }

    func test_handshake_sendAccept_bothFriendIdsUpdated() async throws {
        let friends = FirebaseFriendRepository()

        let aliceId = try await EmulatorHarness.signInUser(
            email: "alice-handshake@test.ufree",
            displayName: "Alice"
        )
        try await friends.saveUserProfile(displayName: "Alice", hashedPhoneNumbers: [])

        let bobId = try await EmulatorHarness.signInUser(
            email: "bob-handshake@test.ufree",
            displayName: "Bob"
        )
        try await friends.saveUserProfile(displayName: "Bob", hashedPhoneNumbers: [])

        // Alice invites Bob
        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(
            email: "alice-handshake@test.ufree",
            displayName: "Alice"
        )
        let bobProfileOptional = try await friends.findUserById(bobId)
        let bobProfile = try XCTUnwrap(bobProfileOptional)
        try await friends.sendFriendRequest(to: bobProfile)

        // Bob accepts
        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(
            email: "bob-handshake@test.ufree",
            displayName: "Bob"
        )
        let pendingOptional = try await friends.pendingFriendRequest(from: aliceId)
        let pending = try XCTUnwrap(pendingOptional)
        try await friends.acceptFriendRequest(pending)

        let bobFriends = try await friends.getMyFriends()
        XCTAssertTrue(bobFriends.contains(where: { $0.id == aliceId }), "Bob should list Alice")

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(
            email: "alice-handshake@test.ufree",
            displayName: "Alice"
        )
        let aliceFriends = try await friends.getMyFriends()
        XCTAssertTrue(aliceFriends.contains(where: { $0.id == bobId }), "Alice should list Bob")
    }
}
