//
//  BondProgressStore.swift
//  UFree
//
//  Local per-friend hang / nudge counters. Never synced to Firestore.
//  Rewards presence only — no decay, no absence penalties.
//

import Foundation
import Combine

@MainActor
public final class BondProgressStore: ObservableObject {
    public static let shared = BondProgressStore()
    public static let hangMilestones: Set<Int> = [1, 5, 10]

    private let defaults: UserDefaults
    private var userId: String?
    private let hangsKeyBase = "ufree.bond.hangsConfirmed"
    private let nudgesKeyBase = "ufree.bond.nudgesExchanged"
    private let hangDaysKeyBase = "ufree.bond.hangDays"

    @Published private var hangsByFriend: [String: Int] = [:]
    @Published private var nudgesByFriend: [String: Int] = [:]
    private var confirmedHangDays: Set<String> = []

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reload()
    }

    public func bind(userId: String?) {
        self.userId = userId
        reload()
    }

    public func hangsConfirmed(for friendId: String) -> Int {
        hangsByFriend[friendId] ?? 0
    }

    public func hasRecordedHang(friendId: String, dayKey: String) -> Bool {
        confirmedHangDays.contains("\(friendId)|\(dayKey)")
    }

    public func nudgesExchanged(for friendId: String) -> Int {
        nudgesByFriend[friendId] ?? 0
    }

    public func incrementNudge(friendId: String) {
        nudgesByFriend[friendId, default: 0] += 1
        persist()
    }

    /// Idempotent per friend+day. Returns the new hang count when a milestone is hit.
    @discardableResult
    public func recordHang(friendId: String, dayKey: String) -> Int? {
        let hangKey = "\(friendId)|\(dayKey)"
        guard !confirmedHangDays.contains(hangKey) else { return nil }
        confirmedHangDays.insert(hangKey)
        let next = hangsByFriend[friendId, default: 0] + 1
        hangsByFriend[friendId] = next
        persist()
        if Self.hangMilestones.contains(next) {
            AnalyticsManager.logBondMilestoneReached(count: next)
            return next
        }
        return nil
    }

    public static func milestoneToast(friendName: String, count: Int) -> String {
        switch count {
        case 1:
            return "First hang with \(friendName)!"
        case 5:
            return "5 hangs with \(friendName)!"
        case 10:
            return "10 hangs with \(friendName)!"
        default:
            return "Hang with \(friendName) counted."
        }
    }

    public func resetAll() {
        hangsByFriend = [:]
        nudgesByFriend = [:]
        confirmedHangDays = []
        defaults.removeObject(forKey: scoped(hangsKeyBase))
        defaults.removeObject(forKey: scoped(nudgesKeyBase))
        defaults.removeObject(forKey: scoped(hangDaysKeyBase))
    }

    // MARK: - Private

    private func scoped(_ base: String) -> String {
        guard let userId, !userId.isEmpty else { return base }
        return "\(base).\(userId)"
    }

    private func persist() {
        defaults.set(hangsByFriend.mapValues { NSNumber(value: $0) }, forKey: scoped(hangsKeyBase))
        defaults.set(nudgesByFriend.mapValues { NSNumber(value: $0) }, forKey: scoped(nudgesKeyBase))
        defaults.set(Array(confirmedHangDays), forKey: scoped(hangDaysKeyBase))
    }

    private func reload() {
        hangsByFriend = intMap(forKey: scoped(hangsKeyBase))
        nudgesByFriend = intMap(forKey: scoped(nudgesKeyBase))
        if let days = defaults.array(forKey: scoped(hangDaysKeyBase)) as? [String] {
            confirmedHangDays = Set(days)
        } else {
            confirmedHangDays = []
        }
    }

    private func intMap(forKey key: String) -> [String: Int] {
        guard let raw = defaults.dictionary(forKey: key) else { return [:] }
        return raw.reduce(into: [:]) { result, pair in
            if let number = pair.value as? NSNumber {
                result[pair.key] = number.intValue
            } else if let int = pair.value as? Int {
                result[pair.key] = int
            }
        }
    }
}
