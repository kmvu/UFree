//
//  MockFriendRepository.swift
//  UFree
//
//  Created by Khang Vu on 05/01/26.
//

import Foundation

public actor MockFriendRepository: FriendRepositoryProtocol {
     
    private var discoveredUsers: [UserProfile]
    private var myFriends: [UserProfile]
    
    public init(discoveredUsers: [UserProfile] = [], myFriends: [UserProfile] = []) {
        self.discoveredUsers = discoveredUsers
        self.myFriends = myFriends
    }
    
    public func getMyFriends() async throws -> [UserProfile] {
        return myFriends
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
    
    /// Adds a mock discovered user for testing
    public func addDiscoveredUser(_ user: UserProfile) {
        discoveredUsers.append(user)
    }
    
    /// Adds a mock friend for testing
    public func addFriend(_ user: UserProfile) {
        myFriends.append(user)
    }
    
    /// Clears all mock data
    public func clearMockData() {
        discoveredUsers.removeAll()
        myFriends.removeAll()
    }
}
