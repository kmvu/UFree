//
//  NudgeIntegrationTests.swift
//  UFreeIntegrationTests
//
//  Nudge lands in the recipient’s notifications inbox (rules + repository).
//

import XCTest
import FirebaseAuth
import FirebaseFirestore
@testable import UFree

@MainActor
final class NudgeIntegrationTests: XCTestCase {
    override func setUp() async throws {
        try requireIntegrationEnvironment()
        try await EmulatorHarness.resetEmulatorData()
    }

    func test_nudge_visibleInRecipientInbox() async throws {
        let friends = FirebaseFriendRepository()
        let notifications = FirebaseNotificationRepository()

        let aliceId = try await EmulatorHarness.signInUser(
            email: "alice-nudge@test.ufree",
            displayName: "Alice"
        )
        try await friends.saveUserProfile(displayName: "Alice", hashedPhoneNumbers: [])

        let bobId = try await EmulatorHarness.signInUser(
            email: "bob-nudge@test.ufree",
            displayName: "Bob"
        )
        try await friends.saveUserProfile(displayName: "Bob", hashedPhoneNumbers: [])

        // Friends required for nudge rules
        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(email: "alice-nudge@test.ufree", displayName: "Alice")
        let bobProfileOptional = try await friends.findUserById(bobId)
        let bobProfile = try XCTUnwrap(bobProfileOptional)
        try await friends.sendFriendRequest(to: bobProfile)

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(email: "bob-nudge@test.ufree", displayName: "Bob")
        let pendingOptional = try await friends.pendingFriendRequest(from: aliceId)
        let pending = try XCTUnwrap(pendingOptional)
        try await friends.acceptFriendRequest(pending)
        let bobFriends = try await friends.getMyFriends()
        XCTAssertTrue(bobFriends.contains(where: { $0.id == aliceId }))

        // Alice nudges Bob for tomorrow
        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(email: "alice-nudge@test.ufree", displayName: "Alice")
        let aliceFriends = try await friends.getMyFriends()
        XCTAssertTrue(
            aliceFriends.contains(where: { $0.id == bobId }),
            "Mutual friendship required for nudge rules"
        )
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        try await notifications.sendNudge(to: bobId, targetDate: tomorrow)

        // Bob reads his inbox via a point get (collection list + orderBy can flake under rules).
        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(email: "bob-nudge@test.ufree", displayName: "Bob")

        let snap = try await Firestore.firestore()
            .collection("users")
            .document(bobId)
            .collection("notifications")
            .getDocuments()
        let notes = snap.documents.compactMap { try? $0.data(as: AppNotification.self) }
        let nudge = try XCTUnwrap(notes.first { $0.type == .nudge && $0.senderId == aliceId })
        XCTAssertEqual(nudge.senderName, "Alice")
        XCTAssertEqual(nudge.targetDateString, AppNotification.dateString(from: tomorrow))
    }
}
