//
//  UserProfileTests.swift
//  UFreeTests
//

import XCTest
@testable import UFree

@MainActor
final class UserProfileTests: XCTestCase {

    func test_init_seedsHashArrayFromLegacySingleHash() {
        let profile = UserProfile(id: "u1", displayName: "Alice", hashedPhoneNumber: "legacy_hash")

        XCTAssertEqual(profile.hashedPhoneNumbers, ["legacy_hash"])
        XCTAssertEqual(profile.hashedPhoneNumber, "legacy_hash")
    }

    func test_init_prefersExplicitHashArrayOverLegacyHash() {
        let profile = UserProfile(
            id: "u1",
            displayName: "Alice",
            hashedPhoneNumber: "legacy_hash",
            hashedPhoneNumbers: ["hash_a", "hash_b"]
        )

        XCTAssertEqual(profile.hashedPhoneNumbers, ["hash_a", "hash_b"])
    }

    func test_init_withoutAnyHashes_leavesArrayEmpty() {
        let profile = UserProfile(displayName: "Alice")

        XCTAssertTrue(profile.hashedPhoneNumbers.isEmpty)
        XCTAssertNil(profile.hashedPhoneNumber)
        XCTAssertNil(profile.id)
        XCTAssertTrue(profile.friendIds.isEmpty)
    }

    func test_init_retainsFriendIdsAndPhoneNumber() {
        let profile = UserProfile(
            id: "u1",
            displayName: "Alice",
            phoneNumber: "+15551234567",
            friendIds: ["u2", "u3"]
        )

        XCTAssertEqual(profile.phoneNumber, "+15551234567")
        XCTAssertEqual(profile.friendIds, ["u2", "u3"])
    }

    func test_equality_comparesAllStoredFields() {
        let alice = UserProfile(id: "u1", displayName: "Alice", hashedPhoneNumber: "hash_a")
        let sameAlice = UserProfile(id: "u1", displayName: "Alice", hashedPhoneNumber: "hash_a")
        let bob = UserProfile(id: "u2", displayName: "Bob", hashedPhoneNumber: "hash_b")

        XCTAssertEqual(alice, sameAlice)
        XCTAssertNotEqual(alice, bob)
    }

    func test_hashedPhoneNumbers_isMutable() {
        var profile = UserProfile(id: "u1", displayName: "Alice")

        profile.hashedPhoneNumbers = ["hash_a"]

        XCTAssertEqual(profile.hashedPhoneNumbers, ["hash_a"])
    }

    func test_decode_missingFriendIdsAndHashArray_defaultsAndSeedsLegacy() throws {
        let json = """
        {"displayName":"Test User 1","hashedPhoneNumber":"abc123"}
        """.data(using: .utf8)!

        let profile = try JSONDecoder().decode(UserProfile.self, from: json)

        XCTAssertEqual(profile.displayName, "Test User 1")
        XCTAssertEqual(profile.hashedPhoneNumber, "abc123")
        XCTAssertEqual(profile.hashedPhoneNumbers, ["abc123"])
        XCTAssertTrue(profile.friendIds.isEmpty)
        // JSONDecoder has no Firestore document ref — id stays nil (Firestore path sets it).
        XCTAssertNil(profile.id)
    }

    func test_decode_withHashArray_preservesArray() throws {
        let json = """
        {"displayName":"Test User 2","hashedPhoneNumbers":["h1","h2"],"friendIds":["u9"]}
        """.data(using: .utf8)!

        let profile = try JSONDecoder().decode(UserProfile.self, from: json)

        XCTAssertEqual(profile.hashedPhoneNumbers, ["h1", "h2"])
        XCTAssertEqual(profile.friendIds, ["u9"])
    }
}
