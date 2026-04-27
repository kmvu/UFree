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

    public init(friendRepository: FriendRepositoryProtocol, rootViewModel: RootViewModel) {
        self.rootViewModel = rootViewModel
        _viewModel = StateObject(wrappedValue: FriendsViewModel(friendRepository: friendRepository))
    }

    public var body: some View {
        NavigationStack {
            List {
                qrShortcutSection
                incomingRequestsSection
                myFriendsSection
                addFriendsSection
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.medium()
                        viewModel.showQRScanner = true
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showQRScanner) {
                QRScannerView(scannedCode: $viewModel.scannedCode)
                    .ignoresSafeArea()
                    .overlay(alignment: .topTrailing) {
                        Button {
                            viewModel.showQRScanner = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                        }
                    }
            }
            .sheet(isPresented: $viewModel.showMyQR) {
                if let qrImage = viewModel.qrImage {
                    VStack(spacing: 20) {
                        Text("Your UFree Handshake").font(.title2).bold()
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                        Text("Friends can scan this to add you instantly").font(.caption).foregroundStyle(.secondary)
                        Button("Done") { viewModel.showMyQR = false }.buttonStyle(.bordered)
                    }
                    .padding()
                }
            }
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
    private var qrShortcutSection: some View {
        Section {
            HStack {
                Button {
                    HapticManager.medium()
                    if let userId = rootViewModel.currentUser?.id {
                        viewModel.generateMyQRCode(from: userId)
                        viewModel.showMyQR = true
                    }
                } label: {
                    Label("My Handshake QR", systemImage: "qrcode")
                }
                
                Spacer()
                
                if let userId = rootViewModel.currentUser?.id {
                    ShareLink(item: URL(string: "https://ufree.app/profile/\(userId)")!) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
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
                friendRow(for: result, isDiscovered: true, source: "manual")
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
                    friendRow(for: user, isDiscovered: true, source: "contact_sync")
                }
            }
        } header: {
            Text("Add Friends")
        } footer: {
            Text("We hash your contacts securely. Raw phone numbers are never stored.")
                .font(.caption2)
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
