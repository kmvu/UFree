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
    }
    
    func test_authPhase_initialState_isLoading() {
        XCTAssertEqual(viewModel.authPhase, .loading)
    }
    
    func test_authPhase_transitionsToAuthenticated() async throws {
        _ = try await authRepository.signInAnonymously()
        
        let startDate = Date()
        while viewModel.authPhase != .authenticated && Date().timeIntervalSince(startDate) < 1.0 {
            await Task.yield()
        }
        
        XCTAssertEqual(viewModel.authPhase, .authenticated)
    }
    
    func test_authPhase_transitionsToUnauthenticated_whenSignedOut() async throws {
        _ = try await authRepository.signInAnonymously()
        
        // Wait for sign in to reflect
        let startIn = Date()
        while viewModel.authPhase != .authenticated && Date().timeIntervalSince(startIn) < 1.0 {
            await Task.yield()
        }
        
        try await authRepository.signOut()
        
        let startOut = Date()
        while viewModel.authPhase != .unauthenticated && Date().timeIntervalSince(startOut) < 1.0 {
            await Task.yield()
        }
        
        XCTAssertEqual(viewModel.authPhase, .unauthenticated)
    }
    
    func test_activeTab_initialState_isSchedule() {
        XCTAssertEqual(viewModel.activeTab, .schedule)
    }
    
    func test_activeTab_canBeChanged() {
        viewModel.activeTab = .friends
        XCTAssertEqual(viewModel.activeTab, .friends)
        
        viewModel.activeTab = .feed
        XCTAssertEqual(viewModel.activeTab, .feed)
    }
}