//
//  AuthRepository.swift
//  UFree
//
//  Created by Khang Vu on 31/12/25.
//

import Foundation

public protocol AuthRepository {
    /// Returns the currently authenticated user, or nil if not signed in.
    var currentUser: User? { get async }
    
    /// Stream of auth state changes.
    /// This allows the UI to react instantly when a user logs in/out.
    var authState: AsyncStream<User?> { get }
    
    /// Signs in the user without requiring credentials.
    /// - Returns: The authenticated User entity.
    func signInAnonymously() async throws -> User
    
    /// Signs the user out.
    func signOut() async throws
    
    /// Updates the current user's display name.
    /// - Parameter name: The new display name to set.
    func updateDisplayName(_ name: String) async throws
}
