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
                // MARK: - Search by Phone Number
                Section("Find by Phone Number") {
                    HStack(spacing: 8) {
                        TextField("Enter phone number", text: $viewModel.searchText)
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
                    
                    // Show result if found
                    if let result = viewModel.searchResult {
                        HStack(spacing: 12) {
                            Circle().fill(Color.green.opacity(0.2)).frame(width: 40, height: 40)
                                .overlay { Text(String(result.displayName.prefix(1))).font(.headline).foregroundColor(.green) }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.displayName).font(.headline)
                                Text("Found by phone").font(.caption).foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Add") {
                                HapticManager.success()
                                Task { await viewModel.addFriend(result) }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // MARK: - Incoming Requests
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

                Section {
                    if viewModel.discoveredUsers.isEmpty {
                        Button(action: {
                            Task { await viewModel.findFriendsFromContacts() }
                        }) {
                            Label("Sync Contacts to Find Friends", systemImage: "person.2.badge.gearshape")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
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

    private func friendRow(for user: UserProfile, isDiscovered: Bool) -> some View {
        HStack(spacing: 12) {
            Circle().fill(Color.blue.opacity(0.2)).frame(width: 40, height: 40)
                .overlay { Text(String(user.displayName.prefix(1))).font(.headline).foregroundColor(.blue) }
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName).font(.headline)
                Text(isDiscovered ? "From Contacts" : "Connected").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if isDiscovered {
                Button("Add") { Task { await viewModel.addFriend(user) } }
                    .buttonStyle(.borderedProminent).controlSize(.small)
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
