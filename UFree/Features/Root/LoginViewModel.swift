//
//  LoginViewModel.swift
//  UFree
//
//  Created by Khang Vu on 3/1/26.
//

import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    // MARK: - State
    @Published var name: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // MARK: - Dependencies
    private let authRepository: AuthRepository
    
    // MARK: - Init
    init(authRepository: AuthRepository) {
        self.authRepository = authRepository
    }
    
    // MARK: - Intent
    func loginTapped() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your name to start."
            showError = true
            return
        }
        
        Task {
            isLoading = true
            do {
                // 1. Sign In (Anonymous)
                _ = try await authRepository.signInAnonymously()
                
                // 2. Update Name (So friends know who this is)
                try await authRepository.updateDisplayName(name)
                
                // Success! RootView will automatically switch to MainAppView
                // because it's listening to 'authState'
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
    
    #if DEBUG
    // MARK: - Debug Methods
    
    /// Logs in as a test user with a whitelisted phone number (no SMS required)
    /// - Parameter index: 0 = User 1, 1 = User 2, 2 = User 3
    func loginAsTestUser(index: Int) {
        let testNumbers = [
            "+15550000001",
            "+15550000002",
            "+15550000003"
        ]
        
        guard index < testNumbers.count else { return }
        
        let phoneNumber = testNumbers[index]
        
        Task {
            isLoading = true
            do {
                // Firebase recognizes these whitelisted numbers and doesn't require SMS
                _ = try await authRepository.signInAsTestUser(phoneNumber: phoneNumber)
                
                // Update name to identify the test user
                let displayName = "Test User \(index + 1)"
                try await authRepository.updateDisplayName(displayName)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
    #endif
}
