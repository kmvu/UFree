//
//  MockFriendRepository.swift
//  UFree
//
//  Created by Khang Vu on 05/01/26.
//

import Foundation

@MainActor
public final class MockFriendRepository: FriendRepositoryProtocol {
    
    private var discoveredUsers: [UserProfile]
    private var myFriends: [UserProfile]
    private var incomingRequests: [FriendRequest]
    private var sentRequests: [FriendRequest]
    private var allUsers: [UserProfile]
    
    nonisolated public init(discoveredUsers: [UserProfile] = [], myFriends: [UserProfile] = [], incomingRequests: [FriendRequest] = [], allUsers: [UserProfile] = []) {
        self.discoveredUsers = discoveredUsers
        self.myFriends = myFriends
        self.incomingRequests = incomingRequests
        self.sentRequests = []
        self.allUsers = allUsers
    }
    
    public func getMyFriends() async throws -> [UserProfile] {
        return myFriends
    }
    
    public func findUserByPhoneNumber(_ phoneNumber: String) async throws -> UserProfile? {
        // Mock: hash the phone number same way as real implementation
        guard let hashedNumber = CryptoUtils.hashPhoneNumber(phoneNumber) else {
            return nil
        }
        
        // Search by hashed phone number
        return allUsers.first { $0.hashedPhoneNumber == hashedNumber }
    }
    
    public func findFriendsFromContacts() async throws -> [UserProfile] {
        return discoveredUsers
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
    
    public func acceptFriendRequest(_ request: FriendRequest) async throws {
        guard let index = incomingRequests.firstIndex(where: { $0.id == request.id }) else { return }
        incomingRequests[index].status = .accepted
        
        // Add to friends list
        let profile = UserProfile(id: request.fromId, displayName: request.fromName, hashedPhoneNumber: "")
        myFriends.append(profile)
    }
    
    public func declineFriendRequest(_ request: FriendRequest) async throws {
        guard let index = incomingRequests.firstIndex(where: { $0.id == request.id }) else { return }
        incomingRequests[index].status = .declined
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
