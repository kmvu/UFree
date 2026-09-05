//
//  NotificationSenderIdentity.swift
//  UFree
//
//  Shared Auth identity checks for nudge / nudge-reply writes.
//

import Foundation

enum NotificationSenderIdentity {
    static let errorDomain = "FirebaseNotificationRepository"

    /// Requires a non-empty display name. Nudges and replies both stamp `senderName`.
    static func requireDisplayName(_ name: String?) throws -> String {
        guard let name, !name.isEmpty else {
            throw NSError(
                domain: errorDomain,
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Display name required to send a nudge"]
            )
        }
        return name
    }

    static func requireSignedInUserId(_ uid: String?) throws -> String {
        guard let uid else {
            throw NSError(
                domain: errorDomain,
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "User not logged in"]
            )
        }
        return uid
    }
}
