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
}
