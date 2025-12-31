//
//  User.swift
//  UFree
//
//  Created by Khang Vu on 31/12/25.
//

import Foundation

public struct User: Identifiable, Equatable, Codable {
    public let id: String
    public let isAnonymous: Bool
    // Future-proofing: We can add 'email' or 'displayName' here later
    
    public init(id: String, isAnonymous: Bool) {
        self.id = id
        self.isAnonymous = isAnonymous
    }
}
