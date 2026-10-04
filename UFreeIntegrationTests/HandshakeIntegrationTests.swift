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

    func test_acceptFriendRequest_alreadyAccepted_isIdempotent() async throws {
        let friends = FirebaseFriendRepository()
        let (aliceId, bobId) = try await EmulatorHarness.connectAliceToBob(
            aliceEmail: "alice-twice@test.ufree",
            bobEmail: "bob-twice@test.ufree"
        )

        let requestId = FriendRequest.documentId(fromId: aliceId, toId: bobId)
        let acceptedOptional = try await friends.fetchFriendRequest(id: requestId)
        let accepted = try XCTUnwrap(acceptedOptional)
        try await friends.acceptFriendRequest(accepted)

        let bobFriends = try await friends.getMyFriends()
        XCTAssertTrue(bobFriends.contains(where: { $0.id == aliceId }))
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

    func test_sendFriendRequest_alreadyConnected_is409() async throws {
        let friends = FirebaseFriendRepository()
        let (_, bobId) = try await EmulatorHarness.connectAliceToBob(
            aliceEmail: "alice-409@test.ufree",
            bobEmail: "bob-409@test.ufree"
        )
        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(email: "alice-409@test.ufree", displayName: "Alice")
        let bob = try require(try await friends.findUserById(bobId))
        let before = try await friends.fetchFriendRequest(
            id: FriendRequest.documentId(fromId: Auth.auth().currentUser!.uid, toId: bobId)
        )
        do {
            try await friends.sendFriendRequest(to: bob)
            XCTFail("Already connected must not send again")
        } catch {
            XCTAssertEqual((error as NSError).code, 409)
        }
        let after = try await friends.fetchFriendRequest(
            id: FriendRequest.documentId(fromId: Auth.auth().currentUser!.uid, toId: bobId)
        )
        XCTAssertEqual(after?.status, before?.status)
        XCTAssertEqual(after?.timestamp, before?.timestamp)
    }

    func test_sendFriendRequest_whenReverseIsPending_is410_thenAccept() async throws {
        let friends = FirebaseFriendRepository()
        let aliceId = try await EmulatorHarness.signInUser(email: "alice-410@test.ufree", displayName: "Alice")
        try await friends.saveUserProfile(displayName: "Alice", hashedPhoneNumbers: [])
        let bobId = try await EmulatorHarness.signInUser(email: "bob-410@test.ufree", displayName: "Bob")
        try await friends.saveUserProfile(displayName: "Bob", hashedPhoneNumbers: [])

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(email: "bob-410@test.ufree", displayName: "Bob")
        let alice = try require(try await friends.findUserById(aliceId))
        try await friends.sendFriendRequest(to: alice)

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(email: "alice-410@test.ufree", displayName: "Alice")
        let bob = try require(try await friends.findUserById(bobId))
        do {
            try await friends.sendFriendRequest(to: bob)
            XCTFail("Crossed pending request must not create a second invite")
        } catch {
            XCTAssertEqual((error as NSError).code, 410)
        }

        let incoming = try require(try await friends.pendingFriendRequest(from: bobId))
        try await friends.acceptFriendRequest(incoming)
        let aliceFriends = try await friends.getMyFriends()
        XCTAssertEqual(aliceFriends.filter { $0.id == bobId }.count, 1)
    }

    func test_sendFriendRequest_afterDecline_is411() async throws {
        let friends = FirebaseFriendRepository()
        let aliceId = try await EmulatorHarness.signInUser(email: "alice-411@test.ufree", displayName: "Alice")
        try await friends.saveUserProfile(displayName: "Alice", hashedPhoneNumbers: [])
        let bobId = try await EmulatorHarness.signInUser(email: "bob-411@test.ufree", displayName: "Bob")
        try await friends.saveUserProfile(displayName: "Bob", hashedPhoneNumbers: [])

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(email: "alice-411@test.ufree", displayName: "Alice")
        let bob = try require(try await friends.findUserById(bobId))
        try await friends.sendFriendRequest(to: bob)

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(email: "bob-411@test.ufree", displayName: "Bob")
        let pending = try require(try await friends.pendingFriendRequest(from: aliceId))
        try await friends.declineFriendRequest(pending)

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(email: "alice-411@test.ufree", displayName: "Alice")
        do {
            try await friends.sendFriendRequest(to: bob)
            XCTFail("Declined invite must not be rewritten")
        } catch {
            XCTAssertEqual((error as NSError).code, 411)
        }
    }

    func test_sendFriendRequest_pendingDuplicate_doesNotRewrite() async throws {
        let friends = FirebaseFriendRepository()
        _ = try await EmulatorHarness.signInUser(email: "alice-dup@test.ufree", displayName: "Alice")
        try await friends.saveUserProfile(displayName: "Alice", hashedPhoneNumbers: [])
        let bobId = try await EmulatorHarness.signInUser(email: "bob-dup@test.ufree", displayName: "Bob")
        try await friends.saveUserProfile(displayName: "Bob", hashedPhoneNumbers: [])

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(email: "alice-dup@test.ufree", displayName: "Alice")
        let bob = try require(try await friends.findUserById(bobId))
        try await friends.sendFriendRequest(to: bob)
        let requestId = FriendRequest.documentId(fromId: Auth.auth().currentUser!.uid, toId: bobId)
        let before = try require(try await friends.fetchFriendRequest(id: requestId))
        try await friends.sendFriendRequest(to: bob)
        let after = try require(try await friends.fetchFriendRequest(id: requestId))
        XCTAssertEqual(after.status, .pending)
        XCTAssertEqual(after.timestamp, before.timestamp)
    }

    func test_acceptFriendRequest_concurrentCalls_friendsListedOnce() async throws {
        let friends = FirebaseFriendRepository()
        let (aliceId, bobId) = try await seedPendingAliceToBob(
            aliceEmail: "alice-race@test.ufree",
            bobEmail: "bob-race@test.ufree"
        )
        let pending = try require(try await friends.pendingFriendRequest(from: aliceId))
        async let first: Void = friends.acceptFriendRequest(pending)
        async let second: Void = friends.acceptFriendRequest(pending)
        _ = try await (first, second)

        let bobFriends = try await friends.getMyFriends()
        XCTAssertEqual(bobFriends.filter { $0.id == aliceId }.count, 1)
        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(email: "alice-race@test.ufree", displayName: "Alice")
        let aliceFriends = try await friends.getMyFriends()
        XCTAssertEqual(aliceFriends.filter { $0.id == bobId }.count, 1)
    }

    func test_removeFriend_thenReconnect_isClean() async throws {
        let friends = FirebaseFriendRepository()
        let (aliceId, bobId) = try await EmulatorHarness.connectAliceToBob(
            aliceEmail: "alice-readd@test.ufree",
            bobEmail: "bob-readd@test.ufree"
        )
        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(email: "alice-readd@test.ufree", displayName: "Alice")
        try await friends.removeFriend(userId: bobId)

        let bob = try require(try await friends.findUserById(bobId))
        try await friends.sendFriendRequest(to: bob)
        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(email: "bob-readd@test.ufree", displayName: "Bob")
        let pending = try require(try await friends.pendingFriendRequest(from: aliceId))
        try await friends.acceptFriendRequest(pending)
        let readded = try await friends.getMyFriends().filter { $0.id == aliceId }
        XCTAssertEqual(readded.count, 1)
    }

    func test_acceptFriendRequest_afterSenderDeleted_leavesNoFriend() async throws {
        let friends = FirebaseFriendRepository()
        let (aliceId, _) = try await seedPendingAliceToBob(
            aliceEmail: "alice-gone@test.ufree",
            bobEmail: "bob-gone@test.ufree"
        )
        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(email: "alice-gone@test.ufree", displayName: "Alice")
        try await friends.deleteAccountData()

        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(email: "bob-gone@test.ufree", displayName: "Bob")
        let requestId = FriendRequest.documentId(fromId: aliceId, toId: Auth.auth().currentUser!.uid)
        let leftover = FriendRequest(
            id: requestId,
            fromId: aliceId,
            fromName: "Alice",
            toId: Auth.auth().currentUser!.uid,
            status: .pending,
            timestamp: Date()
        )
        do {
            try await friends.acceptFriendRequest(leftover)
            XCTFail("Accept after the sender is gone must fail")
        } catch {
            XCTAssertEqual((error as NSError).code, 404)
        }
        let bobFriends = try await friends.getMyFriends()
        XCTAssertTrue(bobFriends.isEmpty)
    }

    func test_fetchFriendRequest_missingId_isNil() async throws {
        let friends = FirebaseFriendRepository()
        _ = try await EmulatorHarness.signInUser(email: "alice-miss@test.ufree", displayName: "Alice")
        let missing = try await friends.fetchFriendRequest(id: "no-such-user_also-missing")
        XCTAssertNil(missing)
    }

    func test_accept_rewritesInboxOnce() async throws {
        let friends = FirebaseFriendRepository()
        let (aliceId, bobId) = try await seedPendingAliceToBob(
            aliceEmail: "alice-inbox@test.ufree",
            bobEmail: "bob-inbox@test.ufree"
        )
        let bobUid = Auth.auth().currentUser!.uid
        let pending = try require(try await friends.pendingFriendRequest(from: aliceId))
        try await friends.acceptFriendRequest(pending)
        try await friends.acceptFriendRequest(pending)

        let bobNotes = try await Firestore.firestore()
            .collection("users").document(bobUid).collection("notifications").getDocuments()
        let bobAccepted = bobNotes.documents.filter {
            ($0.data()["type"] as? String) == AppNotification.NotificationType.friendAccepted.rawValue
        }
        XCTAssertEqual(bobAccepted.count, 1)
        XCTAssertEqual(bobAccepted.first?.data()["isRead"] as? Bool, true)

        let aliceNotes = try await Firestore.firestore()
            .collection("users").document(aliceId).collection("notifications").getDocuments()
        let aliceAccepted = aliceNotes.documents.filter {
            ($0.data()["type"] as? String) == AppNotification.NotificationType.friendAccepted.rawValue
                && ($0.data()["senderId"] as? String) == bobId
        }
        XCTAssertEqual(aliceAccepted.count, 1)
    }

    private func require<T>(_ value: T?) throws -> T {
        try XCTUnwrap(value)
    }

    private func seedPendingAliceToBob(aliceEmail: String, bobEmail: String) async throws -> (aliceId: String, bobId: String) {
        let friends = FirebaseFriendRepository()
        let aliceId = try await EmulatorHarness.signInUser(email: aliceEmail, displayName: "Alice")
        try await friends.saveUserProfile(displayName: "Alice", hashedPhoneNumbers: [])
        let bobId = try await EmulatorHarness.signInUser(email: bobEmail, displayName: "Bob")
        try await friends.saveUserProfile(displayName: "Bob", hashedPhoneNumbers: [])
        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(email: aliceEmail, displayName: "Alice")
        let bob = try require(try await friends.findUserById(bobId))
        try await friends.sendFriendRequest(to: bob)
        try EmulatorHarness.signOut()
        _ = try await EmulatorHarness.signInUser(email: bobEmail, displayName: "Bob")
        return (aliceId, bobId)
    }
}
