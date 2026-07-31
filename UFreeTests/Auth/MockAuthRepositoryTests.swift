//
//  MockAuthRepositoryTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 31/12/25.
//

import XCTest
@testable import UFree

final class MockAuthRepositoryTests: XCTestCase {
    
    private var repository: MockAuthRepository!
    
    override func setUp() async throws {
        try await super.setUp()
        repository = MockAuthRepository()
    }
    
    // MARK: - Initial State
    
    func test_initialState_currentUserIsNil() async {
        let currentUser = await repository.currentUser
        
        XCTAssertNil(currentUser)
    }
    
    func test_init_withUser_setsCurrentUser() async {
        let user = User(id: "test-123", isAnonymous: true)
        let repo = MockAuthRepository(user: user)
        
        let currentUser = await repo.currentUser
        
        XCTAssertEqual(currentUser, user)
    }
    
    // MARK: - Sign In
    
    func test_signInAnonymously_returnsUser() async throws {
        let user = try await repository.signInAnonymously()
        
        XCTAssertTrue(user.isAnonymous)
        XCTAssertFalse(user.id.isEmpty)
    }
    
    func test_signInAnonymously_setsCurrentUser() async throws {
        let user = try await repository.signInAnonymously()
        let currentUser = await repository.currentUser
        
        XCTAssertEqual(user.id, currentUser?.id)
    }
    
    func test_signInAnonymously_multipleCallsCreateDifferentUsers() async throws {
        let user1 = try await repository.signInAnonymously()
        let user2 = try await repository.signInAnonymously()
        
        XCTAssertNotEqual(user1.id, user2.id)
    }
    
    // MARK: - Sign Out
    
    func test_signOut_clearsCurrentUser() async throws {
        _ = try await repository.signInAnonymously()
        
        try await repository.signOut()
        let currentUser = await repository.currentUser
        
        XCTAssertNil(currentUser)
    }
    
    // MARK: - Update Display Name
    
    func test_updateDisplayName_withSignedInUser_updatesCurrentUser() async throws {
        _ = try await repository.signInAnonymously()
        
        try await repository.updateDisplayName("Alice")
        let currentUser = await repository.currentUser
        
        XCTAssertEqual(currentUser?.displayName, "Alice")
    }
    
    func test_updateDisplayName_preservesIdentityAndAnonymousFlag() async throws {
        let original = try await repository.signInAnonymously()
        
        try await repository.updateDisplayName("Alice")
        let currentUser = await repository.currentUser
        
        XCTAssertEqual(currentUser?.id, original.id)
        XCTAssertEqual(currentUser?.isAnonymous, original.isAnonymous)
    }
    
    func test_updateDisplayName_withoutSignedInUser_throwsUnauthorized() async {
        do {
            try await repository.updateDisplayName("Alice")
            XCTFail("Expected updateDisplayName to throw when no user is signed in")
        } catch {
            XCTAssertEqual((error as NSError).code, 401)
        }
    }
    
    // MARK: - Test User Sign In
    
    func test_signInAsTestUser_usesPhoneNumberAsIdentity() async throws {
        let user = try await repository.signInAsTestUser(phoneNumber: "555-1234")
        
        XCTAssertEqual(user.id, "555-1234")
        XCTAssertFalse(user.isAnonymous)
        XCTAssertNil(user.displayName)
    }
    
    func test_signInAsTestUser_setsCurrentUser() async throws {
        let user = try await repository.signInAsTestUser(phoneNumber: "555-1234")
        let currentUser = await repository.currentUser
        
        XCTAssertEqual(currentUser?.id, user.id)
    }
    
    // MARK: - Auth State Stream
    
    func test_authState_providesAccessToStream() async {
        let authState = await repository.authState
        
        // Stream is accessible and not nil
        XCTAssertNotNil(authState)
    }
    
    func test_authState_emitsUserAfterSignIn() async throws {
        var emittedUser: User? = nil
        
        let signedInUser = try await repository.signInAnonymously()
        
        for await user in repository.authState {
            if user != nil {
                emittedUser = user
                break
            }
        }
        
        XCTAssertEqual(emittedUser?.id, signedInUser.id)
    }
    
    func test_authState_emitsNilAfterSignOut() async throws {
        _ = try await repository.signInAnonymously()
        
        var emittedNil = false
        
        let task = Task {
            var emissionCount = 0
            for await user in repository.authState {
                emissionCount += 1
                // After sign out (second sign-in then sign-out), expect nil
                if emissionCount > 1 && user == nil {
                    emittedNil = true
                    break
                }
            }
        }
        
        try await repository.signOut()
        
        // Yield to allow task to process the emission
        let startDate = Date()
        while !emittedNil && Date().timeIntervalSince(startDate) < 1.0 {
            await Task.yield()
        }
        task.cancel()
        
        XCTAssertTrue(emittedNil)
    }
    
    // MARK: - Protocol Conformance
    
    func test_conformsToAuthRepository() {
        let proto: AuthRepository = repository
        XCTAssertNotNil(proto)
    }
}
