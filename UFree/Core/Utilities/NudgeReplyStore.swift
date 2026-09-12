//
//  NudgeReplyStore.swift
//  UFree
//
//  UID-scoped local persistence for nudge replies so Who's Free and the
//  hangout-confirm prompt survive relaunch.
//

import Foundation
import Combine

public struct PersistedNudgeReply: Equatable, Codable {
    public enum Outcome: String, Codable {
        case confirmed
        case dismissed
    }

    public let friendId: String
    public var friendName: String
    public let dayKey: String
    public var response: String
    public var outcome: Outcome?

    public var id: String { "\(friendId)|\(dayKey)" }

    public init(
        friendId: String,
        friendName: String,
        dayKey: String,
        response: String,
        outcome: Outcome? = nil
    ) {
        self.friendId = friendId
        self.friendName = friendName
        self.dayKey = dayKey
        self.response = response
        self.outcome = outcome
    }
}

@MainActor
public final class NudgeReplyStore: ObservableObject {
    public static let shared = NudgeReplyStore()

    private let defaults: UserDefaults
    private var userId: String?
    private let recordsKeyBase = "ufree.engagement.nudgeReplies"

    @Published public private(set) var records: [PersistedNudgeReply] = []

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reload()
    }

    public func bind(userId: String?) {
        self.userId = userId
        reload()
    }

    public func record(
        friendId: String,
        friendName: String,
        dayKey: String,
        response: AppNotification.NudgeResponse
    ) {
        var next = records
        if let index = next.firstIndex(where: { $0.friendId == friendId && $0.dayKey == dayKey }) {
            next[index].response = response.rawValue
            if !friendName.isEmpty {
                next[index].friendName = friendName
            }
        } else {
            next.append(
                PersistedNudgeReply(
                    friendId: friendId,
                    friendName: friendName,
                    dayKey: dayKey,
                    response: response.rawValue
                )
            )
        }
        records = next
        persist()
    }

    public func markConfirmed(friendId: String, dayKey: String) {
        setOutcome(.confirmed, friendId: friendId, dayKey: dayKey)
    }

    public func markDismissed(friendId: String, dayKey: String) {
        setOutcome(.dismissed, friendId: friendId, dayKey: dayKey)
    }

    public func isResolved(friendId: String, dayKey: String) -> Bool {
        records.first(where: { $0.friendId == friendId && $0.dayKey == dayKey })?.outcome != nil
    }

    /// `.imIn` replies whose target day is in the past and not yet confirmed/dismissed.
    public func pendingHangoutPrompts(now: Date = Date()) -> [PersistedNudgeReply] {
        let todayKey = AppNotification.dateString(from: now)
        return records.filter { record in
            record.response == AppNotification.NudgeResponse.imIn.rawValue
                && record.outcome == nil
                && record.dayKey < todayKey
        }
        .sorted { $0.dayKey < $1.dayKey }
    }

    public func resetAll() {
        records = []
        defaults.removeObject(forKey: scopedKey)
        reload()
    }

    // MARK: - Private

    private var scopedKey: String {
        guard let userId, !userId.isEmpty else { return recordsKeyBase }
        return "\(recordsKeyBase).\(userId)"
    }

    private func setOutcome(_ outcome: PersistedNudgeReply.Outcome, friendId: String, dayKey: String) {
        guard let index = records.firstIndex(where: { $0.friendId == friendId && $0.dayKey == dayKey }) else {
            return
        }
        if records[index].outcome == .confirmed { return }
        records[index].outcome = outcome
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: scopedKey)
        }
    }

    private func reload() {
        guard let data = defaults.data(forKey: scopedKey),
              let decoded = try? JSONDecoder().decode([PersistedNudgeReply].self, from: data) else {
            records = []
            return
        }
        records = decoded
    }
}
