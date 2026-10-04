//
//  AvailabilityRepository.swift
//  UFree
//
//  Created by Khang Vu on 22/12/25.
//

import Foundation

public protocol AvailabilityRepository {
    /// Fetches schedules for the next 7 days for a list of friend IDs.
    func getSchedules(for userIds: [String]) async throws -> [UserSchedule]
    
    /// Fetches the current user's schedule for the next 7 days.
    func getMySchedule() async throws -> UserSchedule
    
    /// Updates a specific day in the current user's schedule.
    func updateMySchedule(for day: DayAvailability) async throws

    /// Live schedules for the given friends. Emits the current window, then each change.
    /// The stream ends when the consumer cancels.
    func observeSchedules(for userIds: [String]) -> AsyncStream<[UserSchedule]>
}

public extension AvailabilityRepository {
    /// One-shot stand-in so test spies keep compiling. Live repositories override this.
    func observeSchedules(for userIds: [String]) -> AsyncStream<[UserSchedule]> {
        let ids = userIds
        return AsyncStream { continuation in
            let task = Task {
                let schedules = (try? await getSchedules(for: ids)) ?? []
                continuation.yield(schedules)
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

