//
//  UserProfile.swift
//  UFree
//
//  Created by Khang Vu on 05/01/26.
//

import Foundation
import FirebaseFirestore

/// Represents a user's profile in Firestore for friend discovery and scheduling.
public struct UserProfile: Identifiable, Codable, Equatable {
    @DocumentID public var id: String?
    public let displayName: String
    public let phoneNumber: String?

    /// Legacy single-hash field kept for backward-compatible Firestore reads.
    /// New writes use `hashedPhoneNumbers` (the array) instead.
    public let hashedPhoneNumber: String?

    /// Primary multi-hash field for E.164-normalised phone matching.
    /// Stores up to 2 SHA-256 hashes (raw-digits form + E.164 variant)
    /// so that local-format numbers match international-format contacts.
    /// Queried via Firestore `array-contains-any`.
    public var hashedPhoneNumbers: [String]

    public var friendIds: [String]

    private enum CodingKeys: String, CodingKey {
        case displayName
        case phoneNumber
        case hashedPhoneNumber
        case hashedPhoneNumbers
        case friendIds
    }

    // MARK: - Init

    public init(
        id: String? = nil,
        displayName: String,
        phoneNumber: String? = nil,
        hashedPhoneNumber: String? = nil,
        hashedPhoneNumbers: [String] = [],
        friendIds: [String] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.phoneNumber = phoneNumber
        self.hashedPhoneNumber = hashedPhoneNumber
        // If the caller only supplied the legacy single-hash, seed the array from it
        // so existing callers that pass `hashedPhoneNumber:` still produce a valid
        // array field on first write.
        if hashedPhoneNumbers.isEmpty, let legacy = hashedPhoneNumber {
            self.hashedPhoneNumbers = [legacy]
        } else {
            self.hashedPhoneNumbers = hashedPhoneNumbers
        }
        self.friendIds = friendIds
    }

    /// Firestore docs often omit `friendIds` / `hashedPhoneNumbers` on first write.
    /// Synthesized Codable treats missing non-optional arrays as decode failures, which
    /// made `findUserByPhoneNumber` skip every match (`try?` → nil → "No user found").
    ///
    /// Custom decoding must also populate `@DocumentID` from `Firestore.Decoder` userInfo;
    /// otherwise `id` stays nil and friend requests fail with "Missing user information".
    public init(from decoder: Decoder) throws {
        if let documentID = try? DocumentID<String>(from: decoder) {
            _id = documentID
        } else {
            _id = DocumentID(wrappedValue: nil)
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decode(String.self, forKey: .displayName)
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        hashedPhoneNumber = try container.decodeIfPresent(String.self, forKey: .hashedPhoneNumber)
        var numbers = try container.decodeIfPresent([String].self, forKey: .hashedPhoneNumbers) ?? []
        if numbers.isEmpty, let legacy = hashedPhoneNumber {
            numbers = [legacy]
        }
        hashedPhoneNumbers = numbers
        friendIds = try container.decodeIfPresent([String].self, forKey: .friendIds) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(phoneNumber, forKey: .phoneNumber)
        try container.encodeIfPresent(hashedPhoneNumber, forKey: .hashedPhoneNumber)
        try container.encode(hashedPhoneNumbers, forKey: .hashedPhoneNumbers)
        try container.encode(friendIds, forKey: .friendIds)
    }
}
