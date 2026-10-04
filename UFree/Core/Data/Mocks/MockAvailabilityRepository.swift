//
//  MockAvailabilityRepository.swift
//  UFree
//
//  Created by Khang Vu on 22/12/25.
//

import Foundation

public class MockAvailabilityRepository: AvailabilityRepository {
    private var mySchedule: [DayAvailability]
    private var friendsSchedules: [String: [DayAvailability]]
    /// Incremented on each `getSchedules(for:)` call (test spy).
    public private(set) var getSchedulesCallCount: Int = 0
    /// When true, `updateMySchedule` throws so UI can show the offline/error path.
    public var shouldFailUpdates = false
    /// Each `observeSchedules` call, in order. Tests assert a friend-set change restarts the listen.
    public private(set) var observedUserIdBatches: [[String]] = []
    private var scheduleContinuation: AsyncStream<[UserSchedule]>.Continuation?

    public init() {
        // Pre-populate with some data for the next 7 days
        self.mySchedule = (0..<7).compactMap { i in
            guard let date = Calendar.current.date(byAdding: .day, value: i, to: Date()) else {
                return nil
            }
            return DayAvailability(date: date, status: .unknown)
        }
        self.friendsSchedules = [:]
    }

    /// Empty `nonisolated` deinit works around a Swift 6.2 / iOS 26.2 XCTest bug where
    /// MainActor-isolated class teardown aborts with "pointer being freed was not allocated".
    nonisolated deinit {}

    public func getSchedules(for userIds: [String]) async throws -> [UserSchedule] {
        getSchedulesCallCount += 1
        return schedules(for: userIds)
    }

    private func schedules(for userIds: [String]) -> [UserSchedule] {
        userIds.compactMap { userId in
            guard let days = friendsSchedules[userId] else { return nil }
            return UserSchedule(id: userId, name: "Friend", avatarURL: nil, weeklyStatus: days)
        }
    }

    public func observeSchedules(for userIds: [String]) -> AsyncStream<[UserSchedule]> {
        observedUserIdBatches.append(userIds)
        let current = schedules(for: userIds)
        return AsyncStream { continuation in
            scheduleContinuation = continuation
            continuation.yield(current)
        }
    }

    /// Push a live update to the most recent `observeSchedules` consumer.
    public func pushSchedules(_ schedules: [UserSchedule]) {
        for schedule in schedules {
            friendsSchedules[schedule.id] = schedule.weeklyStatus
        }
        scheduleContinuation?.yield(schedules)
    }

    public func getMySchedule() async throws -> UserSchedule {
        return UserSchedule(id: "me_123", name: "User", avatarURL: nil, weeklyStatus: mySchedule)
    }

    public func updateMySchedule(for day: DayAvailability) async throws {
        if shouldFailUpdates {
            throw NSError(
                domain: "MockAvailabilityRepository",
                code: -1009,
                userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."]
            )
        }
        let targetDate = Calendar.current.startOfDay(for: day.date)
        if let index = mySchedule.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: targetDate) }) {
            mySchedule[index] = day
            #if DEBUG
            print("✅ Mock DB Updated: \(day.date.formatted()) is now \(day.status.displayName)")
            #endif
        }
    }

    // MARK: - Testing Helpers

    /// Add mock friend schedule for testing
    public func addFriendSchedule(_ userSchedule: UserSchedule) {
        friendsSchedules[userSchedule.id] = userSchedule.weeklyStatus
    }

    /// Clear all mock data
    public func clearMockData() {
        friendsSchedules.removeAll()
        getSchedulesCallCount = 0
    }
}

