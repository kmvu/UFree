//
//  FriendRequest.swift
//  UFree
//
//  Created by Khang Vu on 07/01/26.
//

import Foundation
import FirebaseFirestore

public struct FriendRequest: Identifiable, Codable {
    @DocumentID public var id: String?
    public let fromId: String
    public let fromName: String
    public let toId: String
    public var status: RequestStatus
    public let timestamp: Date
    
    public enum RequestStatus: String, Codable {
        case pending
        case accepted
        case declined
    }
    
    public init(id: String? = nil, fromId: String, fromName: String, toId: String, status: RequestStatus, timestamp: Date) {
        self.id = id
        self.fromId = fromId
        self.fromName = fromName
        self.toId = toId
        self.status = status
        self.timestamp = timestamp
    }
}
