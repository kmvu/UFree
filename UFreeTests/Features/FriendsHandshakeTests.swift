//
//  FriendsHandshakeTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 07/01/26.
//

import XCTest
@testable import UFree

@MainActor
final class FriendsHandshakeTests: XCTestCase {
    
    private var viewModel: FriendsViewModel!
    private var mockRepo: MockFriendRepository!
    
    override func setUp() async throws {
        try await super.setUp()
        mockRepo = MockFriendRepository()
        viewModel = FriendsViewModel(friendRepository: mockRepo)
    }
    
    // MARK: - Send Friend Request
    
    func test_sendFriendRequest_removesFromDiscovered() async {
        let user = UserProfile(id: "user1", displayName: "Alice", hashedPhoneNumber: "hash1")
        viewModel.discoveredUsers = [user]
        
        await viewModel.sendFriendRequest(to: user)
        
        XCTAssertTrue(viewModel.discoveredUsers.isEmpty)
    }
    
    // MARK: - Accept/Decline Request
    
    func test_acceptRequest_addsToFriends() async {
        let request = FriendRequest(
            id: "req1",
            fromId: "user1",
            fromName: "Alice",
            toId: "currentUser",
            status: .pending,
            timestamp: Date()
        )
        
        await mockRepo.addIncomingRequest(request)
        viewModel.incomingRequests = [request]
        
        await viewModel.acceptRequest(request)
        
        XCTAssertTrue(viewModel.incomingRequests.isEmpty)
        XCTAssertEqual(viewModel.friends.count, 1)
        XCTAssertEqual(viewModel.friends.first?.displayName, "Alice")
    }
    
    func test_declineRequest_removesFromIncoming() async {
        let request = FriendRequest(
            id: "req1",
            fromId: "user1",
            fromName: "Bob",
            toId: "currentUser",
            status: .pending,
            timestamp: Date()
        )
        
        await mockRepo.addIncomingRequest(request)
        viewModel.incomingRequests = [request]
        
        await viewModel.declineRequest(request)
        
        XCTAssertTrue(viewModel.incomingRequests.isEmpty)
    }
    
    // MARK: - Multiple Requests
    
    func test_multipleRequests() async {
        let req1 = makeFriendRequest(id: "req1", fromName: "Alice")
        let req2 = makeFriendRequest(id: "req2", fromName: "Bob")
        
        await mockRepo.addIncomingRequest(req1)
        await mockRepo.addIncomingRequest(req2)
        viewModel.incomingRequests = [req1, req2]
        
        await viewModel.acceptRequest(req1)
        XCTAssertEqual(viewModel.incomingRequests.count, 1)
        XCTAssertEqual(viewModel.friends.count, 1)
        
        await viewModel.declineRequest(req2)
        XCTAssertTrue(viewModel.incomingRequests.isEmpty)
        XCTAssertEqual(viewModel.friends.count, 1)
    }
    
    // MARK: - Observation
    
    func test_observeIncomingRequests() async {
        let request = makeFriendRequest(id: "req1", fromName: "Alice")
        await mockRepo.addIncomingRequest(request)
        
        var receivedRequests: [FriendRequest] = []
        for await requests in await mockRepo.observeIncomingRequests() {
            receivedRequests = requests
            break
        }
        
        XCTAssertEqual(receivedRequests.count, 1)
        XCTAssertEqual(receivedRequests.first?.fromName, "Alice")
    }
    
    // MARK: - Listener Lifecycle
    
    func test_listenToRequests_startsListener() async {
        let request = makeFriendRequest(id: "req1", fromName: "Alice")
        await mockRepo.addIncomingRequest(request)
        
        viewModel.listenToRequests()
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        XCTAssertEqual(viewModel.incomingRequests.count, 1)
    }
    
    func test_stopListening_gracefulShutdown() {
        viewModel.listenToRequests()
        viewModel.stopListening()
        XCTAssertTrue(true) // No crash = pass
    }
    
    func test_listenToRequests_cancelsExisting() async {
        let request = makeFriendRequest(id: "req1", fromName: "Alice")
        await mockRepo.addIncomingRequest(request)
        
        viewModel.listenToRequests()
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        viewModel.listenToRequests()
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        XCTAssertEqual(viewModel.incomingRequests.count, 1)
    }
    
    // MARK: - Helpers
    
    private func makeFriendRequest(id: String, fromName: String) -> FriendRequest {
        FriendRequest(
            id: id,
            fromId: "user_" + id,
            fromName: fromName,
            toId: "currentUser",
            status: .pending,
            timestamp: Date()
        )
    }
}
