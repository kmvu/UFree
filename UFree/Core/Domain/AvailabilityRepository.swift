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
}

