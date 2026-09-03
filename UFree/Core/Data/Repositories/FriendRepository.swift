//
//  FriendRepository.swift
//  UFree
//
//  Created by Khang Vu on 05/01/26.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Implementation
final class FirebaseFriendRepository: FriendRepositoryProtocol {

    private let db = Firestore.firestore()

    init() {}

    /// Empty on purpose. A MainActor-isolated deallocation path under
    /// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` trips an iOS 26.2 XCTest bug:
    /// `pointer being freed was not allocated`.
    nonisolated deinit {}

    // MARK: - Document ID helpers

    /// Deterministic friend-request document id: `{fromId}_{toId}`.
    static func friendRequestId(fromId: String, toId: String) -> String {
        FriendRequest.documentId(fromId: fromId, toId: toId)
    }

    func getMyFriends() async throws -> [UserProfile] {
        guard let userId = Auth.auth().currentUser?.uid else {
            return []
        }

        let snapshot = try await db.collection("users").document(userId).getDocument()
        guard let data = snapshot.data(),
              let friendIds = data["friendIds"] as? [String],
              !friendIds.isEmpty else {
            return []
        }

        return try await profiles(forFriendIds: friendIds)
    }

    nonisolated func observeFriends() -> AsyncStream<[UserProfile]> {
        AsyncStream { continuation in
            guard let uid = Auth.auth().currentUser?.uid else {
                continuation.finish()
                return
            }

            let listener = db.collection("users").document(uid)
                .addSnapshotListener { [weak self] snapshot, error in
                    if error != nil {
                        continuation.finish()
                        return
                    }

                    let friendIds = snapshot?.data()?["friendIds"] as? [String] ?? []
                    guard !friendIds.isEmpty else {
                        continuation.yield([])
                        return
                    }

                    Task {
                        guard let self else { return }
                        do {
                            let friends = try await self.profiles(forFriendIds: friendIds)
                            continuation.yield(friends)
                        } catch {
                            // Keep listening; next snapshot may succeed.
                        }
                    }
                }

            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func findUserByPhoneNumber(_ phoneNumber: String) async throws -> UserProfile? {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return nil
        }

        let candidateHashes = CryptoUtils.phoneNumberHashes(for: phoneNumber)
        guard !candidateHashes.isEmpty else {
            throw NSError(
                domain: "FriendRepository",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid phone number"]
            )
        }

        for hash in candidateHashes {
            if let profile = try await profileFromPhoneDirectory(hash: hash, excluding: currentUserId) {
                return profile
            }
        }
        return nil
    }

    /// Direct add is disabled — friendship must go through the handshake.
    /// Kept on the protocol for source compatibility; always throws.
    func addFriend(userId: String) async throws {
        throw NSError(
            domain: "FriendRepository",
            code: 403,
            userInfo: [NSLocalizedDescriptionKey: "Direct add is disabled. Send a friend request instead."]
        )
    }

    func removeFriend(userId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return
        }

        // Owner removes the other from their list.
        try await db.collection("users").document(currentUserId).updateData([
            "friendIds": FieldValue.arrayRemove([userId])
        ])

        // Peer self-remove from the other user's list (allowed by rules without a request).
        try await db.collection("users").document(userId).updateData([
            "friendIds": FieldValue.arrayRemove([currentUserId])
        ])
    }

    func findUserById(_ userId: String) async throws -> UserProfile? {
        // Prefer public profile for discovery (QR / deep link) — readable by any signed-in user.
        if let publicProfile = try await fetchPublicProfile(userId: userId) {
            return publicProfile
        }
        // Fall back to full user doc when already friends (or owner).
        let snapshot = try await db.collection("users").document(userId).getDocument()
        return decodeUserProfile(from: snapshot)
    }

    func findFriendsFromContactHashes(_ hashes: [String]) async throws -> [UserProfile] {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return [] }
        guard !hashes.isEmpty else { return [] }

        var matchedIds = Set<String>()
        try await withThrowingTaskGroup(of: String?.self) { group in
            for hash in hashes {
                group.addTask {
                    let snap = try await self.db.collection("phoneDirectory").document(hash).getDocument()
                    guard let uid = snap.data()?["uid"] as? String,
                          uid != currentUserId else {
                        return nil
                    }
                    return uid
                }
            }
            for try await uid in group {
                if let uid { matchedIds.insert(uid) }
            }
        }

        guard !matchedIds.isEmpty else { return [] }

        var profiles: [UserProfile] = []
        try await withThrowingTaskGroup(of: UserProfile?.self) { group in
            for uid in matchedIds {
                group.addTask { try await self.fetchPublicProfile(userId: uid) }
            }
            for try await profile in group {
                if let profile { profiles.append(profile) }
            }
        }
        return profiles
    }

    func sendFriendRequest(to user: UserProfile) async throws {
        guard let currentUid = Auth.auth().currentUser?.uid,
              let toId = user.id else {
            throw NSError(
                domain: "FriendRepository",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Missing user information for request"]
            )
        }

        let currentName = Auth.auth().currentUser?.displayName ?? "UFree User"
        let requestId = Self.friendRequestId(fromId: currentUid, toId: toId)

        let request = FriendRequest(
            id: requestId,
            fromId: currentUid,
            fromName: currentName,
            toId: toId,
            status: .pending,
            timestamp: Date()
        )

        // Deterministic ID — enables rules verification and blocks duplicate pending requests.
        try await db.collection("friendRequests").document(requestId).setData([
            "fromId": request.fromId,
            "fromName": request.fromName,
            "toId": request.toId,
            "status": request.status.rawValue,
            "timestamp": Timestamp(date: request.timestamp)
        ])

        let note = AppNotification(
            recipientId: toId,
            senderId: currentUid,
            senderName: currentName,
            type: .friendRequest,
            date: Date(),
            isRead: false,
            relatedRequestId: requestId
        )
        _ = try await db.collection("users").document(toId).collection("notifications")
            .addDocument(from: note)
    }

    func pendingFriendRequest(from fromId: String) async throws -> FriendRequest? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        let requestId = Self.friendRequestId(fromId: fromId, toId: uid)
        return try await fetchFriendRequest(id: requestId)
    }

    func fetchFriendRequest(id: String) async throws -> FriendRequest? {
        let snapshot = try await db.collection("friendRequests").document(id).getDocument()
        guard snapshot.exists else { return nil }
        var request = try snapshot.data(as: FriendRequest.self)
        if request.id == nil {
            request.id = snapshot.documentID
        }
        return request
    }

    nonisolated func observeIncomingRequests() -> AsyncStream<[FriendRequest]> {
        AsyncStream { continuation in
            guard let uid = Auth.auth().currentUser?.uid else {
                continuation.finish()
                return
            }

            let listener = db.collection("friendRequests")
                .whereField("toId", isEqualTo: uid)
                .whereField("status", isEqualTo: FriendRequest.RequestStatus.pending.rawValue)
                .addSnapshotListener { snapshot, error in
                    if error != nil {
                        continuation.finish()
                        return
                    }

                    let requests = snapshot?.documents.compactMap { doc -> FriendRequest? in
                        try? doc.data(as: FriendRequest.self)
                    } ?? []
                    continuation.yield(requests)
                }

            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func acceptFriendRequest(_ request: FriendRequest) async throws {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }

        // Always server-read the request — never trust client-built notification fields alone.
        let requestId = request.id
            ?? Self.friendRequestId(fromId: request.fromId, toId: request.toId)
        guard let serverRequest = try await fetchFriendRequest(id: requestId) else {
            throw NSError(
                domain: "FriendRepository",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Friend request not found"]
            )
        }
        guard serverRequest.toId == currentUid,
              serverRequest.status == .pending else {
            throw NSError(
                domain: "FriendRepository",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Not allowed to accept this request"]
            )
        }

        let fromId = serverRequest.fromId
        let toId = serverRequest.toId

        let batch = db.batch()
        let requestRef = db.collection("friendRequests").document(requestId)
        let myRef = db.collection("users").document(toId)
        let theirRef = db.collection("users").document(fromId)

        batch.updateData(
            ["status": FriendRequest.RequestStatus.accepted.rawValue],
            forDocument: requestRef
        )
        batch.updateData(["friendIds": FieldValue.arrayUnion([fromId])], forDocument: myRef)
        batch.updateData(["friendIds": FieldValue.arrayUnion([toId])], forDocument: theirRef)

        try await batch.commit()

        let acceptorName = Auth.auth().currentUser?.displayName ?? "Your friend"
        let note = AppNotification(
            recipientId: fromId,
            senderId: toId,
            senderName: acceptorName,
            type: .friendAccepted,
            date: Date(),
            isRead: false,
            relatedRequestId: requestId
        )
        _ = try await db.collection("users").document(fromId).collection("notifications")
            .addDocument(from: note)
    }

    func declineFriendRequest(_ request: FriendRequest) async throws {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        let requestId = request.id
            ?? Self.friendRequestId(fromId: request.fromId, toId: request.toId)

        guard let serverRequest = try await fetchFriendRequest(id: requestId),
              serverRequest.toId == currentUid,
              serverRequest.status == .pending else {
            throw NSError(
                domain: "FriendRepository",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Not allowed to decline this request"]
            )
        }

        try await db.collection("friendRequests").document(requestId).updateData([
            "status": FriendRequest.RequestStatus.declined.rawValue
        ])
    }

    func saveUserProfile(displayName: String, hashedPhoneNumbers: [String]) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(
                domain: "FriendRepository",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No authenticated user"]
            )
        }

        var data: [String: Any] = ["displayName": displayName]

        if !hashedPhoneNumbers.isEmpty {
            data["hashedPhoneNumbers"] = hashedPhoneNumbers
            // Legacy single-hash field for any leftover clients / debugging.
            data["hashedPhoneNumber"] = hashedPhoneNumbers[0]
        }

        try await db.collection("users").document(userId).setData(data, merge: true)

        // Discovery projections (Phase 1 privacy model).
        try await db.collection("publicProfiles").document(userId).setData([
            "displayName": displayName
        ])

        for hash in hashedPhoneNumbers {
            try await claimPhoneDirectoryEntry(hash: hash, userId: userId)
        }
    }

    // MARK: - Private Helpers

    private func claimPhoneDirectoryEntry(hash: String, userId: String) async throws {
        let ref = db.collection("phoneDirectory").document(hash)
        let existing = try await ref.getDocument()
        if existing.exists {
            // First-writer-wins: only keep our claim; skip if owned by someone else.
            if existing.data()?["uid"] as? String == userId {
                return
            }
            return
        }
        try await ref.setData(["uid": userId])
    }

    private func fetchPublicProfile(userId: String) async throws -> UserProfile? {
        let snapshot = try await db.collection("publicProfiles").document(userId).getDocument()
        guard snapshot.exists,
              let displayName = snapshot.data()?["displayName"] as? String else {
            return nil
        }
        return UserProfile(id: userId, displayName: displayName)
    }

    private func profileFromPhoneDirectory(hash: String, excluding currentUserId: String) async throws -> UserProfile? {
        let snap = try await db.collection("phoneDirectory").document(hash).getDocument()
        guard let uid = snap.data()?["uid"] as? String, uid != currentUserId else {
            return nil
        }
        return try await fetchPublicProfile(userId: uid)
    }

    private func profiles(forFriendIds friendIds: [String]) async throws -> [UserProfile] {
        guard !friendIds.isEmpty else { return [] }
        // Individual gets — collection `in` queries fail under friend-gated list:false rules.
        var friends: [UserProfile] = []
        try await withThrowingTaskGroup(of: UserProfile?.self) { group in
            for id in friendIds {
                group.addTask {
                    let snap = try await self.db.collection("users").document(id).getDocument()
                    return self.decodeUserProfile(from: snap)
                }
            }
            for try await user in group {
                if let user { friends.append(user) }
            }
        }
        return friends
    }

    private func decodeUserProfile(from snapshot: DocumentSnapshot) -> UserProfile? {
        guard var user = try? snapshot.data(as: UserProfile.self) else { return nil }
        if user.id == nil {
            user.id = snapshot.documentID
        }
        guard user.id != nil else { return nil }
        return user
    }
}

// MARK: - Helper Extension for Chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
