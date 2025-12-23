//
//  AvailabilityRepository.swift
//  UFree
//
//  Created by Khang Vu on 22/12/25.
//

import Foundation

public protocol AvailabilityRepository {
    func getFriendsSchedules() async throws -> [UserSchedule]
    func updateMySchedule(for day: DayAvailability) async throws
    func getMySchedule() async throws -> UserSchedule
}

