//
//  HandshakeIntegrationTests.swift
//  UFreeIntegrationTests
//
//  Full friend handshake against Auth + Firestore emulators + production rules.
//

import XCTest
import FirebaseAuth
import FirebaseFirestore
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

    func test_handshake_declineThenReinviteAfterDelete() async throws {
        let friends = FirebaseFriendRepository()
        let aliceId = try await EmulatorHarness.signInUser(
            email: "alice-decline@test.ufree",
            displayName: "Alice"
        )
        try await friends.saveUserProfile(displayName: "Alice", hashedPhoneNumbers: [])

        let bobId = try await EmulatorHarness.signInUser(
            email: "bob-decline@test.ufree",
            displayName: "Bob"
        )
        try await friends.saveUserProfile(displayName: "Bob", hashedPhoneNumbers: [])

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(
            email: "alice-decline@test.ufree",
            displayName: "Alice"
        )
        let bobProfileOptional = try await friends.findUserById(bobId)
        let bobProfile = try XCTUnwrap(bobProfileOptional)
        try await friends.sendFriendRequest(to: bobProfile)

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(
            email: "bob-decline@test.ufree",
            displayName: "Bob"
        )
        let pendingOptional = try await friends.pendingFriendRequest(from: aliceId)
        let pending = try XCTUnwrap(pendingOptional)
        try await friends.declineFriendRequest(pending)

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(
            email: "alice-decline@test.ufree",
            displayName: "Alice"
        )
        do {
            try await friends.sendFriendRequest(to: bobProfile)
            XCTFail("Re-send on a declined deterministic id should be denied")
        } catch {
            // Expected — rules freeze the declined document.
        }

        let requestId = FriendRequest.documentId(fromId: aliceId, toId: bobId)
        try await Firestore.firestore().collection("friendRequests").document(requestId).delete()
        try await friends.sendFriendRequest(to: bobProfile)

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(
            email: "bob-decline@test.ufree",
            displayName: "Bob"
        )
        let reinvited = try await friends.pendingFriendRequest(from: aliceId)
        XCTAssertEqual(reinvited?.status, .pending)
        XCTAssertEqual(reinvited?.fromId, aliceId)
    }

    func test_removeFriend_clearsBothFriendIds() async throws {
        let friends = FirebaseFriendRepository()
        let (aliceId, bobId) = try await EmulatorHarness.connectAliceToBob(
            aliceEmail: "alice-unfriend@test.ufree",
            bobEmail: "bob-unfriend@test.ufree"
        )

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(
            email: "alice-unfriend@test.ufree",
            displayName: "Alice"
        )
        try await friends.removeFriend(userId: bobId)

        let aliceFriends = try await friends.getMyFriends()
        XCTAssertFalse(aliceFriends.contains(where: { $0.id == bobId }))

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(
            email: "bob-unfriend@test.ufree",
            displayName: "Bob"
        )
        let bobFriends = try await friends.getMyFriends()
        XCTAssertFalse(bobFriends.contains(where: { $0.id == aliceId }))
    }

    func test_acceptFriendRequest_nonRecipient_fails() async throws {
        let friends = FirebaseFriendRepository()
        let aliceId = try await EmulatorHarness.signInUser(
            email: "alice-forge@test.ufree",
            displayName: "Alice"
        )
        try await friends.saveUserProfile(displayName: "Alice", hashedPhoneNumbers: [])

        let bobId = try await EmulatorHarness.signInUser(
            email: "bob-forge@test.ufree",
            displayName: "Bob"
        )
        try await friends.saveUserProfile(displayName: "Bob", hashedPhoneNumbers: [])

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(
            email: "alice-forge@test.ufree",
            displayName: "Alice"
        )
        let forgeBobOptional = try await friends.findUserById(bobId)
        let bobProfile = try XCTUnwrap(forgeBobOptional)
        try await friends.sendFriendRequest(to: bobProfile)

        let forged = FriendRequest(
            id: FriendRequest.documentId(fromId: aliceId, toId: bobId),
            fromId: aliceId,
            fromName: "Alice",
            toId: bobId,
            status: .pending,
            timestamp: Date()
        )
        do {
            try await friends.acceptFriendRequest(forged)
            XCTFail("Sender must not accept their own request")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.code, 403)
        }
    }

    func test_acceptFriendRequest_alreadyAccepted_fails() async throws {
        let friends = FirebaseFriendRepository()
        let (aliceId, bobId) = try await EmulatorHarness.connectAliceToBob(
            aliceEmail: "alice-twice@test.ufree",
            bobEmail: "bob-twice@test.ufree"
        )

        let requestId = FriendRequest.documentId(fromId: aliceId, toId: bobId)
        let acceptedOptional = try await friends.fetchFriendRequest(id: requestId)
        let accepted = try XCTUnwrap(acceptedOptional)
        do {
            try await friends.acceptFriendRequest(accepted)
            XCTFail("Second accept should fail")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.code, 403)
        }
    }

    func test_observeIncomingRequests_emitsPendingRequest() async throws {
        let friends = FirebaseFriendRepository()
        let aliceId = try await EmulatorHarness.signInUser(
            email: "alice-listen@test.ufree",
            displayName: "Alice"
        )
        try await friends.saveUserProfile(displayName: "Alice", hashedPhoneNumbers: [])

        let bobId = try await EmulatorHarness.signInUser(
            email: "bob-listen@test.ufree",
            displayName: "Bob"
        )
        try await friends.saveUserProfile(displayName: "Bob", hashedPhoneNumbers: [])

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(
            email: "alice-listen@test.ufree",
            displayName: "Alice"
        )
        let listenBobOptional = try await friends.findUserById(bobId)
        let bobProfile = try XCTUnwrap(listenBobOptional)
        try await friends.sendFriendRequest(to: bobProfile)

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(
            email: "bob-listen@test.ufree",
            displayName: "Bob"
        )
        let incoming = try await firstMatching(of: friends.observeIncomingRequests()) { requests in
            requests.contains(where: { $0.fromId == aliceId && $0.status == .pending })
        }
        XCTAssertFalse(incoming.isEmpty)
    }
}
