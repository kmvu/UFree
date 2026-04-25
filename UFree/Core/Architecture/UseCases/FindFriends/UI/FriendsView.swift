//
//  FriendsView.swift
//  UFree
//
//  Created by Khang Vu on 05/01/26.
//

import SwiftUI

public struct FriendsView: View {
    @StateObject private var viewModel: FriendsViewModel

    public init(friendRepository: FriendRepositoryProtocol) {
        _viewModel = StateObject(wrappedValue: FriendsViewModel(friendRepository: friendRepository))
    }

    public var body: some View {
        NavigationStack {
            List {
                incomingRequestsSection
                myFriendsSection
                addFriendsSection
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
    private var incomingRequestsSection: some View {
        if !viewModel.incomingRequests.isEmpty {
            Section("Friend Requests") {
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
            Section("My Trusted Circle") {
                ForEach(viewModel.friends) { friend in
                    friendRow(for: friend, isDiscovered: false)
                        .swipeActions {
                            Button("Remove", role: .destructive) {
                                Task { await viewModel.removeFriend(friend) }
                            }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var addFriendsSection: some View {
        Section {
            // Search by Phone
            HStack(spacing: 8) {
                TextField("Find by Phone Number", text: $viewModel.searchText)
                    .keyboardType(.phonePad)
                    .submitLabel(.search)
                    .onSubmit { Task { await viewModel.performPhoneSearch() } }
                    .disabled(viewModel.isSearching)
                
                Button(action: {
                    HapticManager.medium()
                    Task { await viewModel.performPhoneSearch() }
                }) {
                    if viewModel.isSearching {
                        ProgressView().frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                }
                .disabled(viewModel.searchText.isEmpty || viewModel.isSearching)
            }
            .padding(.vertical, 4)
            
            // Search result or empty state button
            if let result = viewModel.searchResult {
                friendRow(for: result, isDiscovered: true)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if viewModel.discoveredUsers.isEmpty {
                Button(action: {
                    Task { await viewModel.findFriendsFromContacts() }
                }) {
                    Label("Sync Contacts", systemImage: "person.2.badge.gearshape")
                        .foregroundColor(.accentColor)
                }
            } else {
                ForEach(viewModel.discoveredUsers) { user in
                    friendRow(for: user, isDiscovered: true)
                }
            }
        } header: {
            Text("Add Friends")
        } footer: {
            Text("We hash your contacts securely. Raw phone numbers are never stored.")
                .font(.caption2)
        }
    }

    private func friendRow(for user: UserProfile, isDiscovered: Bool) -> some View {
        HStack(spacing: 12) {
            Circle().fill(isDiscovered ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay { 
                    Text(String(user.displayName.prefix(1)))
                        .font(.headline)
                        .foregroundColor(isDiscovered ? .green : .blue) 
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName).font(.headline)
                Text(isDiscovered ? "UFree Member" : "Connected").font(.caption).foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isDiscovered {
                if viewModel.isProcessing && viewModel.isSearching {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Request") { 
                        Task { await viewModel.sendFriendRequest(to: user) } 
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
    FriendsView(friendRepository: mockRepo)
}
