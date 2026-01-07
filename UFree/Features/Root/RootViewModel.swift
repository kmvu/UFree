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
    
    private let authRepository: AuthRepository
    private var authStateTask: Task<Void, Never>?
    
    public init(authRepository: AuthRepository) {
        self.authRepository = authRepository
        setupAuthStateListener()
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
