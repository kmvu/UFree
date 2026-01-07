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
    public let displayName: String?
    
    public init(id: String, isAnonymous: Bool, displayName: String? = nil) {
        self.id = id
        self.isAnonymous = isAnonymous
        self.displayName = displayName
    }
}
