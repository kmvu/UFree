//
//  MockAvailabilityRepository.swift
//  UFree
//
//  Created by Khang Vu on 22/12/25.
//

import Foundation

public actor MockAvailabilityRepository: AvailabilityRepository {
    // In-memory storage for our mock data
    private var mySchedule: [DayAvailability]

    public init() {
        // Pre-populate with some data for the next 7 days
        self.mySchedule = (0..<7).map { i in
            DayAvailability(
                date: Calendar.current.date(byAdding: .day, value: i, to: Date())!,
                status: .unknown
            )
        }
    }

    public func getFriendsSchedules() async throws -> [UserSchedule] {
        // Return dummy data for later features
        return []
    }

    public func getMySchedule() async throws -> UserSchedule {
        // Simulate a network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        return UserSchedule(id: "me_123", name: "User", avatarURL: nil, weeklyStatus: mySchedule)
    }

    public func updateMySchedule(for day: DayAvailability) async throws {
        // Simulate a network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Update the in-memory array
        if let index = mySchedule.firstIndex(where: { $0.id == day.id }) {
            mySchedule[index] = day
            print("✅ Mock DB Updated: \(day.date.formatted()) is now \(day.status.displayName)")
        }
    }
}

