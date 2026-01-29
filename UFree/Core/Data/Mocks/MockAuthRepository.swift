//
//  MockAuthRepository.swift
//  UFree
//
//  Created by Khang Vu on 31/12/25.
//

import Foundation

public actor MockAuthRepository: AuthRepository {
    private var user: User?
    private let authStateStream: AsyncStream<User?>
    private let authStateContinuation: AsyncStream<User?>.Continuation
    
    public init(user: User? = nil) {
        self.user = user
        
        // Set up the AsyncStream for auth state changes
        var continuation: AsyncStream<User?>.Continuation!
        let stream = AsyncStream<User?> { cont in
            continuation = cont
        }
        self.authStateStream = stream
        self.authStateContinuation = continuation
        
        // Emit initial state (nonisolated, so safe to use continuation)
        if let user = user {
            continuation.yield(user)
        }
    }
    
    public var currentUser: User? {
        get async {
            user
        }
    }
    
    nonisolated public var authState: AsyncStream<User?> {
        authStateStream
    }
    
    public func signInAnonymously() async throws -> User {
        let newUser = createUser(id: UUID().uuidString, isAnonymous: true, displayName: nil)
        self.user = newUser
        self.authStateContinuation.yield(newUser)
        return newUser
    }
    
    public func signOut() async throws {
        self.user = nil
        self.authStateContinuation.yield(nil)
    }
    
    public func updateDisplayName(_ name: String) async throws {
        guard let currentUser = user else {
            throw NSError(
                domain: "MockAuthRepository",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "No user logged in"]
            )
        }
        
        let updatedUser = createUser(id: currentUser.id, isAnonymous: currentUser.isAnonymous, displayName: name)
        self.user = updatedUser
        self.authStateContinuation.yield(updatedUser)
    }
    
    private func createUser(id: String, isAnonymous: Bool, displayName: String?) -> User {
        User(id: id, isAnonymous: isAnonymous, displayName: displayName)
    }
    
    #if DEBUG
    // MARK: - Debug Methods
    
    public func signInAsTestUser(phoneNumber: String) async throws -> User {
        let newUser = createUser(id: phoneNumber, isAnonymous: false, displayName: nil)
        self.user = newUser
        self.authStateContinuation.yield(newUser)
        return newUser
    }
    #endif
}
