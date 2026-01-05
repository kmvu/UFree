//
//  FriendsViewModel.swift
//  UFree
//
//  Created by Khang Vu on 05/01/26.
//

import Foundation
import Combine
import SwiftUI

@MainActor
public final class FriendsViewModel: ObservableObject {
    @Published public var friends: [UserProfile] = []
    @Published public var discoveredUsers: [UserProfile] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var showPermissionAlert = false
    
    private let friendRepository: FriendRepositoryProtocol
    
    public init(friendRepository: FriendRepositoryProtocol) {
        self.friendRepository = friendRepository
    }
    
    public func loadFriends() async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.friends = try await friendRepository.getMyFriends()
        } catch {
            self.errorMessage = "Failed to load friends: \(error.localizedDescription)"
        }
    }
    
    public func findFriendsFromContacts() async {
        isLoading = true
        errorMessage = nil
        discoveredUsers = []
        defer { isLoading = false }
        do {
            let matches = try await friendRepository.findFriendsFromContacts()
            let existingIds = Set(friends.compactMap { $0.id })
            self.discoveredUsers = matches.filter { !existingIds.contains($0.id ?? "") }
        } catch {
            if (error as NSError).code == 403 {
                self.showPermissionAlert = true
            } else {
                self.errorMessage = "Could not sync contacts."
            }
        }
    }
    
    public func addFriend(_ user: UserProfile) async {
        guard let uid = user.id else { return }
        withAnimation {
            if let index = discoveredUsers.firstIndex(where: { $0.id == user.id }) {
                discoveredUsers.remove(at: index)
            }
            friends.append(user)
        }
        do {
            try await friendRepository.addFriend(userId: uid)
        } catch {
            self.errorMessage = "Failed to add friend."
            await loadFriends()
        }
    }
    
    public func removeFriend(_ user: UserProfile) async {
        guard let uid = user.id else { return }
        withAnimation {
            if let index = friends.firstIndex(where: { $0.id == user.id }) {
                friends.remove(at: index)
            }
        }
        do {
            try await friendRepository.removeFriend(userId: uid)
        } catch {
            self.errorMessage = "Failed to remove friend."
            await loadFriends()
        }
    }
}
