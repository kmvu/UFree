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
        await viewModel.signInAnonymously().value
        
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
        
        // Don't await the task here, we want to observe state during execution
        let task = viewModel.signInAnonymously()
        
        // Wait for the synchronous publish to hit our sink before the task finishes
        XCTAssertTrue(wasSigningIn)
        observation.cancel()
    }
    
    func test_signInAnonymously_clearsErrorMessageOnSuccess() async throws {
        viewModel.errorMessage = "Previous error"
        
        await viewModel.signInAnonymously().value
        
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Sign Out
    
    func test_signOut_clearsCurrentUser() async throws {
        await viewModel.signInAnonymously().value
        await viewModel.signOut().value
        
        XCTAssertNil(viewModel.currentUser)
    }
    
    // MARK: - Auth State Stream
    
    func test_authStateListener_updatesCurrentUser() async throws {
        let user = try await authRepository.signInAnonymously()
        
        // Wait for the ViewModel's authState listener task to pick up the emission
        // Since we are mocking the stream, we can yield to the runloop to let the AsyncStream process
        await Task.yield()
        
        // Let's ensure we wait deterministically until the user matches
        let startDate = Date()
        while viewModel.currentUser?.id != user.id && Date().timeIntervalSince(startDate) < 1.0 {
            await Task.yield()
        }
        
        XCTAssertEqual(viewModel.currentUser?.id, user.id)
    }

    // MARK: - Deep Links

    func test_deepLinkNotification_setsProfileId() {
        let expectation = XCTestExpectation(description: "Wait for property update")
        
        let cancellable = viewModel.$deepLinkProfileId
            .dropFirst()
            .sink { profileId in
                if profileId == "test_user_id" {
                    expectation.fulfill()
                }
            }
        
        NotificationCenter.default.post(name: .didReceiveProfileDeepLink, object: "test_user_id")
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(viewModel.deepLinkProfileId, "test_user_id")
        cancellable.cancel()
    }
}
