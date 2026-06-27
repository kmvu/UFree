//
//  FriendRepositoryProtocol.swift
//  UFree
//
//  Created by Khang Vu on 05/01/26.
//

import Foundation

public protocol FriendRepositoryProtocol {

    // MARK: - Contact Discovery

    /// Accepts pre-computed contact hashes and returns matching UFree users.
    ///
    /// Callers (e.g. `FriendsViewModel`) are responsible for fetching and hashing
    /// contacts **once** via `ContactsRepositoryProtocol.fetchHashedContacts()` and
    /// then passing those hashes here.  This eliminates the redundant double-fetch
    /// that occurred when the repository fetched contacts internally.
    ///
    /// - Parameter hashes: SHA-256 hashes produced by `CryptoUtils.phoneNumberHashes(for:)`.
    /// - Returns: UFree users whose `hashedPhoneNumbers` array contains any of the given hashes.
    func findFriendsFromContactHashes(_ hashes: [String]) async throws -> [UserProfile]

    // MARK: - Friends List

    /// Gets the current user's list of friends.
    func getMyFriends() async throws -> [UserProfile]

    // MARK: - User Lookup

    /// Finds a single user by their phone number (privacy-safe via multi-hash lookup).
    func findUserByPhoneNumber(_ phoneNumber: String) async throws -> UserProfile?

    /// Finds a single user by their Firestore document ID.
    func findUserById(_ userId: String) async throws -> UserProfile?

    // MARK: - Friend Management

    /// Adds a friend by user ID (direct add, for backward compatibility).
    func addFriend(userId: String) async throws

    /// Removes a friend by user ID.
    func removeFriend(userId: String) async throws

    // MARK: - Handshake (Friend Requests)

    /// Sends a friend request to the given user.
    func sendFriendRequest(to user: UserProfile) async throws

    /// Observes incoming friend requests in real-time.
    func observeIncomingRequests() -> AsyncStream<[FriendRequest]>

    /// Accepts a friend request (atomic batch write).
    func acceptFriendRequest(_ request: FriendRequest) async throws

    /// Declines a friend request.
    func declineFriendRequest(_ request: FriendRequest) async throws

    // MARK: - Profile

    /// Persists the user's display name and all candidate phone hashes to Firestore.
    ///
    /// - Parameters:
    ///   - displayName: The user's chosen display name.
    ///   - hashedPhoneNumbers: All candidate SHA-256 hashes produced by
    ///     `CryptoUtils.phoneNumberHashes(for:)` — typically 1–2 entries covering
    ///     the local-format and E.164-normalised forms of the number.
    func saveUserProfile(displayName: String, hashedPhoneNumbers: [String]) async throws
}
