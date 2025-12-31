//
//  RootViewModelTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 31/12/25.
//

import XCTest
import Combine
@testable import UFree

@MainActor
final class RootViewModelTests: XCTestCase {
    
    private var authRepository: MockAuthRepository!
    private var viewModel: RootViewModel!
    
    override func setUp() async throws {
        try await super.setUp()
        authRepository = MockAuthRepository()
        viewModel = RootViewModel(authRepository: authRepository)
    }
    
    // MARK: - Initial State
    
    func test_init_currentUserIsNil() {
        XCTAssertNil(viewModel.currentUser)
    }
    
    func test_init_isSigningInIsFalse() {
        XCTAssertFalse(viewModel.isSigningIn)
    }
    
    // MARK: - Sign In
    
    func test_signInAnonymously_setsCurrentUser() async throws {
        viewModel.signInAnonymously()
        
        // Wait for async operation
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5s
        
        XCTAssertNotNil(viewModel.currentUser)
        XCTAssertTrue(viewModel.currentUser?.isAnonymous ?? false)
    }
    
    func test_signInAnonymously_setsIsSigningInDuringOperation() {
        var wasSigningIn = false
        
        let observation = viewModel.$isSigningIn.sink { isSigningIn in
            if isSigningIn {
                wasSigningIn = true
            }
        }
        
        viewModel.signInAnonymously()
        
        // Give it a moment to observe the state change
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        XCTAssertTrue(wasSigningIn)
        observation.cancel()
    }
    
    func test_signInAnonymously_clearsErrorMessageOnSuccess() async throws {
        viewModel.errorMessage = "Previous error"
        
        viewModel.signInAnonymously()
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Sign Out
    
    func test_signOut_clearsCurrentUser() async throws {
        viewModel.signInAnonymously()
        try await Task.sleep(nanoseconds: 300_000_000)
        
        viewModel.signOut()
        try await Task.sleep(nanoseconds: 300_000_000)
        
        XCTAssertNil(viewModel.currentUser)
    }
    
    // MARK: - Auth State Stream
    
    func test_authStateListener_updatesCurrentUser() async throws {
        let user = try await authRepository.signInAnonymously()
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        XCTAssertEqual(viewModel.currentUser?.id, user.id)
    }
}
