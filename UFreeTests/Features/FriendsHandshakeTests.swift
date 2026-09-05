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
        trackForMemoryLeaks(viewModel)
    }

    override func tearDown() async throws {
        viewModel.stopListening()
        viewModel = nil
        mockRepo = nil
        await drainPendingTasks()
        verifyNoMemoryLeaks()
        try await super.tearDown()
    }
    
    // MARK: - Send Friend Request
    
    func test_sendFriendRequest_removesFromDiscovered() async {
        let user = UserProfile(id: "user1", displayName: "Alice", hashedPhoneNumber: "hash1")
        viewModel.discoveredUsers = [user]
        
        await viewModel.sendFriendRequest(to: user, source: "manual")
        
        XCTAssertTrue(viewModel.discoveredUsers.isEmpty)
    }

    func test_handleScannedCode_sendsRequest() async {
        let user = UserProfile(id: "scanned_user", displayName: "Scanned", hashedPhoneNumber: "hash")
        mockRepo.addUser(user)

        await viewModel.handleScannedCode("scanned_user")

        XCTAssertFalse(viewModel.showQRScanner)
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_handleScannedCode_userNotFound() async {
        await viewModel.handleScannedCode("unknown_user")

        XCTAssertFalse(viewModel.showQRScanner)
        XCTAssertEqual(viewModel.errorMessage, "User not found.")
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
        
        mockRepo.addIncomingRequest(request)
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
        
        mockRepo.addIncomingRequest(request)
        viewModel.incomingRequests = [request]
        
        await viewModel.declineRequest(request)
        
        XCTAssertTrue(viewModel.incomingRequests.isEmpty)
    }
    
    // MARK: - Multiple Requests
    
    func test_multipleRequests() async {
        let req1 = makeFriendRequest(id: "req1", fromName: "Alice")
        let req2 = makeFriendRequest(id: "req2", fromName: "Bob")
        
        mockRepo.addIncomingRequest(req1)
        mockRepo.addIncomingRequest(req2)
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
        mockRepo.addIncomingRequest(request)
        
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
        mockRepo.addIncomingRequest(request)
        
        viewModel.listenToRequests()
        
        await waitUntil("incoming request listener yields") {
            !viewModel.incomingRequests.isEmpty
        }
        
        XCTAssertEqual(viewModel.incomingRequests.count, 1)
    }
    
    func test_stopListening_gracefulShutdown() async {
        viewModel.listenToRequests()
        // Allow the initial (empty) stream yield to apply.
        await Task.yield()
        await Task.yield()

        viewModel.stopListening()
        // Second stop must be idempotent.
        viewModel.stopListening()

        let countAfterStop = viewModel.incomingRequests.count
        mockRepo.addIncomingRequest(makeFriendRequest(id: "req_late", fromName: "Late"))

        await drainPendingTasks()

        XCTAssertEqual(viewModel.incomingRequests.count, countAfterStop)
        XCTAssertGreaterThanOrEqual(viewModel.incomingRequests.count, 0)
    }
    
    func test_listenToRequests_cancelsExisting() async {
        let request = makeFriendRequest(id: "req1", fromName: "Alice")
        mockRepo.addIncomingRequest(request)
        
        viewModel.listenToRequests()
        
        await waitUntil("incoming request listener yields") {
            !viewModel.incomingRequests.isEmpty
        }
        
        // Start listener again to verify it cancels the previous one
        viewModel.listenToRequests()
        
        // Yield to allow new listener to set up
        await Task.yield()
        
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
