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

    func test_nudgeReply_visibleInSenderInbox() async throws {
        let friends = FirebaseFriendRepository()
        let notifications = FirebaseNotificationRepository()
        let (aliceId, bobId) = try await EmulatorHarness.connectAliceToBob(
            aliceEmail: "alice-reply@test.ufree",
            bobEmail: "bob-reply@test.ufree"
        )

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(
            email: "alice-reply@test.ufree",
            displayName: "Alice"
        )
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        try await notifications.sendNudge(to: bobId, targetDate: tomorrow)

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(
            email: "bob-reply@test.ufree",
            displayName: "Bob"
        )
        try await notifications.sendNudgeReply(
            to: aliceId,
            targetDateString: AppNotification.dateString(from: tomorrow),
            response: .imIn
        )

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(
            email: "alice-reply@test.ufree",
            displayName: "Alice"
        )
        let snap = try await Firestore.firestore()
            .collection("users")
            .document(aliceId)
            .collection("notifications")
            .getDocuments()
        let notes = snap.documents.compactMap { try? $0.data(as: AppNotification.self) }
        let reply = notes.first { $0.type == .nudgeReply && $0.senderId == bobId }
        XCTAssertNotNil(
            reply,
            "Expected Bob's nudgeReply in Alice's inbox; decoded \(notes.map(\.type)) from \(snap.documents.count) docs"
        )
        let replyNote = try XCTUnwrap(reply)
        XCTAssertEqual(replyNote.nudgeResponse, AppNotification.NudgeResponse.imIn.rawValue)
        XCTAssertEqual(replyNote.targetDateString, AppNotification.dateString(from: tomorrow))
    }

    func test_listenToNotifications_emitsNudge() async throws {
        let notifications = FirebaseNotificationRepository()
        let (_, bobId) = try await EmulatorHarness.connectAliceToBob(
            aliceEmail: "alice-nlisten@test.ufree",
            bobEmail: "bob-nlisten@test.ufree"
        )

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(
            email: "alice-nlisten@test.ufree",
            displayName: "Alice"
        )
        try await notifications.sendNudge(to: bobId, targetDate: Date())

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(
            email: "bob-nlisten@test.ufree",
            displayName: "Bob"
        )
        let inbox = try await firstMatching(of: notifications.listenToNotifications()) { notes in
            notes.contains(where: { $0.type == .nudge && $0.senderName == "Alice" })
        }
        XCTAssertFalse(inbox.isEmpty)
    }
}
