//
//  PhoneDirectoryIntegrationTests.swift
//  UFreeIntegrationTests
//
//  phoneDirectory discovery: fresh claim + legacy users-doc backfill via saveUserProfile.
//

import XCTest
import FirebaseAuth
import FirebaseFirestore
@testable import UFree

@MainActor
final class PhoneDirectoryIntegrationTests: XCTestCase {
    private let alicePhone = "+15551110001"
    private let bobPhone = "+15551110002"

    override func setUp() async throws {
        try requireIntegrationEnvironment()
        try await EmulatorHarness.resetEmulatorData()
    }

    func test_phoneDirectory_newClaim_findableByPhone() async throws {
        let friends = FirebaseFriendRepository()
        let aliceHashes = CryptoUtils.phoneNumberHashes(for: alicePhone)
        XCTAssertFalse(aliceHashes.isEmpty)

        _ = try await EmulatorHarness.signInUser(
            email: "alice-dir@test.ufree",
            displayName: "Alice"
        )
        try await friends.saveUserProfile(displayName: "Alice", hashedPhoneNumbers: aliceHashes)

        _ = try await EmulatorHarness.signInUser(
            email: "bob-dir@test.ufree",
            displayName: "Bob"
        )
        try await friends.saveUserProfile(
            displayName: "Bob",
            hashedPhoneNumbers: CryptoUtils.phoneNumberHashes(for: bobPhone)
        )

        let foundOptional = try await friends.findUserByPhoneNumber(alicePhone)
        let found = try XCTUnwrap(foundOptional)
        XCTAssertEqual(found.displayName, "Alice")
    }

    func test_phoneDirectory_legacyBackfill_thenFindable() async throws {
        let friends = FirebaseFriendRepository()
        let aliceHashes = CryptoUtils.phoneNumberHashes(for: alicePhone)
        let hash = try XCTUnwrap(aliceHashes.first)

        // Simulate a pre-Phase-1 user: hashes on users/{uid} only, no phoneDirectory claim.
        let aliceId = try await EmulatorHarness.signInUser(
            email: "alice-legacy@test.ufree",
            displayName: "Legacy Alice"
        )
        try await Firestore.firestore().collection("users").document(aliceId).setData([
            "displayName": "Legacy Alice",
            "hashedPhoneNumbers": aliceHashes,
            "hashedPhoneNumber": hash
        ])
        // Intentionally skip phoneDirectory + publicProfiles.

        // Login backfill path: saveUserProfile claims directory + publicProfiles.
        try await friends.saveUserProfile(displayName: "Legacy Alice", hashedPhoneNumbers: aliceHashes)

        _ = try await EmulatorHarness.signInUser(
            email: "bob-legacy@test.ufree",
            displayName: "Bob"
        )
        try await friends.saveUserProfile(displayName: "Bob", hashedPhoneNumbers: [])

        let foundOptional = try await friends.findUserByPhoneNumber(alicePhone)
        let found = try XCTUnwrap(foundOptional)
        XCTAssertEqual(found.id, aliceId)
        XCTAssertEqual(found.displayName, "Legacy Alice")
    }
}
