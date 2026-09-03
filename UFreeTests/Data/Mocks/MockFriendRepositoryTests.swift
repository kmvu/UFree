//
//  MockFriendRepositoryTests.swift
//  UFreeTests
//

import XCTest
@testable import UFree

/// `MockFriendRepository` ships in the app target and backs most ViewModel tests,
/// so its hash-matching and handshake behaviour needs its own coverage — a bug here
/// would silently invalidate every suite that depends on it.
@MainActor
final class MockFriendRepositoryTests: XCTestCase {

    private var sut: MockFriendRepository!

    override func setUp() {
        super.setUp()
        sut = MockFriendRepository()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Friends List

    func test_getMyFriends_startsEmpty() async throws {
        let friends = try await sut.getMyFriends()

        XCTAssertTrue(friends.isEmpty)
    }

    func test_addFriend_appearsInMyFriends() async throws {
        sut.addFriend(UserProfile(id: "u1", displayName: "Alice"))

        let friends = try await sut.getMyFriends()

        XCTAssertEqual(friends.map(\.id), ["u1"])
    }

    func test_init_seedsProvidedFriends() async throws {
        sut = MockFriendRepository(myFriends: [UserProfile(id: "u1", displayName: "Alice")])

        let friends = try await sut.getMyFriends()

        XCTAssertEqual(friends.count, 1)
    }

    // MARK: - Phone Lookup

    func test_findUserByPhoneNumber_matchesLegacySingleHash() async throws {
        let phone = "555-1234"
        let legacyHash = CryptoUtils.hashPhoneNumber(phone)!
        sut.addUser(UserProfile(id: "u1", displayName: "Alice", hashedPhoneNumber: legacyHash))

        let found = try await sut.findUserByPhoneNumber(phone)

        XCTAssertEqual(found?.id, "u1")
    }

    func test_findUserByPhoneNumber_matchesHashArray() async throws {
        let phone = "555-1234"
        let hashes = CryptoUtils.phoneNumberHashes(for: phone)
        sut.addUser(UserProfile(id: "u1", displayName: "Alice", hashedPhoneNumbers: hashes))

        let found = try await sut.findUserByPhoneNumber(phone)

        XCTAssertEqual(found?.id, "u1")
    }

    func test_findUserByPhoneNumber_unknownNumber_returnsNil() async throws {
        sut.addUser(UserProfile(id: "u1", displayName: "Alice", hashedPhoneNumber: "other_hash"))

        let found = try await sut.findUserByPhoneNumber("555-9999")

        XCTAssertNil(found)
    }

    func test_findUserByPhoneNumber_emptyInput_returnsNil() async throws {
        sut.addUser(UserProfile(id: "u1", displayName: "Alice", hashedPhoneNumber: "hash"))

        let found = try await sut.findUserByPhoneNumber("")

        XCTAssertNil(found)
    }

    func test_findUserById_returnsMatchingUser() async throws {
        sut.addUser(UserProfile(id: "u1", displayName: "Alice"))

        let found = try await sut.findUserById("u1")

        XCTAssertEqual(found?.displayName, "Alice")
    }

    func test_findUserById_unknownId_returnsNil() async throws {
        let found = try await sut.findUserById("nope")

        XCTAssertNil(found)
    }

    // MARK: - Contact Discovery

    func test_findFriendsFromContactHashes_emptyHashes_returnsEmpty() async throws {
        sut.addDiscoveredUser(UserProfile(id: "u1", displayName: "Alice", hashedPhoneNumber: "hash_a"))

        let matches = try await sut.findFriendsFromContactHashes([])

        XCTAssertTrue(matches.isEmpty)
    }

    func test_findFriendsFromContactHashes_returnsOnlyHashMatches() async throws {
        sut.addDiscoveredUser(UserProfile(id: "u1", displayName: "Alice", hashedPhoneNumber: "hash_a"))
        sut.addDiscoveredUser(UserProfile(id: "u2", displayName: "Bob", hashedPhoneNumber: "hash_b"))

        let matches = try await sut.findFriendsFromContactHashes(["hash_b"])

        XCTAssertEqual(matches.map(\.id), ["u2"])
    }

    func test_findFriendsFromContactHashes_noHashMatch_fallsBackToAllDiscovered() async throws {
        sut.addDiscoveredUser(UserProfile(id: "u1", displayName: "Alice", hashedPhoneNumber: "hash_a"))

        let matches = try await sut.findFriendsFromContactHashes(["unrelated_hash"])

        XCTAssertEqual(matches.map(\.id), ["u1"])
    }

    // MARK: - Handshake

    func test_observeIncomingRequests_yieldsSeededRequestsThenFinishes() async {
        sut.addIncomingRequest(
            FriendRequest(id: "r1", fromId: "u1", fromName: "Alice", toId: "me", status: .pending, timestamp: Date())
        )

        var emissions: [[FriendRequest]] = []
        for await requests in sut.observeIncomingRequests() {
            emissions.append(requests)
        }

        XCTAssertEqual(emissions.count, 1)
        XCTAssertEqual(emissions.first?.map(\.id), ["r1"])
    }

    func test_observeFriends_yieldsSeededFriendsThenFinishes() async {
        sut.addFriend(UserProfile(id: "u1", displayName: "Alice"))

        var emissions: [[UserProfile]] = []
        for await friends in sut.observeFriends() {
            emissions.append(friends)
        }

        XCTAssertEqual(emissions.count, 1)
        XCTAssertEqual(emissions.first?.map(\.id), ["u1"])
    }

    func test_acceptFriendRequest_promotesSenderToFriend() async throws {
        let request = FriendRequest(
            id: "r1", fromId: "u1", fromName: "Alice", toId: "me", status: .pending, timestamp: Date()
        )
        sut.addIncomingRequest(request)

        try await sut.acceptFriendRequest(request)

        let friends = try await sut.getMyFriends()
        XCTAssertEqual(friends.map(\.displayName), ["Alice"])
    }

    func test_acceptFriendRequest_byIdWithoutCache_promotesSender() async throws {
        // Notification Center Accept may construct a FriendRequest from relatedRequestId
        // before the live incoming-requests listener has populated.
        let request = FriendRequest(
            id: "ghost", fromId: "u1", fromName: "Alice", toId: "me", status: .pending, timestamp: Date()
        )

        try await sut.acceptFriendRequest(request)

        let friends = try await sut.getMyFriends()
        XCTAssertEqual(friends.map(\.displayName), ["Alice"])
    }

    func test_declineFriendRequest_doesNotAddFriend() async throws {
        let request = FriendRequest(
            id: "r1", fromId: "u1", fromName: "Alice", toId: "me", status: .pending, timestamp: Date()
        )
        sut.addIncomingRequest(request)

        try await sut.declineFriendRequest(request)

        let friends = try await sut.getMyFriends()
        XCTAssertTrue(friends.isEmpty)
    }

    func test_sendFriendRequest_withoutUserId_isIgnored() async throws {
        try await sut.sendFriendRequest(to: UserProfile(displayName: "No Id"))

        let friends = try await sut.getMyFriends()
        XCTAssertTrue(friends.isEmpty)
    }

    // MARK: - Disabled Direct Add

    func test_addFriend_throwsDirectAddDisabled() async {
        do {
            try await sut.addFriend(userId: "u1")
            XCTFail("Expected direct add to throw")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Direct add is disabled"))
        }
    }

    func test_noOpMethods_completeWithoutThrowing() async throws {
        try await sut.removeFriend(userId: "u1")
        try await sut.saveUserProfile(displayName: "Alice", hashedPhoneNumbers: ["hash"])
        try await sut.sendFriendRequest(to: UserProfile(id: "u2", displayName: "Bob"))
    }

    // MARK: - Reset

    func test_clearMockData_emptiesEveryCollection() async throws {
        sut.addFriend(UserProfile(id: "u1", displayName: "Alice"))
        sut.addUser(UserProfile(id: "u2", displayName: "Bob"))
        sut.addDiscoveredUser(UserProfile(id: "u3", displayName: "Carol", hashedPhoneNumber: "hash_c"))
        sut.addIncomingRequest(
            FriendRequest(id: "r1", fromId: "u1", fromName: "Alice", toId: "me", status: .pending, timestamp: Date())
        )

        sut.clearMockData()

        let friends = try await sut.getMyFriends()
        let clearedUser = try await sut.findUserById("u2")
        let discovered = try await sut.findFriendsFromContactHashes(["hash_c"])

        XCTAssertTrue(friends.isEmpty)
        XCTAssertNil(clearedUser)
        XCTAssertTrue(discovered.isEmpty)
    }
}
