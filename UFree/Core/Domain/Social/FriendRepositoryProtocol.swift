//
//  FriendRepository.swift
//  UFree
//
//  Created by Khang Vu on 05/01/26.
//

import Foundation

public protocol FriendRepositoryProtocol {
    /// Syncs local contacts, hashes them, and finds matching users in Firestore.
    func findFriendsFromContacts() async throws -> [UserProfile]
    
    /// Gets the user's list of friends.
    func getMyFriends() async throws -> [UserProfile]
    
    /// Finds a single user by their phone number (privacy-safe via hash lookup).
    func findUserByPhoneNumber(_ phoneNumber: String) async throws -> UserProfile?
    
    /// Finds a single user by their document ID.
    func findUserById(_ userId: String) async throws -> UserProfile?

    /// Adds a friend by user ID (direct add, for backward compatibility).
    func addFriend(userId: String) async throws
    
    /// Removes a friend by user ID.
    func removeFriend(userId: String) async throws
    
    /// Sends a friend request (handshake model).
    func sendFriendRequest(to user: UserProfile) async throws
    
    /// Observes incoming friend requests in real-time.
    func observeIncomingRequests() -> AsyncStream<[FriendRequest]>
    
    /// Accepts a friend request (atomic batch write).
    func acceptFriendRequest(_ request: FriendRequest) async throws
    
    /// Declines a friend request.
    func declineFriendRequest(_ request: FriendRequest) async throws
}
