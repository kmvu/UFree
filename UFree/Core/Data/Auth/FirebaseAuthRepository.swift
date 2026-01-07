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
    private let auth: Auth
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    // AsyncStream for auth state changes
    private let authStateStream: AsyncStream<User?>
    private let authStateContinuation: AsyncStream<User?>.Continuation
    
    public init(auth: Auth = Auth.auth()) {
        self.auth = auth
        
        // Set up the AsyncStream for auth state changes
        var continuation: AsyncStream<User?>.Continuation!
        let stream = AsyncStream<User?> { cont in
            continuation = cont
        }
        self.authStateStream = stream
        self.authStateContinuation = continuation
        
        // Listen to auth state changes
        setupAuthStateListener()
    }
    
    deinit {
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
}
