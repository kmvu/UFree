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

    public init(friendRepository: FriendRepositoryProtocol, rootViewModel: RootViewModel) {
        self.rootViewModel = rootViewModel
        _viewModel = StateObject(wrappedValue: FriendsViewModel(friendRepository: friendRepository))
    }

    public var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        if let userId = rootViewModel.currentUser?.id {
                            DiscoveryCardView(viewModel: viewModel, userId: userId)
                            
                            shareInviteLinkButton(userId: userId)
                        }
                        
                        VStack(spacing: 12) {
                            incomingRequestsSection
                            myFriendsSection
                            suggestedFromContactsSection
                                .id("bottomOfPage")
                        }
                    }
                    .padding()
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
                viewModel.listenToRequests()
                await viewModel.loadFriends()
            }
            .onDisappear {
                viewModel.stopListening()
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
        }
    }

    @ViewBuilder
    private func shareInviteLinkButton(userId: String) -> some View {
        ShareLink(item: URL(string: "https://ufree.app/profile/\(userId)")!) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "link")
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Invite Anyone via Link")
                        .font(.headline)
                    Text("Connect to see each other's schedules")
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
                            Button("Accept") {
                                HapticManager.success()
                                Task { await viewModel.acceptRequest(request) }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .controlSize(.small)
                            
                            Button(role: .destructive) {
                                HapticManager.warning()
                                Task { await viewModel.declineRequest(request) }
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
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
                        .contextMenu {
                            Button(role: .destructive) {
                                Task { await viewModel.removeFriend(friend) }
                            } label: {
                                Label("Remove Friend", systemImage: "person.badge.minus")
                            }
                        }
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
                            .font(.subheadline).bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .cornerRadius(20)
                    }
                    .buttonStyle(InteractiveButtonStyle())
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
                Text(isDiscovered ? "UFree Member" : "Connected").font(.caption).foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isDiscovered {
                if viewModel.isProcessing && viewModel.isSearching {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Request") { 
                        Task { await viewModel.sendFriendRequest(to: user, source: source) } 
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.green)
                    .disabled(viewModel.isProcessing)
                }
            }
        }
        .padding(.vertical, 4)
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
