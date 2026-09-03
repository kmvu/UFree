//
//  SettingsViewModel.swift
//  UFree
//
//  Created by Khang Vu on 17/06/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var displayName: String = ""
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isSaveSuccessful: Bool = false
    @Published var isDeleteSuccessful: Bool = false
    @Published var showDeleteConfirmation: Bool = false

    private let authRepository: AuthRepository
    private let friendRepository: FriendRepositoryProtocol
    private let wipeLocalData: () async -> Void
    
    init(
        authRepository: AuthRepository,
        friendRepository: FriendRepositoryProtocol,
        wipeLocalData: @escaping () async -> Void = {}
    ) {
        self.authRepository = authRepository
        self.friendRepository = friendRepository
        self.wipeLocalData = wipeLocalData
    }

    /// Empty `nonisolated` deinit works around a Swift 6.2 / iOS 26.2 XCTest bug where
    /// MainActor-isolated class teardown aborts with "pointer being freed was not allocated".
    nonisolated deinit {}
    
    func loadInitialData() async {
        if let user = await authRepository.currentUser {
            self.displayName = user.displayName ?? ""
        }
    }
    
    func saveProfile() async {
        guard !isProcessing else { return }
        
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a display name"
            HapticManager.warning()
            return
        }
        
        isProcessing = true
        errorMessage = nil
        
        do {
            // Keep Auth profile aligned with Firestore — nudges read Auth.displayName.
            try await authRepository.updateDisplayName(displayName)

            // Pass empty array — display-name-only update preserves any existing hashes
            // already stored in Firestore (merge: true in the repository implementation).
            try await friendRepository.saveUserProfile(displayName: displayName, hashedPhoneNumbers: [])
            
            // Trigger haptic and success state
            HapticManager.success()
            isSaveSuccessful = true
            isProcessing = false
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.warning()
            isProcessing = false
        }
    }

    func requestAccountDeletion() {
        showDeleteConfirmation = true
    }

    /// App Store account deletion: SiwA re-auth → wipe Firestore tree → Auth delete → local wipe.
    func deleteAccount() async {
        guard !isProcessing else { return }
        isProcessing = true
        errorMessage = nil
        showDeleteConfirmation = false

        do {
            let user = await authRepository.currentUser
            #if DEBUG
            // DEBUG simulator personas are anonymous (no SiwA). Skip Apple re-auth.
            if user?.isAnonymous != true {
                try await authRepository.reauthenticateWithApple()
            }
            #else
            _ = user
            try await authRepository.reauthenticateWithApple()
            #endif

            try await friendRepository.deleteAccountData()
            try await authRepository.deleteAccount()
            await wipeLocalData()

            HapticManager.success()
            isDeleteSuccessful = true
            isProcessing = false
        } catch let error as AppleSignInError where error == .cancelled {
            isProcessing = false
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.warning()
            isProcessing = false
        }
    }
}
