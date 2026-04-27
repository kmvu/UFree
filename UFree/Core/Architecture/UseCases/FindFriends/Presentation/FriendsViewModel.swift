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
import CoreImage.CIFilterBuiltins

@MainActor
public final class FriendsViewModel: ObservableObject {
    @Published public var friends: [UserProfile] = []
    @Published public var discoveredUsers: [UserProfile] = []
    @Published public var isLoading = false
    @Published public var isProcessing = false
    @Published public var errorMessage: String? = nil
    @Published public var showPermissionAlert = false
    
    // QR Code & Handshake
    @Published public var showQRScanner = false
    @Published public var showMyQR = false
    @Published public var qrImage: UIImage? = nil
    
    // Privacy & Trust
    @Published public var contactHashes: Set<String> = []

    // Phone number search
    @Published public var searchText: String = ""
    @Published public var searchResult: UserProfile?
    @Published public var isSearching = false
    @Published public var scannedCode: String? = nil {
        didSet {
            if let code = scannedCode {
                Task { await handleScannedCode(code) }
            }
        }
    }
    
    // Friend requests (handshake)
    @Published public var incomingRequests: [FriendRequest] = []
    private var listenerTask: Task<Void, Never>?

    private let friendRepository: FriendRepositoryProtocol
    private let contactsRepository: ContactsRepositoryProtocol

    public init(friendRepository: FriendRepositoryProtocol, contactsRepository: ContactsRepositoryProtocol? = nil) {
        self.friendRepository = friendRepository
        self.contactsRepository = contactsRepository ?? AppleContactsRepository()
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
        guard !isProcessing else { return }
        isLoading = true
        isProcessing = true
        defer { 
            isLoading = false
            isProcessing = false
        }
        do {
            self.friends = try await friendRepository.getMyFriends()
        } catch {
            self.errorMessage = "Failed to load friends: \(error.localizedDescription)"
        }
    }

    public func findFriendsFromContacts() async {
        guard !isProcessing else { return }
        isLoading = true
        isProcessing = true
        errorMessage = nil
        discoveredUsers = []
        defer { 
            isLoading = false
            isProcessing = false
        }

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

        // Step 2: Fetch and Hash contacts in background
        do {
            // Local hashes for "Trust Badge" logic
            let hashes = try await contactsRepository.fetchHashedContacts()
            self.contactHashes = Set(hashes)
            
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
    
    // MARK: - QR Code Logic
    
    public func generateMyQRCode(from userId: String) {
        let data = Data(userId.utf8)
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")

        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            let context = CIContext()
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                self.qrImage = UIImage(cgImage: cgImage)
            }
        }
    }
    
    public func handleScannedCode(_ code: String) async {
        guard !isProcessing else { return }
        isProcessing = true
        showQRScanner = false
        
        // QR Code extracts the encoded User ID
        // The app extracts the encoded user ID and automatically triggers 
        // the same profile routing logic used by deep links.
        do {
            // In this version, we fetch the profile associated with the scanned ID
            // and present it or send a request.
            if let user = try await friendRepository.findUserById(code) {
                print("Scanned user: \(user.displayName)")
                HapticManager.success()
                
                // Directly trigger the handshake request for this scanned user
                await sendFriendRequest(to: user, source: "qr_code")
                scannedCode = nil
            } else {
                self.errorMessage = "User not found."
            }
        } catch {
            self.errorMessage = "Invalid QR code: \(error.localizedDescription)"
        }
        isProcessing = false
    }
    
    // MARK: - Trust Logic
    
    public func isContactMatched(_ user: UserProfile) -> Bool {
        guard let hash = user.hashedPhoneNumber else { return false }
        return contactHashes.contains(hash)
    }

    /// Search for a user by phone number (privacy-safe via hash lookup)
    public func performPhoneSearch() async {
        guard !isProcessing else { return }
        guard !searchText.isEmpty else {
            errorMessage = "Please enter a phone number."
            return
        }

        isSearching = true
        isProcessing = true
        searchResult = nil
        errorMessage = nil
        defer { 
            isSearching = false
            isProcessing = false
        }

        do {
            self.searchResult = try await friendRepository.findUserByPhoneNumber(searchText)

            if searchResult == nil {
                self.errorMessage = "No user found with that phone number. They may not be on UFree yet."
            }
        } catch {
            self.errorMessage = "Search failed: \(error.localizedDescription)"
        }
    }

    @available(*, deprecated, message: "Use sendFriendRequest(to:source:) instead for handshake model")
    public func addFriend(_ user: UserProfile) async {
        await sendFriendRequest(to: user, source: "manual")
    }

    public func removeFriend(_ user: UserProfile) async {
        guard !isProcessing else { return }
        guard let uid = user.id else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let originalFriends = friends
        withAnimation {
            if let index = friends.firstIndex(where: { $0.id == user.id }) {
                friends.remove(at: index)
            }
        }
        do {
            try await friendRepository.removeFriend(userId: uid)
        } catch {
            self.friends = originalFriends
            self.errorMessage = "Failed to remove friend."
        }
    }
    
    // MARK: - Handshake Model (Friend Requests)
    
    public func sendFriendRequest(to user: UserProfile, source: String) async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            HapticManager.medium()
            try await friendRepository.sendFriendRequest(to: user)
            AnalyticsManager.logFriendRequestSent(source: source)
            
            // Remove from discovered users or search result
            withAnimation {
                if let index = discoveredUsers.firstIndex(where: { $0.id == user.id }) {
                    discoveredUsers.remove(at: index)
                }
                if searchResult?.id == user.id {
                    searchResult = nil
                    searchText = ""
                }
            }
        } catch {
            self.errorMessage = "Failed to send friend request."
        }
    }
    
    public func acceptRequest(_ request: FriendRequest) async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }
        
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
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }
        
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
