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
    /// Hangout day proposed by a nudge (`YYYY-MM-DD`).
    public var targetDateString: String?
    /// Reply value: `imIn`, `maybe`, or `busy` (on reply docs, or stamped on original after responding).
    public var nudgeResponse: String?
    /// Firestore `friendRequests` document id when `type == .friendRequest` (enables NC Accept without cache).
    public var relatedRequestId: String?

    public enum NotificationType: String, Codable {
        case friendRequest
        /// Recipient accepted — shown in the inviter’s inbox.
        case friendAccepted
        case nudge
        case nudgeReply
    }

    public enum NudgeResponse: String, Codable, CaseIterable {
        case imIn
        case maybe
        case busy

        public var displayLabel: String {
            switch self {
            case .imIn: return "I'm in"
            case .maybe: return "Maybe"
            case .busy: return "Busy"
            }
        }

        /// Compact label for Who's Free day cells.
        public var shortLabel: String {
            switch self {
            case .imIn: return "In"
            case .maybe: return "Maybe"
            case .busy: return "Busy"
            }
        }
    }

    public init(
        recipientId: String,
        senderId: String,
        senderName: String,
        type: NotificationType,
        date: Date,
        isRead: Bool = false,
        targetDateString: String? = nil,
        nudgeResponse: String? = nil,
        relatedRequestId: String? = nil
    ) {
        self.recipientId = recipientId
        self.senderId = senderId
        self.senderName = senderName
        self.type = type
        self.date = date
        self.isRead = isRead
        self.targetDateString = targetDateString
        self.nudgeResponse = nudgeResponse
        self.relatedRequestId = relatedRequestId
    }

    public var hasResponded: Bool {
        nudgeResponse != nil
    }

    public var targetWeekdayLabel: String? {
        guard let targetDateString,
              let date = Self.dayFormatter.date(from: targetDateString) else {
            return nil
        }
        return Self.weekdayFormatter.string(from: date)
    }

    public static func dateString(from date: Date) -> String {
        dayFormatter.string(from: Calendar.current.startOfDay(for: date))
    }

    public static func date(from dateString: String) -> Date? {
        dayFormatter.date(from: dateString)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()
}
