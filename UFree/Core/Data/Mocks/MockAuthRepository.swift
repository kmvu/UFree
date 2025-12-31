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
    
    nonisolated public init(user: User? = nil) {
        self.user = user
        
        // Set up the AsyncStream for auth state changes
        var continuation: AsyncStream<User?>.Continuation!
        let stream = AsyncStream<User?> { cont in
            continuation = cont
        }
        self.authStateStream = stream
        self.authStateContinuation = continuation
        
        // Emit initial state
        if let user = user {
            self.authStateContinuation.yield(user)
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
        let newUser = User(id: UUID().uuidString, isAnonymous: true)
        self.user = newUser
        self.authStateContinuation.yield(newUser)
        return newUser
    }
    
    public func signOut() async throws {
        self.user = nil
        self.authStateContinuation.yield(nil)
    }
}
