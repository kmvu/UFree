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
        if let user = rootViewModel.currentUser {
            // User is authenticated, show the main app
            MainAppView(
                container: container,
                authRepository: authRepository,
                rootViewModel: rootViewModel,
                user: user
            )
        } else {
            // User is not authenticated, show login
            LoginView(viewModel: rootViewModel)
        }
    }
}

// MARK: - Main App View (after login)

struct MainAppView: View {
    let container: ModelContainer
    let authRepository: AuthRepository
    @ObservedObject var rootViewModel: RootViewModel
    let user: User
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Main schedule view
                ScheduleContainer(container: container, rootViewModel: rootViewModel)
            }
        }
    }
}

// MARK: - Schedule Container (Dependency Injection)

struct ScheduleContainer: View {
    let container: ModelContainer
    let rootViewModel: RootViewModel
    
    var body: some View {
        // Create the persistent repository
        let repository = SwiftDataAvailabilityRepository(container: container)
        
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
