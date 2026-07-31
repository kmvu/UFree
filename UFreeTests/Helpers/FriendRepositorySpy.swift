//
//  FriendRepositorySpy.swift
//  UFreeTests
//

import Foundation
@testable import UFree

/// Recording test double for `FriendRepositoryProtocol`.
///
/// `MockFriendRepository` ships in the app target and models realistic behaviour,
/// which makes it a poor fit for tests that need to assert *what was sent* or to
/// force a specific method to fail. This spy records every call and lets each
/// method be individually configured to throw.
final class FriendRepositorySpy: FriendRepositoryProtocol, @unchecked Sendable {

    // MARK: - Recorded calls

    struct SavedProfile: Equatable {
        let displayName: String
        let hashedPhoneNumbers: [String]
    }

    private(set) var savedProfiles: [SavedProfile] = []
    private(set) var sentRequests: [UserProfile] = []
    private(set) var acceptedRequests: [FriendRequest] = []
    private(set) var declinedRequests: [FriendRequest] = []
    private(set) var removedFriendIds: [String] = []
    private(set) var contactHashQueries: [[String]] = []

    // MARK: - Stubbed results

    var myFriends: [UserProfile] = []
    var contactMatches: [UserProfile] = []
    var userByPhoneNumber: UserProfile?
    var userById: UserProfile?
    var incomingRequests: [FriendRequest] = []

    // MARK: - Failure injection

    var saveProfileError: Error?
    var getMyFriendsError: Error?
    var contactHashesError: Error?
    var findByPhoneError: Error?
    var findByIdError: Error?
    var sendRequestError: Error?
    var acceptRequestError: Error?
    var declineRequestError: Error?
    var removeFriendError: Error?

    // MARK: - FriendRepositoryProtocol

    func findFriendsFromContactHashes(_ hashes: [String]) async throws -> [UserProfile] {
        contactHashQueries.append(hashes)
        if let contactHashesError { throw contactHashesError }
        return contactMatches
    }

    func getMyFriends() async throws -> [UserProfile] {
        if let getMyFriendsError { throw getMyFriendsError }
        return myFriends
    }

    func findUserByPhoneNumber(_ phoneNumber: String) async throws -> UserProfile? {
        if let findByPhoneError { throw findByPhoneError }
        return userByPhoneNumber
    }

    func findUserById(_ userId: String) async throws -> UserProfile? {
        if let findByIdError { throw findByIdError }
        return userById
    }

    func addFriend(userId: String) async throws {}

    func removeFriend(userId: String) async throws {
        removedFriendIds.append(userId)
        if let removeFriendError { throw removeFriendError }
    }

    func sendFriendRequest(to user: UserProfile) async throws {
        sentRequests.append(user)
        if let sendRequestError { throw sendRequestError }
    }

    func observeIncomingRequests() -> AsyncStream<[FriendRequest]> {
        let requests = incomingRequests
        return AsyncStream { continuation in
            continuation.yield(requests)
            continuation.finish()
        }
    }

    func acceptFriendRequest(_ request: FriendRequest) async throws {
        acceptedRequests.append(request)
        if let acceptRequestError { throw acceptRequestError }
    }

    func declineFriendRequest(_ request: FriendRequest) async throws {
        declinedRequests.append(request)
        if let declineRequestError { throw declineRequestError }
    }

    func saveUserProfile(displayName: String, hashedPhoneNumbers: [String]) async throws {
        savedProfiles.append(SavedProfile(displayName: displayName, hashedPhoneNumbers: hashedPhoneNumbers))
        if let saveProfileError { throw saveProfileError }
    }
}
