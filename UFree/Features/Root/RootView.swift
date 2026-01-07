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
    
    init(container: ModelContainer, authRepository: AuthRepository) {
        self.container = container
        self.authRepository = authRepository
        _rootViewModel = StateObject(wrappedValue: RootViewModel(authRepository: authRepository))
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
                        user: user
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
    }
}

// MARK: - Main App View (after login)

struct MainAppView: View {
    let container: ModelContainer
    let authRepository: AuthRepository
    @ObservedObject var rootViewModel: RootViewModel
    let user: User
    
    var body: some View {
        TabView {
            // MARK: - Schedule Tab
            ScheduleContainer(container: container, rootViewModel: rootViewModel)
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }
            
            // MARK: - Friends Feed Tab
            FriendsScheduleContainer(container: container)
                .tabItem {
                    Label("Feed", systemImage: "person.2.wave.vertical")
                }
            
            // MARK: - Add Friends Tab
            FriendsContainer(container: container)
                .tabItem {
                    Label("Add Friends", systemImage: "person.badge.plus")
                }
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

// MARK: - Friends Schedule Container (Dependency Injection)

struct FriendsScheduleContainer: View {
    let container: ModelContainer
    
    var body: some View {
        // Create repositories
        let availabilityRepo = CompositeAvailabilityRepository(
            local: SwiftDataAvailabilityRepository(container: container),
            remote: FirebaseAvailabilityRepository()
        )
        let contactsRepo = AppleContactsRepository()
        let friendRepo = FirebaseFriendRepository(contactsRepo: contactsRepo)
        
        // Pass repositories to the view
        return FriendsScheduleView(friendRepository: friendRepo, availabilityRepository: availabilityRepo)
    }
}

// MARK: - Friends Container (Dependency Injection)

struct FriendsContainer: View {
    let container: ModelContainer
    
    var body: some View {
        // Create repositories
        let contactsRepo = AppleContactsRepository()
        let friendRepo = FirebaseFriendRepository(contactsRepo: contactsRepo)
        
        // Pass repository to the view
        return FriendsView(friendRepository: friendRepo)
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
