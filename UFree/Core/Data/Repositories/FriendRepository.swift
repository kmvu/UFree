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

    // contactsRepo dependency has been removed — callers now pass pre-computed
    // hashes via findFriendsFromContactHashes(_:), eliminating the double-fetch.
    init() {}

    func getMyFriends() async throws -> [UserProfile] {
        guard let userId = Auth.auth().currentUser?.uid else {
            // Return empty list for users not yet authenticated with Firebase
            return []
        }

        let snapshot = try await db.collection("users").document(userId).getDocument()
        guard let data = snapshot.data(),
              let friendIds = data["friendIds"] as? [String] else {
            return []
        }

        guard !friendIds.isEmpty else { return [] }

        // Fetch friend profiles in batches of 10 (Firestore limit)
        let chunks = friendIds.chunked(into: 10)
        var friends: [UserProfile] = []

        try await withThrowingTaskGroup(of: [UserProfile].self) { group in
            for chunk in chunks {
                group.addTask {
                    return try await self.fetchUsers(withIds: chunk)
                }
            }

            for try await users in group {
                friends.append(contentsOf: users)
            }
        }

        return friends
    }

    func findUserByPhoneNumber(_ phoneNumber: String) async throws -> UserProfile? {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return nil
        }

        // Generate all candidate hashes for this phone number (covers local & E.164 forms)
        let candidateHashes = CryptoUtils.phoneNumberHashes(for: phoneNumber)
        guard !candidateHashes.isEmpty else {
            throw NSError(domain: "FriendRepository", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid phone number"])
        }

        // Query the new array field using array-contains-any (up to 10 values, we have ≤2)
        let snapshot = try await db.collection("users")
            .whereField("hashedPhoneNumbers", arrayContainsAny: candidateHashes)
            .getDocuments()

        // Return the first match that isn't the current user
        for doc in snapshot.documents {
            if let user = try? doc.data(as: UserProfile.self),
               user.id != currentUserId {
                return user
            }
        }

        // Legacy fallback: query the old single-hash field for users registered before
        // the schema migration so they are still discoverable.
        if let legacyHash = candidateHashes.first {
            let legacySnapshot = try await db.collection("users")
                .whereField("hashedPhoneNumber", isEqualTo: legacyHash)
                .getDocuments()
            for doc in legacySnapshot.documents {
                if let user = try? doc.data(as: UserProfile.self),
                   user.id != currentUserId {
                    return user
                }
            }
        }

        return nil
    }
    
    func addFriend(userId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            // Silently fail for users not yet authenticated with Firebase
            return
        }
        
        // Add to current user's friendIds
        try await db.collection("users").document(currentUserId).updateData([
            "friendIds": FieldValue.arrayUnion([userId])
        ])
        
        // Add current user to friend's friendIds (bidirectional)
        try await db.collection("users").document(userId).updateData([
            "friendIds": FieldValue.arrayUnion([currentUserId])
        ])
    }
    
    func removeFriend(userId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            // Silently fail for users not yet authenticated with Firebase
            return
        }
        
        // Remove from current user's friendIds
        try await db.collection("users").document(currentUserId).updateData([
            "friendIds": FieldValue.arrayRemove([userId])
        ])
        
        // Remove current user from friend's friendIds (bidirectional)
        try await db.collection("users").document(userId).updateData([
            "friendIds": FieldValue.arrayRemove([currentUserId])
        ])
    }

    func findUserById(_ userId: String) async throws -> UserProfile? {
        let snapshot = try await db.collection("users").document(userId).getDocument()
        return try? snapshot.data(as: UserProfile.self)
    }
    
    func findFriendsFromContactHashes(_ hashes: [String]) async throws -> [UserProfile] {
        guard !hashes.isEmpty else { return [] }

        // Chunk into batches of 10 (Firestore `array-contains-any` limit)
        let chunks = hashes.chunked(into: 10)
        var matchedUsers: [UserProfile] = []

        // Query Firestore in parallel — one task per chunk
        try await withThrowingTaskGroup(of: [UserProfile].self) { group in
            for chunk in chunks {
                group.addTask {
                    return try await self.fetchUsers(withHashes: chunk)
                }
            }

            for try await users in group {
                matchedUsers.append(contentsOf: users)
            }
        }

        // De-duplicate by document ID in case a user matched on multiple hashes
        var seen = Set<String>()
        return matchedUsers.filter { user in
            guard let id = user.id else { return false }
            return seen.insert(id).inserted
        }
    }
    
    func sendFriendRequest(to user: UserProfile) async throws {
        guard let currentUid = Auth.auth().currentUser?.uid,
              let toId = user.id else {
            throw NSError(domain: "FriendRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing user information for request"])
        }
        
        // Use a fallback for name if not set in Auth profile yet
        let currentName = Auth.auth().currentUser?.displayName ?? "UFree User"
        
        let request = FriendRequest(
            id: nil,
            fromId: currentUid,
            fromName: currentName,
            toId: toId,
            status: .pending,
            timestamp: Date()
        )
        
        try db.collection("friendRequests").addDocument(from: request)
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
                    if let _ = error {
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
        guard let requestId = request.id else { return }
        
        let batch = db.batch()
        
        let requestRef = db.collection("friendRequests").document(requestId)
        let myRef = db.collection("users").document(request.toId)
        let theirRef = db.collection("users").document(request.fromId)
        
        // 1. Mark request as accepted
        batch.updateData(["status": FriendRequest.RequestStatus.accepted.rawValue], forDocument: requestRef)
        
        // 2. Add to my friend list
        batch.updateData(["friendIds": FieldValue.arrayUnion([request.fromId])], forDocument: myRef)
        
        // 3. Add to their friend list
        batch.updateData(["friendIds": FieldValue.arrayUnion([request.toId])], forDocument: theirRef)
        
        try await batch.commit()
    }
    
    func declineFriendRequest(_ request: FriendRequest) async throws {
        guard let requestId = request.id else { return }
        
        try await db.collection("friendRequests").document(requestId).updateData([
            "status": FriendRequest.RequestStatus.declined.rawValue
        ])
    }
    
    func saveUserProfile(displayName: String, hashedPhoneNumbers: [String]) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FriendRepository", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }

        var data: [String: Any] = ["displayName": displayName]

        if !hashedPhoneNumbers.isEmpty {
            // Write the new array field (primary, used for array-contains-any queries)
            data["hashedPhoneNumbers"] = hashedPhoneNumbers
            // Also write the legacy single-hash field (first hash = raw-digits form)
            // so that users registered before the migration remain discoverable via
            // the old `isEqualTo` query path until their document is re-written.
            data["hashedPhoneNumber"] = hashedPhoneNumbers[0]
        }

        try await db.collection("users").document(userId).setData(data, merge: true)
    }
    
    // MARK: - Private Helpers
    
    /// Queries Firestore for users whose `hashedPhoneNumbers` array contains any of the
    /// given hashes (new array field).  Falls back to the legacy `hashedPhoneNumber`
    /// single-field query for documents not yet migrated, then merges and deduplicates.
    private func fetchUsers(withHashes hashes: [String]) async throws -> [UserProfile] {
        // Primary query — new array field
        async let newFieldSnapshot = db.collection("users")
            .whereField("hashedPhoneNumbers", arrayContainsAny: hashes)
            .getDocuments()

        // Legacy query — old single-hash field (handles pre-migration documents)
        async let legacySnapshot = db.collection("users")
            .whereField("hashedPhoneNumber", in: hashes)
            .getDocuments()

        let (newDocs, oldDocs) = try await (newFieldSnapshot, legacySnapshot)

        var seen = Set<String>()
        var results: [UserProfile] = []

        for doc in (newDocs.documents + oldDocs.documents) {
            if let user = try? doc.data(as: UserProfile.self),
               let id = user.id,
               seen.insert(id).inserted {
                results.append(user)
            }
        }
        return results
    }
    
    /// Queries Firestore for users matching a batch of IDs
    private func fetchUsers(withIds ids: [String]) async throws -> [UserProfile] {
        let snapshot = try await db.collection("users")
            .whereField(FieldPath.documentID(), in: ids)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> UserProfile? in
            try? doc.data(as: UserProfile.self)
        }
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
