//
//  RootViewModelAuthPhaseTests.swift
//  UFreeTests
//
//  Created by Cline on 06/28/26.
//

import XCTest
@testable import UFree

@MainActor
final class RootViewModelAuthPhaseTests: XCTestCase {
    
    private var authRepository: MockAuthRepository!
    private var viewModel: RootViewModel!
    
    override func setUp() async throws {
        try await super.setUp()
        authRepository = MockAuthRepository()
        viewModel = RootViewModel(authRepository: authRepository)
        trackForMemoryLeaks(viewModel)
    }

    override func tearDown() async throws {
        viewModel = nil
        authRepository = nil
        await drainPendingTasks()
        verifyNoMemoryLeaks()
        try await super.tearDown()
    }
    
    func test_authPhase_initialState_isLoading() {
        XCTAssertEqual(viewModel.authPhase, .loading)
    }
    
    func test_authPhase_transitionsToAuthenticated() async throws {
        _ = try await authRepository.signInAnonymously()
        
        await waitUntil("authPhase becomes authenticated") {
            viewModel.authPhase == .authenticated
        }
        
        XCTAssertEqual(viewModel.authPhase, .authenticated)
    }
    
    func test_authPhase_transitionsToUnauthenticated_whenSignedOut() async throws {
        _ = try await authRepository.signInAnonymously()
        
        await waitUntil("authPhase becomes authenticated") {
            viewModel.authPhase == .authenticated
        }
        
        try await authRepository.signOut()
        
        await waitUntil("authPhase becomes unauthenticated") {
            viewModel.authPhase == .unauthenticated
        }
        
        XCTAssertEqual(viewModel.authPhase, .unauthenticated)
    }
    
    func test_activeTab_initialState_isFeed() {
        XCTAssertEqual(viewModel.activeTab, .feed)
    }
    
    func test_activeTab_canBeChanged() {
        viewModel.activeTab = .friends
        XCTAssertEqual(viewModel.activeTab, .friends)
        
        viewModel.activeTab = .feed
        XCTAssertEqual(viewModel.activeTab, .feed)
    }
}