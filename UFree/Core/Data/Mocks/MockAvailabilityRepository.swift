//
//  MockAvailabilityRepository.swift
//  UFree
//
//  Created by Khang Vu on 22/12/25.
//

import Foundation

public actor MockAvailabilityRepository: AvailabilityRepository {
    private var mySchedule: [DayAvailability]

    public init() {
        // Pre-populate with some data for the next 7 days
        self.mySchedule = (0..<7).map { i in
            DayAvailability(
                date: Calendar.current.date(byAdding: .day, value: i, to: Date())!,
                status: .busy
            )
        }
    }

    public nonisolated func getFriendsSchedules() async throws -> [UserSchedule] {
        return []
    }

    public func getMySchedule() async throws -> UserSchedule {
        return UserSchedule(id: "me_123", name: "User", avatarURL: nil, weeklyStatus: mySchedule)
    }

    public func updateMySchedule(for day: DayAvailability) async throws {
        let targetDate = Calendar.current.startOfDay(for: day.date)
        if let index = mySchedule.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: targetDate) }) {
            mySchedule[index] = day
            print("✅ Mock DB Updated: \(day.date.formatted()) is now \(day.status.displayName)")
        }
    }
}

