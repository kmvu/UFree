//
//  RootViewModel.swift
//  UFree
//
//  Created by Khang Vu on 31/12/25.
//

import Foundation
import Combine

@MainActor
public final class RootViewModel: ObservableObject {
    // MARK: - Auth State
    enum AuthPhase {
        case loading           // Firebase checking for existing session
        case unauthenticated   // No user found, show login
        case authenticated     // User logged in, show main app
    }
    
    @Published var authPhase: AuthPhase = .loading
    @Published var currentUser: User? = nil
    @Published var isSigningIn = false
    @Published var errorMessage: String? = nil
    
    // Navigation / Deep Links
    @Published var deepLinkProfileId: String? = nil
    
    // Navigation Tabs
    public enum Tab {
        case schedule
        case feed
        case friends
    }
    @Published public var activeTab: Tab = .schedule
    
    // Feature ViewModels for navigation and cross-feature state
    @Published public var friendsScheduleViewModel: FriendsScheduleViewModel?
    @Published public var friendsViewModel: FriendsViewModel?
    
    private let authRepository: AuthRepository
    private var authStateTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    public init(authRepository: AuthRepository) {
        self.authRepository = authRepository
        setupAuthStateListener()
        setupDeepLinkObserver()
    }

    private func setupDeepLinkObserver() {
        NotificationCenter.default.publisher(for: .didReceiveProfileDeepLink)
            .compactMap { $0.object as? String }
            .sink { [weak self] userId in
                self?.deepLinkProfileId = userId
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Auth State Setup
    
    private func setupAuthStateListener() {
        authStateTask = Task {
            for await user in authRepository.authState {
                self.currentUser = user
                self.isSigningIn = false
                
                // Update authPhase based on whether user exists
                if user != nil {
                    self.authPhase = .authenticated
                } else {
                    self.authPhase = .unauthenticated
                }
            }
        }
    }
    
    // MARK: - Actions
    
    public func signInAnonymously() {
        Task {
            isSigningIn = true
            errorMessage = nil
            
            do {
                let user = try await authRepository.signInAnonymously()
                self.currentUser = user
            } catch {
                self.errorMessage = error.localizedDescription
            }
            
            isSigningIn = false
        }
    }
    
    public func signOut() {
        Task {
            do {
                try await authRepository.signOut()
                self.currentUser = nil
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    deinit {
        authStateTask?.cancel()
    }
}

// MARK: - Helper for Sheet Identification
extension String: @retroactive Identifiable {
    public var id: String { self }
}
