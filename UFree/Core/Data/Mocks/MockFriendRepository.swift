//
//  MockFriendRepository.swift
//  UFree
//
//  Created by Khang Vu on 05/01/26.
//

import Foundation

public final class MockFriendRepository: FriendRepositoryProtocol {
     
    private var discoveredUsers: [UserProfile]
    private var myFriends: [UserProfile]
    private var incomingRequests: [FriendRequest]
    private var sentRequests: [FriendRequest]
    private var allUsers: [UserProfile]
    
    public init(discoveredUsers: [UserProfile] = [], myFriends: [UserProfile] = [], incomingRequests: [FriendRequest] = [], allUsers: [UserProfile] = []) {
        self.discoveredUsers = discoveredUsers
        self.myFriends = myFriends
        self.incomingRequests = incomingRequests
        self.sentRequests = []
        self.allUsers = allUsers
    }

    /// Empty `nonisolated` deinit works around a Swift 6.2 / iOS 26.2 XCTest bug where
    /// MainActor-isolated class teardown aborts with "pointer being freed was not allocated".
    nonisolated deinit {}
    
    public func getMyFriends() async throws -> [UserProfile] {
        return myFriends
    }
    
    public func findUserByPhoneNumber(_ phoneNumber: String) async throws -> UserProfile? {
        // Generate candidate hashes the same way as the real implementation
        let candidateHashes = CryptoUtils.phoneNumberHashes(for: phoneNumber)
        guard !candidateHashes.isEmpty else { return nil }

        // Search against the new array field first, then the legacy single-hash field
        return allUsers.first { user in
            let matchesArray = user.hashedPhoneNumbers.contains { candidateHashes.contains($0) }
            let matchesLegacy = user.hashedPhoneNumber.map { candidateHashes.contains($0) } ?? false
            return matchesArray || matchesLegacy
        }
    }

    public func findUserById(_ userId: String) async throws -> UserProfile? {
        return allUsers.first { $0.id == userId }
    }

    public func findFriendsFromContactHashes(_ hashes: [String]) async throws -> [UserProfile] {
        guard !hashes.isEmpty else { return [] }
        // Return any mock discovered user whose hashes overlap with the input
        // (falls back to returning all discoveredUsers if none have hashes set,
        //  preserving pre-existing mock behaviour for tests that don't care about hashes)
        let matched = discoveredUsers.filter { user in
            user.hashedPhoneNumbers.contains { hashes.contains($0) }
        }
        return matched.isEmpty ? discoveredUsers : matched
    }
    
    public func addFriend(userId: String) async throws {
        // Mock: no-op
    }
    
    public func removeFriend(userId: String) async throws {
        // Mock: no-op
    }
    
    public func sendFriendRequest(to user: UserProfile) async throws {
        guard let userId = user.id else { return }
        let request = FriendRequest(
            id: UUID().uuidString,
            fromId: "currentUser",
            fromName: "Current User",
            toId: userId,
            status: .pending,
            timestamp: Date()
        )
        sentRequests.append(request)
    }
    
    public func observeIncomingRequests() -> AsyncStream<[FriendRequest]> {
        let requests = incomingRequests
        return AsyncStream { continuation in
            continuation.yield(requests)
            continuation.finish()
        }
    }

    public func pendingFriendRequest(from fromId: String) async throws -> FriendRequest? {
        incomingRequests.first { $0.fromId == fromId && $0.status == .pending }
    }
    
    public func acceptFriendRequest(_ request: FriendRequest) async throws {
        if let index = incomingRequests.firstIndex(where: { $0.id == request.id }) {
            incomingRequests[index].status = .accepted
        } else if let index = incomingRequests.firstIndex(where: {
            $0.fromId == request.fromId && $0.status == .pending
        }) {
            incomingRequests[index].status = .accepted
        } else if request.id != nil {
            // Accept-by-id path (Notification Center with relatedRequestId) when
            // the in-memory list was never populated by the listener.
            var accepted = request
            accepted.status = .accepted
            incomingRequests.append(accepted)
        } else {
            return
        }

        if !myFriends.contains(where: { $0.id == request.fromId }) {
            let profile = UserProfile(id: request.fromId, displayName: request.fromName, hashedPhoneNumber: "")
            myFriends.append(profile)
        }
    }
    
    public func declineFriendRequest(_ request: FriendRequest) async throws {
        guard let index = incomingRequests.firstIndex(where: { $0.id == request.id }) else { return }
        incomingRequests[index].status = .declined
    }
    
    public func saveUserProfile(displayName: String, hashedPhoneNumbers: [String]) async throws {
        // Mock: no-op
    }
    
    /// Adds a mock discovered user for testing
    public func addDiscoveredUser(_ user: UserProfile) {
        discoveredUsers.append(user)
    }
    
    /// Adds a mock friend for testing
    public func addFriend(_ user: UserProfile) {
        myFriends.append(user)
    }
    
    /// Adds a mock incoming request for testing
    public func addIncomingRequest(_ request: FriendRequest) {
        incomingRequests.append(request)
    }
    
    /// Adds a mock user to the all users list for phone search
    public func addUser(_ user: UserProfile) {
        allUsers.append(user)
    }
    
    /// Clears all mock data
    public func clearMockData() {
        discoveredUsers.removeAll()
        myFriends.removeAll()
        incomingRequests.removeAll()
        sentRequests.removeAll()
        allUsers.removeAll()
    }
}
