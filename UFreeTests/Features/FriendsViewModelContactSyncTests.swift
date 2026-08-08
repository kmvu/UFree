//
//  FriendsViewModelContactSyncTests.swift
//  UFreeTests
//

import XCTest
@testable import UFree

/// Covers the contact-discovery, QR and real-time listener paths of `FriendsViewModel`,
/// which `FriendsViewModelTests` leaves untouched because they need a contacts double
/// and a repository that can fail on demand.
@MainActor
final class FriendsViewModelContactSyncTests: XCTestCase {

    private var friendRepository: FriendRepositorySpy!
    private var contactsRepository: ContactsRepositoryStub!
    private var sut: FriendsViewModel!

    override func setUp() {
        super.setUp()
        friendRepository = FriendRepositorySpy()
        contactsRepository = ContactsRepositoryStub()
        sut = FriendsViewModel(friendRepository: friendRepository, contactsRepository: contactsRepository)
        trackForMemoryLeaks(sut)
    }

    override func tearDown() async throws {
        sut?.stopListening()
        await drainPendingTasks()
        sut = nil
        friendRepository = nil
        contactsRepository = nil
        await drainPendingTasks()
        verifyNoMemoryLeaks()
        try await super.tearDown()
    }

    // MARK: - Contact Discovery

    func test_findFriendsFromContacts_deniedAccess_showsPermissionAlert() async {
        contactsRepository.accessGranted = false

        await sut.findFriendsFromContacts()

        XCTAssertTrue(sut.showPermissionAlert)
        XCTAssertEqual(contactsRepository.fetchCallCount, 0)
        XCTAssertTrue(sut.discoveredUsers.isEmpty)
    }

    func test_findFriendsFromContacts_fetchesHashesExactlyOnce() async {
        contactsRepository.hashes = ["hash_a", "hash_b"]

        await sut.findFriendsFromContacts()

        XCTAssertEqual(contactsRepository.fetchCallCount, 1)
        XCTAssertEqual(friendRepository.contactHashQueries, [["hash_a", "hash_b"]])
    }

    func test_findFriendsFromContacts_storesHashesForTrustBadge() async {
        contactsRepository.hashes = ["hash_a", "hash_b"]

        await sut.findFriendsFromContacts()

        XCTAssertEqual(sut.contactHashes, Set(["hash_a", "hash_b"]))
    }

    func test_findFriendsFromContacts_publishesMatches() async {
        contactsRepository.hashes = ["hash_a"]
        friendRepository.contactMatches = [
            UserProfile(id: "u1", displayName: "Alice", hashedPhoneNumber: "hash_a")
        ]

        await sut.findFriendsFromContacts()

        XCTAssertEqual(sut.discoveredUsers.count, 1)
        XCTAssertEqual(sut.discoveredUsers.first?.displayName, "Alice")
        XCTAssertNil(sut.errorMessage)
    }

    func test_findFriendsFromContacts_excludesExistingFriends() async {
        let alice = UserProfile(id: "u1", displayName: "Alice", hashedPhoneNumber: "hash_a")
        let bob = UserProfile(id: "u2", displayName: "Bob", hashedPhoneNumber: "hash_b")
        friendRepository.myFriends = [alice]
        await sut.loadFriends()

        contactsRepository.hashes = ["hash_a", "hash_b"]
        friendRepository.contactMatches = [alice, bob]

        await sut.findFriendsFromContacts()

        XCTAssertEqual(sut.discoveredUsers.map(\.id), ["u2"])
    }

    func test_findFriendsFromContacts_noMatches_setsFriendlyMessage() async {
        contactsRepository.hashes = ["hash_a"]
        friendRepository.contactMatches = []

        await sut.findFriendsFromContacts()

        XCTAssertEqual(sut.errorMessage, "No friends found in your contacts.")
    }

    func test_findFriendsFromContacts_fetchFailure_surfacesError() async {
        contactsRepository.fetchError = NSError(
            domain: "contacts",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Address book unavailable"]
        )

        await sut.findFriendsFromContacts()

        XCTAssertEqual(sut.errorMessage, "Address book unavailable")
        XCTAssertTrue(sut.discoveredUsers.isEmpty)
    }

    func test_findFriendsFromContacts_lookupFailure_surfacesError() async {
        contactsRepository.hashes = ["hash_a"]
        friendRepository.contactHashesError = NSError(
            domain: "firestore",
            code: 8,
            userInfo: [NSLocalizedDescriptionKey: "Quota exhausted"]
        )

        await sut.findFriendsFromContacts()

        XCTAssertEqual(sut.errorMessage, "Quota exhausted")
    }

    func test_findFriendsFromContacts_clearsLoadingFlagsWhenDone() async {
        contactsRepository.hashes = ["hash_a"]

        await sut.findFriendsFromContacts()

        XCTAssertFalse(sut.isLoading)
        XCTAssertFalse(sut.isProcessing)
    }

    // MARK: - QR Code

    func test_generateMyQRCode_producesImage() {
        sut.generateMyQRCode(from: "user_123")

        XCTAssertNotNil(sut.qrImage)
    }

    func test_handleScannedCode_knownUser_sendsFriendRequest() async {
        let alice = UserProfile(id: "u1", displayName: "Alice", hashedPhoneNumber: "hash_a")
        friendRepository.userById = alice

        await sut.handleScannedCode("u1")

        XCTAssertEqual(friendRepository.sentRequests.map(\.id), ["u1"])
        XCTAssertNil(sut.scannedCode)
    }

    func test_handleScannedCode_unknownUser_setsNotFoundError() async {
        friendRepository.userById = nil

        await sut.handleScannedCode("missing")

        XCTAssertEqual(sut.errorMessage, "User not found.")
        XCTAssertTrue(friendRepository.sentRequests.isEmpty)
        XCTAssertNil(sut.scannedCode)
    }

    func test_handleScannedCode_lookupFailure_setsInvalidCodeError() async {
        friendRepository.findByIdError = NSError(
            domain: "firestore",
            code: 5,
            userInfo: [NSLocalizedDescriptionKey: "Not found"]
        )

        await sut.handleScannedCode("bad_code")

        XCTAssertEqual(sut.errorMessage, "Invalid QR code: Not found")
        XCTAssertNil(sut.scannedCode)
    }

    // MARK: - Real-Time Listener

    func test_listenToRequests_publishesIncomingRequests() async {
        friendRepository.incomingRequests = [
            FriendRequest(id: "r1", fromId: "u1", fromName: "Alice", toId: "me", status: .pending, timestamp: Date())
        ]

        sut.listenToRequests()

        await waitUntil("incoming requests published") { self.sut.incomingRequests.count == 1 }
        XCTAssertEqual(sut.incomingRequests.first?.fromName, "Alice")
    }

    func test_listenToFriends_publishesFriends() async {
        friendRepository.myFriends = [UserProfile(id: "u1", displayName: "Alice")]

        sut.listenToFriends()

        await waitUntil("friends published") { self.sut.friends.count == 1 }
        XCTAssertEqual(sut.friends.first?.displayName, "Alice")
    }

    func test_listenToRequests_calledTwice_replacesPreviousListener() async {
        friendRepository.incomingRequests = [
            FriendRequest(id: "r1", fromId: "u1", fromName: "Alice", toId: "me", status: .pending, timestamp: Date())
        ]

        sut.listenToRequests()
        sut.listenToRequests()

        await waitUntil("incoming requests published") { self.sut.incomingRequests.count == 1 }
    }

    func test_stopListening_isIdempotent() {
        sut.listenToRequests()

        sut.stopListening()
        sut.stopListening()

        XCTAssertTrue(sut.incomingRequests.isEmpty)
    }

    // MARK: - Trust Logic

    func test_isContactMatched_noLegacyHash_returnsFalse() {
        sut.contactHashes = ["hash_a"]
        let user = UserProfile(id: "u1", displayName: "Alice")

        XCTAssertFalse(sut.isContactMatched(user))
    }

    func test_isContactMatched_unknownHash_returnsFalse() {
        sut.contactHashes = ["hash_a"]
        let user = UserProfile(id: "u1", displayName: "Bob", hashedPhoneNumber: "hash_z")

        XCTAssertFalse(sut.isContactMatched(user))
    }

    // MARK: - Failure Paths on Existing Flows

    func test_loadFriends_failure_surfacesError() async {
        friendRepository.getMyFriendsError = NSError(
            domain: "firestore",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Offline"]
        )

        await sut.loadFriends()

        XCTAssertEqual(sut.errorMessage, "Failed to load friends: Offline")
    }

    func test_performPhoneSearch_failure_surfacesError() async {
        sut.searchText = "555-1234"
        friendRepository.findByPhoneError = NSError(
            domain: "firestore",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Offline"]
        )

        await sut.performPhoneSearch()

        XCTAssertEqual(sut.errorMessage, "Search failed: Offline")
    }

    func test_sendFriendRequest_failure_surfacesError() async {
        let alice = UserProfile(id: "u1", displayName: "Alice")
        let error = NSError(
            domain: "firestore",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Permission denied"]
        )
        friendRepository.sendRequestError = error

        await sut.sendFriendRequest(to: alice, source: "manual")

        XCTAssertEqual(sut.errorMessage, "Failed to send friend request: Permission denied")
    }

    func test_acceptRequest_failure_surfacesError() async {
        let request = FriendRequest(
            id: "r1", fromId: "u1", fromName: "Alice", toId: "me", status: .pending, timestamp: Date()
        )
        sut.incomingRequests = [request]
        let error = NSError(
            domain: "firestore",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Permission denied"]
        )
        friendRepository.acceptRequestError = error

        await sut.acceptRequest(request)

        XCTAssertEqual(sut.errorMessage, "Failed to accept request: Permission denied")
        XCTAssertEqual(sut.incomingRequests.count, 1)
    }

    func test_declineRequest_failure_surfacesError() async {
        let request = FriendRequest(
            id: "r1", fromId: "u1", fromName: "Alice", toId: "me", status: .pending, timestamp: Date()
        )
        sut.incomingRequests = [request]
        friendRepository.declineRequestError = NSError(domain: "firestore", code: 1)

        await sut.declineRequest(request)

        XCTAssertEqual(sut.errorMessage, "Failed to decline request.")
        XCTAssertEqual(sut.incomingRequests.count, 1)
    }

    func test_removeFriend_failure_restoresOriginalList() async {
        let alice = UserProfile(id: "u1", displayName: "Alice")
        friendRepository.myFriends = [alice]
        await sut.loadFriends()
        friendRepository.removeFriendError = NSError(domain: "firestore", code: 1)

        await sut.removeFriend(alice)

        XCTAssertEqual(sut.friends.map(\.id), ["u1"])
        XCTAssertEqual(sut.errorMessage, "Failed to remove friend.")
    }

    func test_removeFriend_withoutId_isIgnored() async {
        let ghost = UserProfile(displayName: "No Id")

        await sut.removeFriend(ghost)

        XCTAssertTrue(friendRepository.removedFriendIds.isEmpty)
    }
}
