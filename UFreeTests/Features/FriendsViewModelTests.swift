//
//  FriendsViewModelTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 05/01/26.
//

import XCTest
@testable import UFree

@MainActor
final class FriendsViewModelTests: XCTestCase {
    
    private var sut: FriendsViewModel!
    private var mockRepository: MockFriendRepository!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockFriendRepository()
        sut = FriendsViewModel(friendRepository: mockRepository)
        trackForMemoryLeaks(sut)
    }
    
    override func tearDown() {
        sut = nil
        mockRepository = nil
        verifyNoMemoryLeaks()
        super.tearDown()
    }
    
    // MARK: - Load Friends Tests
    
    func test_loadFriends_empty() async {
        await sut.loadFriends()
        XCTAssertEqual(sut.friends.count, 0)
    }
    
    func test_loadFriends_withFriends() async {
        let friend = UserProfile(id: "user1", displayName: "Alice", hashedPhoneNumber: "abc123")
        await mockRepository.addFriend(friend)
        
        await sut.loadFriends()
        
        XCTAssertEqual(sut.friends.count, 1)
        XCTAssertEqual(sut.friends.first?.displayName, "Alice")
    }
    
    // MARK: - Add/Remove Friend Tests
    
    func test_addFriend_sendsRequestAndRemovesFromDiscovered() async {
        let user = UserProfile(id: "user1", displayName: "Alice", hashedPhoneNumber: "abc123")
        sut.discoveredUsers = [user]
        
        await sut.addFriend(user)
        
        XCTAssertTrue(sut.discoveredUsers.isEmpty)
        XCTAssertEqual(sut.friends.count, 0) // Should not be in friends yet (handshake model)
    }
    
    func test_removeFriend_removesFriendFromList() async {
        let friend = UserProfile(id: "user1", displayName: "Alice", hashedPhoneNumber: "abc123")
        await mockRepository.addFriend(friend)
        await sut.loadFriends()
        XCTAssertEqual(sut.friends.count, 1)
        
        await sut.removeFriend(friend)
        
        XCTAssertEqual(sut.friends.count, 0)
    }
    
    // MARK: - Phone Search Tests
    
    func test_performPhoneSearch_empty() async {
        await sut.performPhoneSearch()
        XCTAssertNotNil(sut.errorMessage)
    }
    
    func test_performPhoneSearch_notFound() async {
        sut.searchText = "555-1234"
        
        await sut.performPhoneSearch()
        
        XCTAssertNil(sut.searchResult)
        XCTAssertNotNil(sut.errorMessage)
    }
    
    func test_performPhoneSearch_found() async {
        let phoneNumber = "555-1234"
        let hashedPhone = CryptoUtils.hashPhoneNumber(phoneNumber)!
        let user = UserProfile(id: "user1", displayName: "Alice", hashedPhoneNumber: hashedPhone)
        await mockRepository.addUser(user)
        sut.searchText = phoneNumber
        
        await sut.performPhoneSearch()
        
        XCTAssertNotNil(sut.searchResult)
        XCTAssertNil(sut.errorMessage)
    }
    
    func test_performPhoneSearch_clearsAfterAdd() async {
        let phoneNumber = "555-1234"
        let hashedPhone = CryptoUtils.hashPhoneNumber(phoneNumber)!
        let user = UserProfile(id: "user1", displayName: "Alice", hashedPhoneNumber: hashedPhone)
        await mockRepository.addUser(user)
        sut.searchText = phoneNumber
        sut.searchResult = user
        
        await sut.sendFriendRequest(to: user, source: "manual")
        
        XCTAssertTrue(sut.searchText.isEmpty)
        XCTAssertNil(sut.searchResult)
    }
    
    func test_isContactMatched_returnsTrueForMatchedHash() {
        let hash = "matched_hash"
        sut.contactHashes = [hash]
        let user = UserProfile(id: "user1", displayName: "Alice", hashedPhoneNumber: hash)
        
        XCTAssertTrue(sut.isContactMatched(user))
    }

    func test_acceptRequest_addsFriend() async {
        let request = FriendRequest(
            id: "req1",
            fromId: "user1",
            fromName: "Alice",
            toId: "me",
            status: .pending,
            timestamp: Date()
        )
        sut.incomingRequests = [request]
        
        await sut.acceptRequest(request)
        
        XCTAssertEqual(sut.friends.count, 1)
        XCTAssertEqual(sut.friends.first?.id, "user1")
        XCTAssertEqual(sut.incomingRequests.count, 0)
    }

    func test_acceptRequest_firesOnAcceptCompleted_forSubsequentFriend() async {
        sut.friends = [UserProfile(id: "existing", displayName: "Existing")]
        let request = FriendRequest(
            id: "req2",
            fromId: "user2",
            fromName: "Bob",
            toId: "me",
            status: .pending,
            timestamp: Date()
        )
        sut.incomingRequests = [request]

        var completedName: String?
        var completedWasFirst: Bool?
        sut.onAcceptCompleted = { name, wasFirst in
            completedName = name
            completedWasFirst = wasFirst
        }

        await sut.acceptRequest(request)

        XCTAssertEqual(completedName, "Bob")
        XCTAssertEqual(completedWasFirst, false)
    }

    func test_declineRequest_removesFromIncoming() async {
        let request = FriendRequest(
            id: "req1",
            fromId: "user1",
            fromName: "Alice",
            toId: "me",
            status: .pending,
            timestamp: Date()
        )
        sut.incomingRequests = [request]
        
        await sut.declineRequest(request)
        
        XCTAssertEqual(sut.friends.count, 0)
        XCTAssertEqual(sut.incomingRequests.count, 0)
    }

    func test_rapidTapProtection() async {
        let user = UserProfile(id: "user1", displayName: "Alice", hashedPhoneNumber: "abc123")
        mockRepository.simulatedSendDelayNanoseconds = 80_000_000 // 80ms — keep first call in-flight

        async let first: Void = sut.sendFriendRequest(to: user, source: "manual")
        async let second: Void = sut.sendFriendRequest(to: user, source: "manual")
        _ = await (first, second)

        XCTAssertEqual(mockRepository.sendFriendRequestCallCount, 1)
    }

    func test_sendFriendRequest_alreadyFriend_setsErrorWithoutCallingRepo() async {
        let user = UserProfile(id: "user1", displayName: "Alice", hashedPhoneNumber: "abc123")
        sut.friends = [user]

        await sut.sendFriendRequest(to: user, source: "manual")

        XCTAssertEqual(sut.errorMessage, "You're already connected with Alice.")
        XCTAssertEqual(mockRepository.sendFriendRequestCallCount, 0)
    }
}
