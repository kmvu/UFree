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
    
    func test_loadFriends_noFriends_returnsEmpty() async {
        await sut.loadFriends()
        XCTAssertEqual(sut.friends.count, 0)
    }
    
    func test_loadFriends_withFriends_populatesState() async {
        let friend = UserProfile(id: "user1", displayName: "Alice", hashedPhoneNumber: "abc123")
        await mockRepository.addFriend(friend)
        
        await sut.loadFriends()
        
        XCTAssertEqual(sut.friends.count, 1)
        XCTAssertEqual(sut.friends.first?.displayName, "Alice")
    }
    
    func test_findFriendsFromContacts_filtersOutExistingFriends() async {
        let existing = UserProfile(id: "user1", displayName: "Alice", hashedPhoneNumber: "abc123")
        let newFriend = UserProfile(id: "user2", displayName: "Bob", hashedPhoneNumber: "def456")
        
        await mockRepository.addFriend(existing)
        await mockRepository.addDiscoveredUser(existing)
        await mockRepository.addDiscoveredUser(newFriend)
        
        await sut.loadFriends()
        await sut.findFriendsFromContacts()
        
        XCTAssertEqual(sut.discoveredUsers.count, 1)
        XCTAssertEqual(sut.discoveredUsers.first?.displayName, "Bob")
    }
    
    func test_addFriend_movesFromDiscoveredToFriends() async {
        let user = UserProfile(id: "user1", displayName: "Alice", hashedPhoneNumber: "abc123")
        await mockRepository.addDiscoveredUser(user)
        
        await sut.findFriendsFromContacts()
        XCTAssertEqual(sut.discoveredUsers.count, 1)
        
        await sut.addFriend(user)
        
        XCTAssertEqual(sut.discoveredUsers.count, 0)
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
}
