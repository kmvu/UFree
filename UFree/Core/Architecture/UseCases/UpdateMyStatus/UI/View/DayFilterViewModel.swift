//
//  DayFilterViewModel.swift
//  UFree
//
//  Created by Khang Vu on 01/01/26.
//

import Foundation
import Combine

@MainActor
final class DayFilterViewModel: ObservableObject {
    @Published var selectedDay: Date?
    
    private let friendRepository: FriendRepositoryProtocol
    private let availabilityRepository: AvailabilityRepository
    
    // MARK: - Initialization
    
    init(friendRepository: FriendRepositoryProtocol = MockFriendRepository(),
         availabilityRepository: AvailabilityRepository = MockAvailabilityRepository()) {
        self.friendRepository = friendRepository
        self.availabilityRepository = availabilityRepository
    }
    
    // MARK: - Day Selection
    
    func toggleDay(_ date: Date) {
        // Set or clear the selected day
        if selectedDay == date {
            selectedDay = nil
        } else {
            selectedDay = date
        }
    }

    func clearSelection() {
        selectedDay = nil
    }
    
    // MARK: - Availability Heatmap (Phase 1 - Sprint 6)
    
    /// Counts how many friends are "Free" on a specific date
    /// - Parameters:
    ///   - date: The date to check
    ///   - friendsSchedules: Array of friend UserSchedule objects
    /// - Returns: Count of friends with .free status on the given date
    func freeFriendCount(for date: Date, friendsSchedules: [UserSchedule]) -> Int {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        
        return friendsSchedules.filter { schedule in
            schedule.weeklyStatus.contains { dayAvail in
                Calendar.current.isDate(dayAvail.date, inSameDayAs: normalizedDate) &&
                dayAvail.status == .free
            }
        }.count
    }
    
    /// Calculates the next 7 days from today for the heatmap
    var nextSevenDays: [Date] {
        let today = Calendar.current.startOfDay(for: Date())
        return (0..<7).compactMap { dayOffset in
            Calendar.current.date(byAdding: .day, value: dayOffset, to: today)
        }
    }
}
