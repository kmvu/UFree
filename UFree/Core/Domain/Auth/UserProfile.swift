//
//  UserProfile.swift
//  UFree
//
//  Created by Khang Vu on 05/01/26.
//

import Foundation
import FirebaseFirestore

/// Represents a user's profile in Firestore for friend discovery and scheduling
public struct UserProfile: Identifiable, Codable, Equatable {
    @DocumentID public var id: String?
    public let displayName: String
    public let phoneNumber: String?
    public let hashedPhoneNumber: String?
    public var friendIds: [String]
    
    // Standard Init
    public init(
        id: String? = nil,
        displayName: String,
        phoneNumber: String? = nil,
        hashedPhoneNumber: String? = nil,
        friendIds: [String] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.phoneNumber = phoneNumber
        self.hashedPhoneNumber = hashedPhoneNumber
        self.friendIds = friendIds
    }
}
