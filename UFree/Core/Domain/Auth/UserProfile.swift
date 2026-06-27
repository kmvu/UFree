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
}
