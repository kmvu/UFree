//
//  AppNotification.swift
//  UFree
//
//  Created by Khang Vu on 08/01/26.
//

import Foundation
import FirebaseFirestore

public struct AppNotification: Identifiable, Codable {
    @DocumentID public var id: String?
    public let recipientId: String
    public let senderId: String
    public let senderName: String
    public let type: NotificationType
    public let date: Date
    public var isRead: Bool
    
    public enum NotificationType: String, Codable {
        case friendRequest
        case nudge
        // easy to extend later: case scheduleChange, case eventInvite
    }
    
    public init(
        recipientId: String,
        senderId: String,
        senderName: String,
        type: NotificationType,
        date: Date,
        isRead: Bool = false
    ) {
        self.recipientId = recipientId
        self.senderId = senderId
        self.senderName = senderName
        self.type = type
        self.date = date
        self.isRead = isRead
    }
}
