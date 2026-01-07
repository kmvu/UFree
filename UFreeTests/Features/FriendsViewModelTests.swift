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
    }
    
    override func tearDown() {
        sut = nil
        mockRepository = nil
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
    
    func test_addFriend_movesFromDiscoveredToFriends() async {
        let user = UserProfile(id: "user1", displayName: "Alice", hashedPhoneNumber: "abc123")
        sut.discoveredUsers = [user]
        
        await sut.addFriend(user)
        
        XCTAssertTrue(sut.discoveredUsers.isEmpty)
        XCTAssertEqual(sut.friends.count, 1)
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
        
        await sut.addFriend(user)
        
        XCTAssertTrue(sut.searchText.isEmpty)
        XCTAssertNil(sut.searchResult)
    }
}
