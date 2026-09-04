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
    @Published public var errorMessage: String?
    @Published public var showPermissionAlert = false
    
    // QR Code & Handshake
    @Published public var showQRScanner = false
    @Published public var showMyQR = false
    @Published public var showMyQRCard = false // Managed within the Discovery Card flip
    @Published public var qrImage: UIImage?
    
    // Privacy & Trust
    @Published public var contactHashes: Set<String> = []

    // Phone number search
    @Published public var searchText: String = ""
    @Published public var searchResult: UserProfile?
    @Published public var isSearching = false
    @Published public var scannedCode: String? {
        didSet {
            if let code = scannedCode {
                Task { await handleScannedCode(code) }
            }
        }
    }
    
    // Friend requests (handshake)
    @Published public var incomingRequests: [FriendRequest] = []
    /// Which incoming row is running Accept / Decline (spinner stays on that row only).
    @Published public private(set) var processingRequestKey: String?
    /// Locally handled requests kept out of the list until Firestore stops echoing them as pending.
    private var handledIncomingRequestKeys = Set<String>()
    /// Friends added optimistically until the friends listener / fetch catches up.
    private var optimisticFriendsById: [String: UserProfile] = [:]
    /// `nonisolated(unsafe)` so `deinit` can cancel without hopping to the MainActor.
    /// A non-empty `@MainActor deinit` trips a Swift 6.2 / iOS 26.2 XCTest bug
    /// (`swift_task_deinitOnExecutorImpl` → "pointer being freed was not allocated").
    nonisolated(unsafe) private var requestsListenerTask: Task<Void, Never>?
    nonisolated(unsafe) private var friendsListenerTask: Task<Void, Never>?

    public let friendRepository: FriendRepositoryProtocol
    private let contactsRepository: ContactsRepositoryProtocol

    public init(friendRepository: FriendRepositoryProtocol, contactsRepository: ContactsRepositoryProtocol? = nil) {
        self.friendRepository = friendRepository
        self.contactsRepository = contactsRepository ?? AppleContactsRepository()
    }

    nonisolated deinit {
        requestsListenerTask?.cancel()
        friendsListenerTask?.cancel()
    }
    
    // MARK: - Real-Time Listener Lifecycle
    
    /// Starts listening to incoming friend requests in real-time
    public func listenToRequests() {
        // Cancel existing listener if any
        requestsListenerTask?.cancel()
        
        requestsListenerTask = Task { [weak self] in
            guard let friendRepository = self?.friendRepository else { return }
            for await requests in friendRepository.observeIncomingRequests() {
                guard !Task.isCancelled else { return }
                // Avoid `withAnimation` during hosted-view teardown (iOS 26.2 XCTest
                // allocator abort when an animation transaction outlives the hierarchy).
                self?.applyIncomingRequestsUpdate(requests)
            }
        }
    }

    /// Starts listening to friends list updates so the inviter sees accept without a pull.
    public func listenToFriends() {
        friendsListenerTask?.cancel()

        friendsListenerTask = Task { [weak self] in
            guard let friendRepository = self?.friendRepository else { return }
            for await latest in friendRepository.observeFriends() {
                guard !Task.isCancelled else { return }
                self?.applyFriendsUpdate(latest)
            }
        }
    }

    /// Drop discovery rows for people who are already connected (search uses `isAlreadyFriend` in UI).
    private func pruneSearchAndDiscoveryAgainstFriends() {
        let friendIds = Set(friends.compactMap(\.id))
        discoveredUsers.removeAll { user in
            guard let id = user.id else { return false }
            return friendIds.contains(id)
        }
    }

    func isProcessingRequest(_ request: FriendRequest) -> Bool {
        processingRequestKey == incomingRequestKey(request)
    }

    var hasActiveRequestAction: Bool {
        processingRequestKey != nil
    }

    private func incomingRequestKey(_ request: FriendRequest) -> String {
        if let id = request.id, !id.isEmpty {
            return id
        }
        return "\(request.fromId)-pending"
    }

    private func applyIncomingRequestsUpdate(_ requests: [FriendRequest]) {
        let pendingKeys = Set(requests.map(incomingRequestKey))
        handledIncomingRequestKeys = handledIncomingRequestKeys.intersection(pendingKeys)
        incomingRequests = requests.filter { !handledIncomingRequestKeys.contains(incomingRequestKey($0)) }
    }

    private func applyFriendsUpdate(_ latest: [UserProfile]) {
        let latestIds = Set(latest.compactMap(\.id))
        var merged = latest
        for (id, profile) in optimisticFriendsById where !latestIds.contains(id) {
            merged.append(profile)
        }
        for id in latestIds {
            optimisticFriendsById.removeValue(forKey: id)
        }
        friends = merged
        pruneSearchAndDiscoveryAgainstFriends()
    }

    private func markIncomingRequestHandled(_ request: FriendRequest) {
        handledIncomingRequestKeys.insert(incomingRequestKey(request))
        if let index = incomingRequests.firstIndex(where: { $0.id == request.id }) {
            incomingRequests.remove(at: index)
        } else if let index = incomingRequests.firstIndex(where: { $0.fromId == request.fromId }) {
            incomingRequests.remove(at: index)
        }
    }
    
    /// Stops listening to incoming friend requests and friends list
    public func stopListening() {
        requestsListenerTask?.cancel()
        requestsListenerTask = nil
        friendsListenerTask?.cancel()
        friendsListenerTask = nil
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
            applyFriendsUpdate(try await friendRepository.getMyFriends())
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

        // Step 2: Fetch and hash contacts once in background, then query Firestore
        do {
            // Use Task.detached to move the heavy CNContact enumeration + hashing
            // off the @MainActor thread.  Contacts are fetched exactly once here;
            // the repository no longer fetches them internally (that was the
            // source of the double-fetch bug).
            let hashes = try await Task.detached(priority: .userInitiated) { [contactsRepository] in
                try await contactsRepository.fetchHashedContacts()
            }.value

            // Store hashes for the trust-badge logic (isContactMatched)
            self.contactHashes = Set(hashes)

            // Step 3: Query Firestore with the pre-computed hashes — no re-fetch
            let matches = try await friendRepository.findFriendsFromContactHashes(hashes)

            let existingIds = Set(friends.compactMap { $0.id })

            withAnimation {
                self.discoveredUsers = matches.filter { !existingIds.contains($0.id ?? "") }
            }

            if self.discoveredUsers.isEmpty {
                self.errorMessage = "No friends found in your contacts."
            }
        } catch {
            #if DEBUG
            print("❌ Error syncing contacts: \(error.localizedDescription)")
            #endif
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
        // NOTE: Do NOT set isProcessing here — sendFriendRequest owns that flag.
        // Setting it here caused a deadlock where sendFriendRequest's own
        // `guard !isProcessing` would always bail out silently.
        
        // QR Code contains the encoded User ID
        do {
            if let user = try await friendRepository.findUserById(code) {
                #if DEBUG
                print("Scanned user: \(user.displayName)")
                #endif
                HapticManager.success()
                
                // Automatically send request for now as per strategy
                // Future: Show profile sheet
                await sendFriendRequest(to: user, source: "qr_code")
                
                // Reset scanned code after success
                scannedCode = nil
            } else {
                self.errorMessage = "User not found."
                scannedCode = nil
            }
        } catch {
            self.errorMessage = "Invalid QR code: \(error.localizedDescription)"
            scannedCode = nil
        }
    }
    
    // MARK: - Trust Logic
    
    public func isContactMatched(_ user: UserProfile) -> Bool {
        guard let hash = user.hashedPhoneNumber else { return false }
        return contactHashes.contains(hash)
    }

    /// Whether this profile is already in the trusted circle (no second Request).
    public func isAlreadyFriend(_ user: UserProfile) -> Bool {
        guard let id = user.id else { return false }
        return friends.contains { $0.id == id }
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
            let found = try await friendRepository.findUserByPhoneNumber(searchText)
            self.searchResult = found

            if found == nil {
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
        if isAlreadyFriend(user) {
            errorMessage = "You're already connected with \(user.displayName)."
            return
        }
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            HapticManager.medium()
            try await friendRepository.sendFriendRequest(to: user)
            AnalyticsManager.logFriendRequestSent(source: source)
            OnboardingProgressStore.shared.markInvitedFriend()
            
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
            self.errorMessage = "Failed to send friend request: \(error.localizedDescription)"
        }
    }
    
    /// Fired after a successful accept so the host can run the post-accept quest
    /// (first-connection celebration vs subsequent Who's Free toast).
    public var onAcceptCompleted: ((_ friendName: String, _ wasFirstFriend: Bool) -> Void)?

    /// Resolves a pending request for Notification Center Accept.
    /// Always prefers a server-backed request over client-built notification fields.
    public func resolveIncomingRequest(
        fromSenderId senderId: String,
        relatedRequestId: String?,
        senderName _: String,
        recipientId: String
    ) async -> FriendRequest? {
        let deterministicId = FriendRequest.documentId(
            fromId: senderId,
            toId: recipientId
        )
        let candidateIds = [relatedRequestId, deterministicId].compactMap { $0 }

        for id in candidateIds {
            if let fetched = try? await friendRepository.fetchFriendRequest(id: id),
               fetched.status == .pending,
               fetched.fromId == senderId,
               fetched.toId == recipientId {
                return fetched
            }
        }

        if let cached = incomingRequests.first(where: {
            $0.fromId == senderId && $0.status == .pending
        }) {
            return cached
        }

        return try? await friendRepository.pendingFriendRequest(from: senderId)
    }

    @discardableResult
    public func acceptRequest(_ request: FriendRequest) async -> Bool {
        guard processingRequestKey == nil else { return false }
        let key = incomingRequestKey(request)
        processingRequestKey = key
        defer { processingRequestKey = nil }

        do {
            HapticManager.success()
            try await friendRepository.acceptFriendRequest(request)

            let wasFirstFriend = friends.isEmpty
            let newFriend = UserProfile(
                id: request.fromId,
                displayName: request.fromName,
                hashedPhoneNumber: ""
            )

            withAnimation {
                markIncomingRequestHandled(request)
                if !friends.contains(where: { $0.id == request.fromId }) {
                    optimisticFriendsById[request.fromId] = newFriend
                    friends.append(newFriend)
                }
            }

            OnboardingProgressStore.shared.markFirstHandshake()
            onAcceptCompleted?(request.fromName, wasFirstFriend)

            requestNotificationPermissions()
            return true
        } catch {
            handledIncomingRequestKeys.remove(key)
            optimisticFriendsById.removeValue(forKey: request.fromId)
            self.errorMessage = "Failed to accept request: \(error.localizedDescription)"
            return false
        }
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted {
                #if canImport(UIKit)
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                #endif
            }
        }
    }
    
    public func declineRequest(_ request: FriendRequest) async {
        guard processingRequestKey == nil else { return }
        let key = incomingRequestKey(request)
        processingRequestKey = key
        defer { processingRequestKey = nil }

        do {
            HapticManager.warning()
            try await friendRepository.declineFriendRequest(request)

            withAnimation {
                markIncomingRequestHandled(request)
            }
        } catch {
            handledIncomingRequestKeys.remove(key)
            self.errorMessage = "Failed to decline request."
        }
    }
}
