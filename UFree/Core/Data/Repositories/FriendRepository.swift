//
//  FriendRepository.swift
//  UFree
//
//  Created by Khang Vu on 05/01/26.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Protocol
public protocol FriendRepositoryProtocol {
     /// Syncs local contacts, hashes them, and finds matching users in Firestore.
    func findFriendsFromContacts() async throws -> [UserProfile]
    
    /// Gets the user's list of friends.
    func getMyFriends() async throws -> [UserProfile]
    
    /// Adds a friend by user ID.
    func addFriend(userId: String) async throws
    
    /// Removes a friend by user ID.
    func removeFriend(userId: String) async throws
}

// MARK: - Implementation
final class FirebaseFriendRepository: FriendRepositoryProtocol {
     
     private let db = Firestore.firestore()
    private let contactsRepo: ContactsRepositoryProtocol
    
    init(contactsRepo: ContactsRepositoryProtocol) {
        self.contactsRepo = contactsRepo
    }
    
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
    
    func findFriendsFromContacts() async throws -> [UserProfile] {
        // 1. Get local hashes (Privacy Safe)
        let localHashes = try await contactsRepo.fetchHashedContacts()
        
        guard !localHashes.isEmpty else { return [] }
        
        // 2. Chunk hashes into batches of 10 (Firestore Limit)
        let chunks = localHashes.chunked(into: 10)
        var matchedUsers: [UserProfile] = []
        
        // 3. Query Firestore in parallel
        // We use a TaskGroup to fire off all batch queries at once
        try await withThrowingTaskGroup(of: [UserProfile].self) { group in
            for chunk in chunks {
                group.addTask {
                    return try await self.fetchUsers(withHashes: chunk)
                }
            }
            
            // Collect results
            for try await users in group {
                matchedUsers.append(contentsOf: users)
            }
        }
        
        return matchedUsers
    }
    
    // MARK: - Private Helpers
    
    /// Queries Firestore for users matching a batch of hashes
    private func fetchUsers(withHashes hashes: [String]) async throws -> [UserProfile] {
        let snapshot = try await db.collection("users")
            .whereField("hashedPhoneNumber", in: hashes)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> UserProfile? in
            try? doc.data(as: UserProfile.self)
        }
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
