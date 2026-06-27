//
//  LoginViewModel.swift
//  UFree
//
//  Created by Khang Vu on 3/1/26.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class LoginViewModel: ObservableObject {
    // MARK: - State
    @Published var name: String = ""
    @Published var phoneNumber: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // MARK: - Dependencies
    private let authRepository: AuthRepository
    private let friendRepository: FriendRepositoryProtocol
    
    // MARK: - Init
    init(authRepository: AuthRepository, friendRepository: FriendRepositoryProtocol? = nil) {
        self.authRepository = authRepository
        // In a real app, we'd use a container or factory. For now, we default to Firebase if not provided.
        self.friendRepository = friendRepository ?? FirebaseFriendRepository()
    }
    
    // MARK: - Intent
    func loginTapped() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your name to start."
            showError = true
            return
        }
        
        guard !phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your phone number to find friends."
            showError = true
            return
        }
        
        Task {
            isLoading = true
            do {
                // 1. Sign In (Anonymous)
                _ = try await authRepository.signInAnonymously()
                
                // 2. Update Auth Name (for Firebase Auth profile)
                try await authRepository.updateDisplayName(name)
                
                // 3. Update Firestore Profile.
                // Generate all candidate hashes (covers local + E.164 variants) so that
                // friends who have this number stored in a different format still match.
                let hashes = CryptoUtils.phoneNumberHashes(for: phoneNumber)
                try await friendRepository.saveUserProfile(
                    displayName: name,
                    hashedPhoneNumbers: hashes
                )
                
                // Success! RootView will automatically switch to MainAppView
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
                
                // Also update Firestore profile for test users so they are discoverable
                let hashes = CryptoUtils.phoneNumberHashes(for: phoneNumber)
                try await friendRepository.saveUserProfile(
                    displayName: displayName,
                    hashedPhoneNumbers: hashes
                )
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
    #endif
}
