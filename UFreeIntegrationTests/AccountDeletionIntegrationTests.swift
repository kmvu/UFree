//
//  AccountDeletionIntegrationTests.swift
//  UFreeIntegrationTests
//
//  Account wipe must clear the deleted UID from peers' friendIds.
//

import XCTest
import FirebaseAuth
import FirebaseFirestore
@testable import UFree

@MainActor
final class AccountDeletionIntegrationTests: XCTestCase {
    override func setUp() async throws {
        try requireIntegrationEnvironment()
        try await EmulatorHarness.resetEmulatorData()
    }

    func test_deleteAccountData_removesSelfFromPeersFriendIds() async throws {
        let friends = FirebaseFriendRepository()

        let aliceId = try await EmulatorHarness.signInUser(
            email: "alice-delete@test.ufree",
            displayName: "Alice"
        )
        try await friends.saveUserProfile(displayName: "Alice", hashedPhoneNumbers: [])

        let bobId = try await EmulatorHarness.signInUser(
            email: "bob-delete@test.ufree",
            displayName: "Bob"
        )
        try await friends.saveUserProfile(displayName: "Bob", hashedPhoneNumbers: [])

        // Alice invites Bob; Bob accepts.
        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(
            email: "alice-delete@test.ufree",
            displayName: "Alice"
        )
        let bobOptional = try await friends.findUserById(bobId)
        let bobProfile = try XCTUnwrap(bobOptional)
        try await friends.sendFriendRequest(to: bobProfile)

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(
            email: "bob-delete@test.ufree",
            displayName: "Bob"
        )
        let pendingOptional = try await friends.pendingFriendRequest(from: aliceId)
        let pending = try XCTUnwrap(pendingOptional)
        try await friends.acceptFriendRequest(pending)

        var bobFriends = try await friends.getMyFriends()
        XCTAssertTrue(bobFriends.contains(where: { $0.id == aliceId }))

        // Alice deletes her Firestore tree (friend-graph cleanup included).
        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(
            email: "alice-delete@test.ufree",
            displayName: "Alice"
        )
        try await friends.deleteAccountData()

        // Bob should no longer list Alice.
        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(
            email: "bob-delete@test.ufree",
            displayName: "Bob"
        )
        bobFriends = try await friends.getMyFriends()
        XCTAssertFalse(
            bobFriends.contains(where: { $0.id == aliceId }),
            "Deleted UID must be removed from peers' friendIds"
        )

        let bobSnap = try await Firestore.firestore().collection("users").document(bobId).getDocument()
        let bobFriendIds = bobSnap.data()?["friendIds"] as? [String] ?? []
        XCTAssertFalse(bobFriendIds.contains(aliceId))

        // Missing users/{uid} has null `resource`, so friend get rules deny.
        // Only the owner path (`isOwner`) can probe that the wipe succeeded.
        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(
            email: "alice-delete@test.ufree",
            displayName: "Alice"
        )
        let aliceSnap = try await Firestore.firestore().collection("users").document(aliceId).getDocument()
        XCTAssertFalse(aliceSnap.exists, "Alice users doc should be gone")
    }

    func test_deleteAccountData_removesAvailabilityNotificationsRequestsAndDiscovery() async throws {
        let friends = FirebaseFriendRepository()
        let availability = FirebaseAvailabilityRepository()
        let notifications = FirebaseNotificationRepository()
        let aliceHashes = CryptoUtils.phoneNumberHashes(for: "+15557654321")
        let hash = try XCTUnwrap(aliceHashes.first)

        let (aliceId, bobId) = try await EmulatorHarness.connectAliceToBob(
            aliceEmail: "alice-cascade@test.ufree",
            bobEmail: "bob-cascade@test.ufree",
            aliceHashes: aliceHashes
        )

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(
            email: "alice-cascade@test.ufree",
            displayName: "Alice"
        )
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        try await availability.updateMySchedule(for: DayAvailability(date: tomorrow, status: .free))

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(
            email: "bob-cascade@test.ufree",
            displayName: "Bob"
        )
        try await notifications.sendNudge(to: aliceId, targetDate: tomorrow)

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(
            email: "alice-cascade@test.ufree",
            displayName: "Alice"
        )
        try await friends.deleteAccountData()

        let db = Firestore.firestore()
        let usersSnap = try await db.collection("users").document(aliceId).getDocument()
        XCTAssertFalse(usersSnap.exists)

        let availabilitySnap = try await db.collection("users").document(aliceId)
            .collection("availability").getDocuments()
        XCTAssertTrue(availabilitySnap.documents.isEmpty)

        let notesSnap = try await db.collection("users").document(aliceId)
            .collection("notifications").getDocuments()
        XCTAssertTrue(notesSnap.documents.isEmpty)

        let requestId = FriendRequest.documentId(fromId: aliceId, toId: bobId)
        // Missing friendRequests docs evaluate `resource.data` as null, so get is
        // denied (PERMISSION_DENIED) rather than returning exists=false.
        do {
            let requestSnap = try await db.collection("friendRequests").document(requestId).getDocument()
            XCTAssertFalse(requestSnap.exists)
        } catch {
            XCTAssertEqual((error as NSError).code, FirestoreErrorCode.permissionDenied.rawValue)
        }

        let profileSnap = try await db.collection("publicProfiles").document(aliceId).getDocument()
        XCTAssertFalse(profileSnap.exists)

        let directorySnap = try await db.collection("phoneDirectory").document(hash).getDocument()
        XCTAssertFalse(directorySnap.exists)
    }
}
