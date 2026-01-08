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
        _rootViewModel = StateObject(wrappedValue: RootViewModel(authRepository: authRepository))

        // Create ViewModels early
        let availabilityRepo = CompositeAvailabilityRepository(
            local: SwiftDataAvailabilityRepository(container: container),
            remote: FirebaseAvailabilityRepository()
        )
        let contactsRepo = AppleContactsRepository()
        let friendRepo = FirebaseFriendRepository(contactsRepo: contactsRepo)
        self.friendRepository = friendRepo

        _friendsScheduleViewModel = StateObject(wrappedValue: FriendsScheduleViewModel(
            friendRepository: friendRepo,
            availabilityRepository: availabilityRepo,
            notificationRepository: FirebaseNotificationRepository()
        ))
        _friendsViewModel = StateObject(wrappedValue: FriendsViewModel(friendRepository: friendRepo))
        _notificationViewModel = StateObject(wrappedValue: NotificationViewModel(
            repository: FirebaseNotificationRepository()
        ))
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
                FriendsView(friendRepository: friendRepository)
                    .navigationTitle("Friends")
            }
            .tabItem {
                Label("Add Friends", systemImage: "person.badge.plus")
            }
        }
        .environment(\.notificationViewModel, notificationViewModel)
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
