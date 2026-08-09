//
//  AppNotification+InboxCopy.swift
//  UFree
//

import Foundation

extension AppNotification {
    /// Shared inbox / banner copy for notification rows and foreground banners.
    public var inboxMessage: String {
        let day = targetWeekdayLabel
        switch type {
        case .friendRequest:
            return "\(senderName) sent you a friend request."
        case .friendAccepted:
            return "\(senderName) accepted — you're connected!"
        case .nudge:
            if let day {
                return "\(senderName) asked if you're free \(day)"
            }
            return "\(senderName) nudged you! 👋"
        case .nudgeReply:
            let response = nudgeResponse.flatMap { NudgeResponse(rawValue: $0) }
            let verb: String
            switch response {
            case .imIn: verb = "is in"
            case .maybe: verb = "said maybe"
            case .busy: verb = "is busy"
            case .none: verb = "replied"
            }
            if let day {
                return "\(senderName) \(verb) for \(day)"
            }
            return "\(senderName) \(verb)"
        }
    }

    /// Short subtitle for the foreground banner (sender name is shown separately).
    public var inboxBannerSubtitle: String {
        let day = targetWeekdayLabel
        switch type {
        case .friendRequest:
            return "Sent you a friend request"
        case .friendAccepted:
            return "You're connected!"
        case .nudge:
            if let day {
                return "Are you free \(day)?"
            }
            return "Sent you a nudge"
        case .nudgeReply:
            let response = nudgeResponse.flatMap { NudgeResponse(rawValue: $0) }
            switch response {
            case .imIn: return day.map { "Is in for \($0)" } ?? "Is in"
            case .maybe: return day.map { "Maybe for \($0)" } ?? "Said maybe"
            case .busy: return day.map { "Busy for \($0)" } ?? "Is busy"
            case .none: return "Replied to your nudge"
            }
        }
    }

    public var inboxIconName: String {
        switch type {
        case .nudge: return "hand.wave.fill"
        case .nudgeReply: return "checkmark.bubble.fill"
        case .friendRequest: return "person.badge.plus"
        case .friendAccepted: return "person.2.fill"
        }
    }
}
