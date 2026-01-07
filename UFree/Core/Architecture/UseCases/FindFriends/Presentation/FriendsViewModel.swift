//
//  FriendsViewModel.swift
//  UFree
//
//  Created by Khang Vu on 05/01/26.
//

import Foundation
import Combine
import SwiftUI
import Contacts

@MainActor
public final class FriendsViewModel: ObservableObject {
    @Published public var friends: [UserProfile] = []
    @Published public var discoveredUsers: [UserProfile] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var showPermissionAlert = false

    // Phone number search
    @Published public var searchText: String = ""
    @Published public var searchResult: UserProfile?
    @Published public var isSearching = false
    
    // Friend requests (handshake)
    @Published public var incomingRequests: [FriendRequest] = []
    private var listenerTask: Task<Void, Never>?

    private let friendRepository: FriendRepositoryProtocol
    private let contactsRepository: ContactsRepositoryProtocol

    public init(friendRepository: FriendRepositoryProtocol, contactsRepository: ContactsRepositoryProtocol? = nil) {
        self.friendRepository = friendRepository
        // Extract ContactsRepository from FriendRepository if available
        if let friendRepo = friendRepository as? FirebaseFriendRepository {
            self.contactsRepository = AppleContactsRepository()
        } else {
            self.contactsRepository = contactsRepository ?? AppleContactsRepository()
        }
    }
    
    // MARK: - Real-Time Listener Lifecycle
    
    /// Starts listening to incoming friend requests in real-time
    public func listenToRequests() {
        // Cancel existing listener if any
        listenerTask?.cancel()
        
        listenerTask = Task {
            for await requests in friendRepository.observeIncomingRequests() {
                // SwiftUI animation for new requests popping in
                withAnimation(.spring()) {
                    self.incomingRequests = requests
                }
            }
        }
    }
    
    /// Stops listening to incoming friend requests
    public func stopListening() {
        listenerTask?.cancel()
        listenerTask = nil
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

        // Step 1: Check authorization status first
        let status = CNContactStore.authorizationStatus(for: .contacts)

        // If not authorized, request permission
        if status != .authorized {
            let hasAccess = await contactsRepository.requestAccess()

            guard hasAccess else {
                self.showPermissionAlert = true
                return
            }
        }

        // Step 2: Fetch friends
        do {
            let matches = try await friendRepository.findFriendsFromContacts()
            let existingIds = Set(friends.compactMap { $0.id })
            self.discoveredUsers = matches.filter { !existingIds.contains($0.id ?? "") }

            if self.discoveredUsers.isEmpty {
                self.errorMessage = "No friends found in your contacts."
            }
        } catch {
            print("❌ Error syncing contacts: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
        }
    }

    /// Search for a user by phone number (privacy-safe via hash lookup)
    public func performPhoneSearch() async {
        guard !searchText.isEmpty else {
            errorMessage = "Please enter a phone number."
            return
        }

        isSearching = true
        searchResult = nil
        errorMessage = nil
        defer { isSearching = false }

        do {
            self.searchResult = try await friendRepository.findUserByPhoneNumber(searchText)

            if searchResult == nil {
                self.errorMessage = "No user found with that phone number. They may not be on UFree yet."
            }
        } catch {
            self.errorMessage = "Search failed: \(error.localizedDescription)"
        }
    }

    public func addFriend(_ user: UserProfile) async {
        guard let uid = user.id else { return }
        withAnimation {
            if let index = discoveredUsers.firstIndex(where: { $0.id == user.id }) {
                discoveredUsers.remove(at: index)
            }
            // Check if already in friends list
            if !friends.contains(where: { $0.id == user.id }) {
                friends.append(user)
            }
        }
        do {
            try await friendRepository.addFriend(userId: uid)
            // Clear search after adding
            searchResult = nil
            searchText = ""
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
    
    // MARK: - Handshake Model (Friend Requests)
    
    public func sendFriendRequest(to user: UserProfile) async {
        do {
            HapticManager.medium()
            try await friendRepository.sendFriendRequest(to: user)
            
            // Remove from discovered users
            withAnimation {
                if let index = discoveredUsers.firstIndex(where: { $0.id == user.id }) {
                    discoveredUsers.remove(at: index)
                }
            }
        } catch {
            self.errorMessage = "Failed to send friend request."
        }
    }
    
    public func acceptRequest(_ request: FriendRequest) async {
        do {
            HapticManager.success()
            try await friendRepository.acceptFriendRequest(request)
            
            // Remove from incoming requests and add to friends
            withAnimation {
                if let index = incomingRequests.firstIndex(where: { $0.id == request.id }) {
                    incomingRequests.remove(at: index)
                }
                let newFriend = UserProfile(
                    id: request.fromId,
                    displayName: request.fromName,
                    hashedPhoneNumber: ""
                )
                friends.append(newFriend)
            }
        } catch {
            self.errorMessage = "Failed to accept request."
        }
    }
    
    public func declineRequest(_ request: FriendRequest) async {
        do {
            HapticManager.warning()
            try await friendRepository.declineFriendRequest(request)
            
            // Remove from incoming requests
            withAnimation {
                if let index = incomingRequests.firstIndex(where: { $0.id == request.id }) {
                    incomingRequests.remove(at: index)
                }
            }
        } catch {
            self.errorMessage = "Failed to decline request."
        }
    }
}
