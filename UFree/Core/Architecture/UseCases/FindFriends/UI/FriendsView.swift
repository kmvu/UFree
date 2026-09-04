//
//  FriendsView.swift
//  UFree
//
//  Created by Khang Vu on 05/01/26.
//

import SwiftUI

public struct FriendsView: View {
    @StateObject private var viewModel: FriendsViewModel
    @ObservedObject var rootViewModel: RootViewModel
    @FocusState private var isSearchFocused: Bool
    @State private var friendPendingRemoval: UserProfile?

    public init(friendRepository: FriendRepositoryProtocol, rootViewModel: RootViewModel) {
        self.init(viewModel: FriendsViewModel(friendRepository: friendRepository), rootViewModel: rootViewModel)
    }

    /// Accepts a pre-built ViewModel so callers can supply their own contacts repository
    /// instead of the `AppleContactsRepository` default.
    public init(viewModel: FriendsViewModel, rootViewModel: RootViewModel) {
        self.rootViewModel = rootViewModel
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    if let userId = rootViewModel.currentUser?.id {
                        DiscoveryCardView(viewModel: viewModel, userId: userId)
                            .adaptiveContentWidth()

                        shareInviteLinkButton(userId: userId)
                            .adaptiveContentWidth()
                    }

                    VStack(spacing: 12) {
                        incomingRequestsSection
                        myFriendsSection
                        suggestedFromContactsSection
                            .id("bottomOfPage")
                    }
                    .adaptiveContentWidth()
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .onChange(of: isSearchFocused) { _, focused in
                if focused {
                    // Small delay to allow keyboard to begin appearing and ScrollView to adjust
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("bottomOfPage", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .navigationTitle("Friends")
        .overlay { if viewModel.isLoading { ProgressView() } }
        .task {
            // Warm listeners if this tab is opened before MainAppView.onAppear finishes.
            // Do not stopListening on disappear — MainAppView owns the shared VM lifecycle.
            viewModel.listenToRequests()
            viewModel.listenToFriends()
            await viewModel.loadFriends()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NotificationBellButton(isPresented: .constant(false))
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let error = viewModel.errorMessage { Text(error) }
        }
        .alert("Permission Needed", isPresented: $viewModel.showPermissionAlert) {
            Button("Settings", role: .cancel) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .destructive) {}
        } message: {
            Text("Please allow Contacts access in Settings to find friends.")
        }
        .alert("Remove Friend?", isPresented: removalConfirmationIsPresented) {
            Button("Remove", role: .destructive) {
                if let friend = friendPendingRemoval {
                    Task { await viewModel.removeFriend(friend) }
                }
                friendPendingRemoval = nil
            }
            Button("Cancel", role: .cancel) {
                friendPendingRemoval = nil
            }
        } message: {
            if let friend = friendPendingRemoval {
                Text("\(friend.displayName) will be removed from your trusted circle. You can add them again anytime.")
            }
        }
    }

    private var removalConfirmationIsPresented: Binding<Bool> {
        Binding(
            get: { friendPendingRemoval != nil },
            set: { isPresented in
                if !isPresented {
                    friendPendingRemoval = nil
                }
            }
        )
    }

    @ViewBuilder
    private func shareInviteLinkButton(userId: String) -> some View {
        if let inviteURL = URL(string: "https://ufree.app/profile/\(userId)") {
            shareInviteLinkContent(inviteURL: inviteURL)
        }
    }

    @ViewBuilder
    private func shareInviteLinkContent(inviteURL: URL) -> some View {
        ShareLink(
            item: inviteURL,
            subject: Text("Join me on UFree"),
            message: Text("Add me on UFree so we can find a free night: \(inviteURL.absoluteString)")
        ) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: "link")
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Share Invite Link")
                        .font(.headline)
                    Text("Add me on UFree so we can find a free night")
                        .font(.caption)
                        .opacity(0.9)
                }

                Spacer()

                Image(systemName: "square.and.arrow.up")
                    .font(.subheadline)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(24)
            .shadow(color: Color.accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(InteractiveButtonStyle())
        .simultaneousGesture(TapGesture().onEnded {
            HapticManager.medium()
            OnboardingProgressStore.shared.markInvitedFriend()
        })
    }

    @ViewBuilder
    private var incomingRequestsSection: some View {
        if !viewModel.incomingRequests.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Friend Requests")
                    .font(.subheadline).bold()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                
                ForEach(viewModel.incomingRequests) { request in
                    HStack(spacing: 12) {
                        Circle().fill(Color.green.opacity(0.2)).frame(width: 40, height: 40)
                            .overlay { Text(String(request.fromName.prefix(1))).font(.headline).foregroundColor(.green) }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(request.fromName).font(.headline)
                            Text("wants to be friends").font(.caption).foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Button {
                                Task { await viewModel.acceptRequest(request) }
                            } label: {
                                if viewModel.isProcessingRequest(request) {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text("Accept")
                                }
                            }
                            .ufreeCompactButton(tint: .green)
                            .disabled(viewModel.hasActiveRequestAction)

                            Button(role: .destructive) {
                                Task { await viewModel.declineRequest(request) }
                            } label: {
                                if viewModel.isProcessingRequest(request) {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "xmark")
                                }
                            }
                            .ufreeCompactButton(prominent: false, tint: .secondary)
                            .disabled(viewModel.hasActiveRequestAction)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private var myFriendsSection: some View {
        if !viewModel.friends.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("My Trusted Circle")
                    .font(.subheadline).bold()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                
                ForEach(viewModel.friends) { friend in
                    friendRow(for: friend, isDiscovered: false)
                        .padding(.horizontal)
                }
            }
        }
    }

    @ViewBuilder
    private var suggestedFromContactsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested from Contacts")
                .font(.subheadline).bold()
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 12)
            
            VStack(spacing: 8) {
                // Search by Phone
                HStack(spacing: 12) {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    
                    TextField("Find by Phone Number", text: $viewModel.searchText)
                        .keyboardType(.phonePad)
                        .submitLabel(.search)
                        .focused($isSearchFocused)
                        .onSubmit { Task { await viewModel.performPhoneSearch() } }
                        .disabled(viewModel.isSearching)
                    
                    if !viewModel.searchText.isEmpty {
                        Button(action: {
                            HapticManager.medium()
                            Task { await viewModel.performPhoneSearch() }
                        }) {
                            if viewModel.isSearching {
                                ProgressView().frame(width: 20, height: 20)
                            } else {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .disabled(viewModel.isSearching)
                    }
                }
                .id("searchField")
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(16)
                
                // Search result or empty state button
                if let result = viewModel.searchResult {
                    friendRow(for: result, isDiscovered: true, source: "manual")
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else if viewModel.discoveredUsers.isEmpty {
                    Button(action: {
                        Task { await viewModel.findFriendsFromContacts() }
                    }) {
                        Label("Sync Contacts", systemImage: "person.2.badge.gearshape")
                            .frame(maxWidth: .infinity)
                    }
                    .ufreeSecondaryButton()
                } else {
                    ForEach(viewModel.discoveredUsers) { user in
                        friendRow(for: user, isDiscovered: true, source: "contact_sync")
                    }
                }
                
                Text("Secure, anonymous matching. Your phone numbers never leave your device.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.horizontal)
        }
    }

    private func friendRow(for user: UserProfile, isDiscovered: Bool, source: String = "manual") -> some View {
        HStack(spacing: 12) {
            Circle().fill(isDiscovered ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay { 
                    Text(String(user.displayName.prefix(1)))
                        .font(.headline)
                        .foregroundColor(isDiscovered ? .green : .blue) 
                }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(user.displayName).font(.headline)
                    if isDiscovered && viewModel.isContactMatched(user) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                            .help("In your contacts")
                    }
                }
                Text(
                    viewModel.isAlreadyFriend(user) || !isDiscovered
                        ? "Connected"
                        : "UFree Member"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isDiscovered {
                if viewModel.isAlreadyFriend(user) {
                    removeFriendButton(for: user)
                } else if viewModel.isProcessing && viewModel.isSearching {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Request") { 
                        Task { await viewModel.sendFriendRequest(to: user, source: source) } 
                    }
                    .ufreeCompactButton(tint: .green)
                    .disabled(viewModel.isProcessing)
                }
            } else {
                removeFriendButton(for: user)
            }
        }
        .padding(.vertical, 4)
    }

    private func removeFriendButton(for user: UserProfile) -> some View {
        Button("Remove") {
            HapticManager.warning()
            friendPendingRemoval = user
        }
        .ufreeCompactButton(prominent: false, tint: .red)
        .disabled(viewModel.isProcessing)
        .accessibilityHint("Removes \(user.displayName) from your trusted circle")
    }
}

#Preview {
    let incomingRequest = FriendRequest(
        id: "req1",
        fromId: "user4",
        fromName: "Diana",
        toId: "currentUser",
        status: .pending,
        timestamp: Date()
    )
    
    let mockRepo = MockFriendRepository(
        discoveredUsers: [
            UserProfile(id: "user1", displayName: "Alice", hashedPhoneNumber: "abc123"),
            UserProfile(id: "user2", displayName: "Bob", hashedPhoneNumber: "def456")
        ],
        myFriends: [UserProfile(id: "user3", displayName: "Charlie", hashedPhoneNumber: "ghi789")],
        incomingRequests: [incomingRequest]
    )
    FriendsView(
        friendRepository: mockRepo,
        rootViewModel: RootViewModel(authRepository: MockAuthRepository())
    )
}
