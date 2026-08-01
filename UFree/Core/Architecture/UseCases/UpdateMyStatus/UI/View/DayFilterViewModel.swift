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

    /// Empty on purpose. A MainActor-isolated deallocation path under
    /// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` trips an iOS 26.2 XCTest bug:
    /// `pointer being freed was not allocated`.
    nonisolated deinit {}
    
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
    
    /// Counts friends with any free window on a specific date (full-day or partial).
    func freeFriendCount(for date: Date, friendsSchedules: [UserSchedule]) -> Int {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        
        return friendsSchedules.filter { schedule in
            schedule.weeklyStatus.contains { dayAvail in
                Calendar.current.isDate(dayAvail.date, inSameDayAs: normalizedDate)
                    && dayAvail.isAvailable
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
