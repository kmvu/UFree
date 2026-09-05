//
//  FirebaseAuthRepository.swift
//  UFree
//
//  Created by Khang Vu on 31/12/25.
//

import Foundation
import FirebaseAuth

@MainActor
public final class FirebaseAuthRepository: AuthRepository {
    /// Touched from `nonisolated deinit`, so it cannot be MainActor-isolated storage.
    nonisolated(unsafe) private let auth: Auth
    /// `nonisolated(unsafe)` so `deinit` can unregister without hopping to the MainActor.
    /// A non-empty `@MainActor deinit` trips a Swift 6.2 / iOS 26.2 XCTest bug
    /// (`swift_task_deinitOnExecutorImpl` → "pointer being freed was not allocated").
    nonisolated(unsafe) private var authStateHandle: AuthStateDidChangeListenerHandle?

    private let appleSignIn: AppleSignInCoordinator
    
    // AsyncStream for auth state changes
    private let authStateStream: AsyncStream<User?>
    private let authStateContinuation: AsyncStream<User?>.Continuation
    
    public init(auth: Auth = Auth.auth()) {
        self.auth = auth
        self.appleSignIn = AppleSignInCoordinator()
        
        // Newest-only buffer so a lagged sign-in emission cannot outrun sign-out.
        var continuation: AsyncStream<User?>.Continuation!
        let stream = AsyncStream<User?>(bufferingPolicy: .bufferingNewest(1)) { cont in
            continuation = cont
        }
        self.authStateStream = stream
        self.authStateContinuation = continuation
        
        // Listen to auth state changes
        setupAuthStateListener()
    }
    
    nonisolated deinit {
        if let handle = authStateHandle {
            auth.removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - AuthRepository conformance
    
    public var currentUser: User? {
        get async {
            guard let firebaseUser = auth.currentUser else {
                return nil
            }
            return mapFirebaseUserToUser(firebaseUser)
        }
    }
    
    nonisolated public var authState: AsyncStream<User?> {
        authStateStream
    }

    public func signInWithApple() async throws -> User {
        let apple = try await appleSignIn.signIn()
        let credential = OAuthProvider.appleCredential(
            withIDToken: apple.idToken,
            rawNonce: apple.rawNonce,
            fullName: apple.fullName
        )

        let firebaseUser: FirebaseAuth.User
        if let existing = auth.currentUser, existing.isAnonymous {
            // Preserve pilot UIDs / friend graphs by linking Apple to the anonymous session.
            let result = try await existing.link(with: credential)
            firebaseUser = result.user
        } else {
            let result = try await auth.signIn(with: credential)
            firebaseUser = result.user
        }

        let user = mapFirebaseUserToUser(firebaseUser)
        authStateContinuation.yield(user)
        return user
    }

    public func reauthenticateWithApple() async throws {
        guard let firebaseUser = auth.currentUser else {
            throw NSError(
                domain: "FirebaseAuthRepository",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "No user logged in"]
            )
        }

        let apple = try await appleSignIn.signIn()
        let credential = OAuthProvider.appleCredential(
            withIDToken: apple.idToken,
            rawNonce: apple.rawNonce,
            fullName: apple.fullName
        )
        _ = try await firebaseUser.reauthenticate(with: credential)
    }

    public func deleteAccount() async throws {
        guard let firebaseUser = auth.currentUser else {
            throw NSError(
                domain: "FirebaseAuthRepository",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "No user logged in"]
            )
        }
        try await firebaseUser.delete()
        authStateContinuation.yield(nil)
    }
    
    public func signInAnonymously() async throws -> User {
        let result = try await auth.signInAnonymously()
        let user = mapFirebaseUserToUser(result.user)
        authStateContinuation.yield(user)
        return user
    }
    
    public func signOut() async throws {
        try auth.signOut()
        authStateContinuation.yield(nil)
    }
    
    public func updateDisplayName(_ name: String) async throws {
        guard let firebaseUser = auth.currentUser else {
            throw NSError(
                domain: "FirebaseAuthRepository",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "No user logged in"]
            )
        }
        
        let request = firebaseUser.createProfileChangeRequest()
        request.displayName = name
        try await request.commitChanges()
        
        // Emit the updated user via the stream
        let updatedUser = mapFirebaseUserToUser(firebaseUser)
        authStateContinuation.yield(updatedUser)
    }
    
    // MARK: - Private
    
    private func setupAuthStateListener() {
        authStateHandle = auth.addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self = self else { return }
            
            let user: User? = firebaseUser.map { self.mapFirebaseUserToUser($0) }
            self.authStateContinuation.yield(user)
        }
    }
    
    private func mapFirebaseUserToUser(_ firebaseUser: FirebaseAuth.User) -> User {
        User(id: firebaseUser.uid, isAnonymous: firebaseUser.isAnonymous, displayName: firebaseUser.displayName)
    }
    
    #if DEBUG
    // MARK: - Debug Methods
    
    /// DEBUG multi-account helper: anonymous Firebase Auth (SiwA is unavailable on Simulator).
    ///
    /// Avoids Phone Auth’s APNs / reCAPTCHA / URL-scheme requirements, which are unreliable on
    /// Simulator. `phoneNumber` is unused here — `LoginViewModel` attaches discoverable phone
    /// hashes via `saveUserProfile` after sign-in.
    public func signInAsTestUser(phoneNumber: String) async throws -> User {
        _ = phoneNumber
        if auth.currentUser != nil {
            try auth.signOut()
            authStateContinuation.yield(nil)
        }
        return try await signInAnonymously()
    }
    #endif
}
