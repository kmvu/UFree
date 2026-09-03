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

    /// Signs in with Apple. Links an existing anonymous session when present so
    /// pilot UIDs and friend graphs are preserved.
    /// - Returns: The authenticated User entity.
    func signInWithApple() async throws -> User

    /// Re-authenticates the current user with Apple (required before account deletion).
    func reauthenticateWithApple() async throws

    /// Deletes the Firebase Auth user. Caller must wipe Firestore data first and
    /// re-authenticate when Firebase requires a recent login.
    func deleteAccount() async throws

    /// Legacy anonymous sign-in. Production login uses Sign in with Apple; this remains
    /// for DEBUG simulator personas and existing unit tests.
    func signInAnonymously() async throws -> User
    
    /// Signs the user out.
    func signOut() async throws
    
    /// Updates the current user's display name (Firebase Auth profile).
    /// - Parameter name: The new display name to set.
    func updateDisplayName(_ name: String) async throws
    
    #if DEBUG
    /// DEBUG multi-account helper. Implementations use anonymous auth; `phoneNumber` identifies
    /// which test persona the UI will attach (display name + hashed phone for discovery).
    /// - Parameter phoneNumber: Test phone number (e.g., "+15550000001")
    func signInAsTestUser(phoneNumber: String) async throws -> User
    #endif
}
