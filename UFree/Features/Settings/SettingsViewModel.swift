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
    
    private let authRepository: AuthRepository
    private let friendRepository: FriendRepositoryProtocol
    
    init(authRepository: AuthRepository, friendRepository: FriendRepositoryProtocol) {
        self.authRepository = authRepository
        self.friendRepository = friendRepository
    }
    
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
}
