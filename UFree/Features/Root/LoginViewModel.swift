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
}
