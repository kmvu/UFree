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
        let friendRepo = FirebaseFriendRepository()
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
                LoginView(viewModel: LoginViewModel(
                    authRepository: authRepository,
                    friendRepository: friendRepository
                ))
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
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    let container: ModelContainer
    let authRepository: AuthRepository
    @ObservedObject var rootViewModel: RootViewModel
    let user: User
    let friendRepository: FriendRepositoryProtocol
    let friendsScheduleViewModel: FriendsScheduleViewModel
    let friendsViewModel: FriendsViewModel
    @ObservedObject var notificationViewModel: NotificationViewModel

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                adaptiveSidebarLayout
            } else {
                tabBarLayout
            }
        }
        .sheet(item: $rootViewModel.deepLinkProfileId) { userId in
            // Profile Card View for Deep Links
            VStack(spacing: 20) {
                ProfileResolutionView(userId: userId, friendsViewModel: friendsViewModel)
                
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

    // MARK: - Layouts

    @ViewBuilder
    private var tabBarLayout: some View {
        TabView(selection: $rootViewModel.activeTab) {
            // MARK: - Schedule Tab
            NavigationStack {
                ScheduleContainer(container: container, rootViewModel: rootViewModel)
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Schedule", systemImage: "calendar")
            }
            .tag(RootViewModel.Tab.schedule)

            // MARK: - Friends Feed Tab
            NavigationStack {
                FriendsScheduleView(
                    viewModel: friendsScheduleViewModel,
                    rootViewModel: rootViewModel
                )
                .navigationTitle("Who's Free?")
                .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Feed", systemImage: "person.2.fill")
            }
            .tag(RootViewModel.Tab.feed)

            // MARK: - Add Friends Tab
            NavigationStack {
                FriendsView(
                    friendRepository: friendRepository,
                    rootViewModel: rootViewModel
                )
                .navigationTitle("Friends")
                .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Add Friends", systemImage: "person.badge.plus")
            }
            .tag(RootViewModel.Tab.friends)
        }
    }

    @ViewBuilder
    private var adaptiveSidebarLayout: some View {
        NavigationSplitView {
            List(selection: Binding(
                get: { rootViewModel.activeTab },
                set: { if let newValue = $0 { rootViewModel.activeTab = newValue } }
            )) {
                NavigationLink(value: RootViewModel.Tab.schedule) {
                    Label("Schedule", systemImage: "calendar")
                }
                NavigationLink(value: RootViewModel.Tab.feed) {
                    Label("Feed", systemImage: "person.2.fill")
                }
                NavigationLink(value: RootViewModel.Tab.friends) {
                    Label("Add Friends", systemImage: "person.badge.plus")
                }
            }
            .navigationTitle("UFree")
        } detail: {
            switch rootViewModel.activeTab {
            case .schedule:
                NavigationStack {
                    ScheduleContainer(container: container, rootViewModel: rootViewModel)
                }
            case .feed:
                NavigationStack {
                    FriendsScheduleView(
                        viewModel: friendsScheduleViewModel,
                        rootViewModel: rootViewModel
                    )
                    .navigationTitle("Who's Free?")
                }
            case .friends:
                NavigationStack {
                    FriendsView(
                        friendRepository: friendRepository,
                        rootViewModel: rootViewModel
                    )
                    .navigationTitle("Friends")
                }
            }
        }
    }
    
    // MARK: - Universal Links Handler
    
    /// Handles incoming Universal Links (App Site Association)
    /// Example: https://ufree.app/notification/user123
    private func handleUniversalLink(_ url: URL) {
        AnalyticsManager.logLinkOpened(url: url.absoluteString)
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

// MARK: - Profile Resolution for Deep Links

struct ProfileResolutionView: View {
    let userId: String
    @ObservedObject var friendsViewModel: FriendsViewModel
    @State private var resolvedUser: UserProfile?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView("Finding user...")
            } else if let user = resolvedUser {
                Circle().fill(Color.blue.opacity(0.1)).frame(width: 80, height: 80)
                    .overlay {
                        Text(String(user.displayName.prefix(1)))
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.blue)
                    }
                
                Text(user.displayName).font(.headline)
                Text("Connect on UFree").font(.subheadline).foregroundStyle(.secondary)
                
                Button("Send Friend Request") {
                    Task {
                        await friendsViewModel.sendFriendRequest(to: user, source: "deep_link")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(friendsViewModel.isProcessing)
            } else {
                Image(systemName: "person.fill.questionmark")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                
                Text(errorMessage ?? "User not found").font(.headline)
                Text("The link might be invalid or the user may have deleted their account.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            await resolveUser()
        }
    }
    
    private func resolveUser() async {
        do {
            resolvedUser = try await friendsViewModel.friendRepository.findUserById(userId)
            isLoading = false
        } catch {
            errorMessage = "Failed to load profile"
            isLoading = false
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
