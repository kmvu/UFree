//
//  RootView.swift
//  UFree
//
//  Created by Khang Vu on 31/12/25.
//

import SwiftUI
import SwiftData

struct RootView: View {
    let container: ModelContainer
    let authRepository: AuthRepository

    @StateObject private var rootViewModel: RootViewModel
    @StateObject private var friendsScheduleViewModel: FriendsScheduleViewModel
    @StateObject private var friendsViewModel: FriendsViewModel
    @StateObject private var notificationViewModel: NotificationViewModel
    let friendRepository: FriendRepositoryProtocol

    init(container: ModelContainer, authRepository: AuthRepository) {
        self.container = container
        self.authRepository = authRepository

        // 1. Setup Repositories
        let availabilityRepo = CompositeAvailabilityRepository(
            local: SwiftDataAvailabilityRepository(container: container),
            remote: FirebaseAvailabilityRepository()
        )
        let contactsRepo = AppleContactsRepository()
        let friendRepo = FirebaseFriendRepository(contactsRepo: contactsRepo)
        self.friendRepository = friendRepo
        let notificationRepo = FirebaseNotificationRepository()

        // 2. Instantiate ViewModels (Non-StateObject versions for injection)
        let friendsScheduleVM = FriendsScheduleViewModel(
            friendRepository: friendRepo,
            availabilityRepository: availabilityRepo,
            notificationRepository: notificationRepo
        )
        let friendsVM = FriendsViewModel(friendRepository: friendRepo)
        let notificationVM = NotificationViewModel(repository: notificationRepo)
        let rootVM = RootViewModel(authRepository: authRepository)

        // 3. Inject dependencies into Root
        rootVM.friendsScheduleViewModel = friendsScheduleVM
        rootVM.friendsViewModel = friendsVM

        // 4. Wrap in StateObjects for SwiftUI lifecycle
        _rootViewModel = StateObject(wrappedValue: rootVM)
        _friendsScheduleViewModel = StateObject(wrappedValue: friendsScheduleVM)
        _friendsViewModel = StateObject(wrappedValue: friendsVM)
        _notificationViewModel = StateObject(wrappedValue: notificationVM)
    }

    var body: some View {
        Group {
            switch rootViewModel.authPhase {
            case .loading:
                SplashView()
                    .transition(.opacity)

            case .unauthenticated:
                LoginView(viewModel: LoginViewModel(authRepository: authRepository))
                    .transition(.opacity)

            case .authenticated:
                // Wait for displayName to be available before showing main app
                if let user = rootViewModel.currentUser,
                   let displayName = user.displayName, !displayName.isEmpty {
                    MainAppView(
                        container: container,
                        authRepository: authRepository,
                        rootViewModel: rootViewModel,
                        user: user,
                        friendRepository: friendRepository,
                        friendsScheduleViewModel: friendsScheduleViewModel,
                        friendsViewModel: friendsViewModel,
                        notificationViewModel: notificationViewModel
                    )
                    .transition(.opacity)
                } else {
                    // Still waiting for displayName to load
                    SplashView()
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeOut(duration: 0.3), value: rootViewModel.authPhase)
        .animation(.easeOut(duration: 0.3), value: rootViewModel.currentUser?.displayName)
        .onChange(of: rootViewModel.authPhase) { oldPhase, newPhase in
            if newPhase == .authenticated {
                Task {
                    await friendsScheduleViewModel.loadFriendsSchedules()
                    await friendsViewModel.loadFriends()
                }
            }
        }
    }
}

// MARK: - Main App View (after login)

struct MainAppView: View {
    let container: ModelContainer
    let authRepository: AuthRepository
    @ObservedObject var rootViewModel: RootViewModel
    let user: User
    let friendRepository: FriendRepositoryProtocol
    let friendsScheduleViewModel: FriendsScheduleViewModel
    let friendsViewModel: FriendsViewModel
    @ObservedObject var notificationViewModel: NotificationViewModel

    var body: some View {
        TabView {
            // MARK: - Schedule Tab
            NavigationStack {
                ScheduleContainer(container: container, rootViewModel: rootViewModel)
            }
            .tabItem {
                Label("Schedule", systemImage: "calendar")
            }

            // MARK: - Friends Feed Tab
            NavigationStack {
                FriendsScheduleView(viewModel: friendsScheduleViewModel)
                    .navigationTitle("Who's Free?")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Feed", systemImage: "person.2.fill")
            }

            // MARK: - Add Friends Tab
            NavigationStack {
                FriendsView(
                    friendRepository: friendRepository,
                    rootViewModel: rootViewModel
                )
                .navigationTitle("Friends")
            }
            .tabItem {
                Label("Add Friends", systemImage: "person.badge.plus")
            }
        }
        .sheet(item: $rootViewModel.deepLinkProfileId) { userId in
            // Profile Card View for Deep Links
            VStack(spacing: 20) {
                Circle().fill(Color.blue.opacity(0.1)).frame(width: 80, height: 80)
                    .overlay { Image(systemName: "person.fill").font(.system(size: 40)).foregroundColor(.blue) }
                
                Text("Connect on UFree").font(.headline)
                Text("User ID: \(userId)").font(.caption).foregroundStyle(.secondary)
                
                Button("Send Friend Request") {
                    let placeholderUser = UserProfile(id: userId, displayName: "UFree User", hashedPhoneNumber: "")
                    Task {
                        await friendsViewModel.sendFriendRequest(to: placeholderUser, source: "deep_link")
                        rootViewModel.deepLinkProfileId = nil
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Button("Cancel") { rootViewModel.deepLinkProfileId = nil }.foregroundStyle(.secondary)
            }
            .padding()
            .presentationDetents([.medium])
        }
        .environment(\.notificationViewModel, notificationViewModel)
        .onOpenURL { url in
            handleUniversalLink(url)
        }
    }
    
    // MARK: - Universal Links Handler
    
    /// Handles incoming Universal Links (App Site Association)
    /// Example: https://ufree.app/notification/user123
    private func handleUniversalLink(_ url: URL) {
        let deepLink = DeepLink.parse(url)
        
        switch deepLink {
        case .notification(let userId):
            // Navigate to notification center and highlight sender
            notificationViewModel.highlightedSenderId = userId
            
        case .profile(let userId):
            // Trigger profile sheet via RootViewModel
            rootViewModel.deepLinkProfileId = userId
            
        case .unknown:
            print("Unknown deep link: \(url)")
        }
    }
}

// MARK: - Deep Link Parser

enum DeepLink {
    case notification(senderId: String)
    case profile(userId: String)
    case unknown
    
    /// Parses Universal Link URLs into navigation actions
    /// - Parameter url: Universal Link URL (e.g., https://ufree.app/notification/user123)
    static func parse(_ url: URL) -> DeepLink {
        let components = url.pathComponents.filter { $0 != "/" }
        
        guard components.count >= 2 else {
            return .unknown
        }
        
        let pathType = components[0]
        let parameter = components[1]
        
        switch pathType {
        case "notification":
            return .notification(senderId: parameter)
        case "profile":
            return .profile(userId: parameter)
        default:
            return .unknown
        }
    }
}

// MARK: - Schedule Container (Dependency Injection)

struct ScheduleContainer: View {
    let container: ModelContainer
    @ObservedObject var rootViewModel: RootViewModel

    var body: some View {
        // Create the persistent repository and remote repository
        let localRepository = SwiftDataAvailabilityRepository(container: container)
        let remoteRepository = FirebaseAvailabilityRepository()

        // Orchestrate with offline-first composite pattern
        let repository = CompositeAvailabilityRepository(local: localRepository, remote: remoteRepository)

        // Inject Repository into the Use Case
        let useCase = UpdateMyStatusUseCase(repository: repository)

        // Inject Use Case and Repository into the ViewModel
        let viewModel = MyScheduleViewModel(updateUseCase: useCase, repository: repository)

        // Pass ViewModel to the View
        return MyScheduleView(viewModel: viewModel, rootViewModel: rootViewModel)
    }
}

#Preview {
    RootView(
        container: {
            do {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                return try ModelContainer(for: PersistentDayAvailability.self, configurations: config)
            } catch {
                fatalError("Failed to create preview container")
            }
        }(),
        authRepository: MockAuthRepository()
    )
}
