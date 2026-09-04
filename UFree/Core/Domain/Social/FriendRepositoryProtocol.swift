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
    /// - Returns: Public profiles whose phone-directory entries match any hash.
    func findFriendsFromContactHashes(_ hashes: [String]) async throws -> [UserProfile]

    // MARK: - Friends List

    /// Gets the current user's list of friends.
    func getMyFriends() async throws -> [UserProfile]

    /// Observes the current user's friends list in real-time (via `friendIds` on the user doc).
    /// Used so the inviter can celebrate the first connection without a manual pull.
    func observeFriends() -> AsyncStream<[UserProfile]>

    // MARK: - User Lookup

    /// Finds a single user by their phone number (privacy-safe via phoneDirectory lookup).
    func findUserByPhoneNumber(_ phoneNumber: String) async throws -> UserProfile?

    /// Finds a single user by their Firestore document ID (publicProfiles first).
    func findUserById(_ userId: String) async throws -> UserProfile?

    // MARK: - Friend Management

    /// Direct add is disabled. Implementations must throw; use `sendFriendRequest`.
    func addFriend(userId: String) async throws

    /// Removes a friend by user ID.
    func removeFriend(userId: String) async throws

    // MARK: - Handshake (Friend Requests)

    /// Sends a friend request to the given user.
    func sendFriendRequest(to user: UserProfile) async throws

    /// Observes incoming friend requests in real-time.
    func observeIncomingRequests() -> AsyncStream<[FriendRequest]>

    /// One-shot lookup of a pending incoming request from a specific sender.
    /// Used when Notification Center Accept runs before the live listener has populated.
    func pendingFriendRequest(from fromId: String) async throws -> FriendRequest?

    /// Loads a friend request by deterministic document id (`{fromId}_{toId}`).
    func fetchFriendRequest(id: String) async throws -> FriendRequest?

    /// Accepts a friend request (atomic batch write after a server read).
    func acceptFriendRequest(_ request: FriendRequest) async throws

    /// Declines a friend request.
    func declineFriendRequest(_ request: FriendRequest) async throws

    // MARK: - Profile

    /// Persists the user's display name and phone hashes, plus discovery projections
    /// (`publicProfiles/{uid}`, `phoneDirectory/{hash}`).
    ///
    /// - Parameters:
    ///   - displayName: The user's chosen display name.
    ///   - hashedPhoneNumbers: All candidate SHA-256 hashes produced by
    ///     `CryptoUtils.phoneNumberHashes(for:)` — typically 1–2 entries covering
    ///     the local-format and E.164-normalised forms of the number.
    func saveUserProfile(displayName: String, hashedPhoneNumbers: [String]) async throws

    /// Deletes the signed-in user's Firestore tree (availability, notifications,
    /// own friendRequests, phoneDirectory claims, publicProfiles, users doc) and
    /// removes this UID from each peer's `friendIds` so friends do not keep orphans.
    /// Does not delete the Firebase Auth user — call `AuthRepository.deleteAccount()` after.
    func deleteAccountData() async throws
}
