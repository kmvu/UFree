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

    /// Empty on purpose. A non-empty `@MainActor deinit` (or the synthesized MainActor
    /// deallocation path under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`) trips an
    /// iOS 26.2 XCTest bug: `pointer being freed was not allocated` at a fixed address.
    nonisolated deinit {}
    
    // MARK: - Intent

    /// Production path: Sign in with Apple (links an anonymous session when present).
    func loginTapped() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your name to start."
            showError = true
            return
        }

        Task {
            isLoading = true
            do {
                // 1. Sign in with Apple (or link to existing anonymous pilot UID).
                _ = try await authRepository.signInWithApple()
                
                // 2. Update Auth Name (nudges / Auth profile use displayName).
                try await authRepository.updateDisplayName(name)
                
                // 3. Update Firestore profile + optional phone discovery hashes.
                // Phone is optional: first-writer-wins directory claim can be squatted until OTP (Phase 7).
                let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                let hashes = trimmedPhone.isEmpty ? [] : CryptoUtils.phoneNumberHashes(for: trimmedPhone)
                try await friendRepository.saveUserProfile(
                    displayName: name,
                    hashedPhoneNumbers: hashes
                )
                
                // Success! RootView will automatically switch to MainAppView
            } catch let error as AppleSignInError where error == .cancelled {
                // User dismissed the sheet — don't show a failure alert.
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
    
    #if DEBUG
    // MARK: - Debug Methods
    
    /// Logs in as a distinct DEBUG persona (anonymous auth + fixed phone hash for discovery).
    /// SiwA is unavailable on Simulator — keep these buttons for multi-account testing.
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
                _ = try await authRepository.signInAsTestUser(phoneNumber: phoneNumber)
                
                let displayName = "Test User \(index + 1)"
                try await authRepository.updateDisplayName(displayName)
                
                // Same phone hashes production uses — enables Find by Phone between DEBUG users.
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
