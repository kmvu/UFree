//
//  SwiftDataAvailabilityRepository.swift
//  UFree
//
//  Created by Khang Vu on 29/12/25.
//

import Foundation
import SwiftData

/// Production repository implementation using SwiftData for local persistence
/// Conforms to AvailabilityRepository protocol for seamless substitution
public final class SwiftDataAvailabilityRepository: AvailabilityRepository {
    private let container: ModelContainer
    private let context: ModelContext
    private let userId: String
    
    /// Initialize with a SwiftData ModelContainer
    /// - Parameter container: The configured ModelContainer
    /// - Parameter userId: Local user identifier (default: "local_user")
    public init(container: ModelContainer, userId: String = "local_user") {
        self.container = container
        self.context = ModelContext(container)
        self.userId = userId
    }

    /// Fetch the current user's schedule from persistent storage
    /// - Returns: UserSchedule with all persisted DayAvailability objects
    /// - Note: If database is empty, generates initial 7-day schedule with .unknown status
    @MainActor
    public func getMySchedule() async throws -> UserSchedule {
        let descriptor = FetchDescriptor<PersistentDayAvailability>(
            sortBy: [SortDescriptor(\.date)]
        )
        let persistentDays = try context.fetch(descriptor)
        let days = persistentDays.map { $0.toDomain() }
        
        // If no data exists, return schedule with generated 7 days
        let weeklyStatus = days.isEmpty ? generateNextSevenDays() : days
        
        return UserSchedule(
            id: userId,
            name: "Me",
            avatarURL: nil,
            weeklyStatus: weeklyStatus
        )
    }

    /// Update or create a day's availability status in persistent storage
    /// - Parameter day: DayAvailability with updated status and note
    /// - Throws: SwiftData errors on save failure
    @MainActor
    public func updateMySchedule(for day: DayAvailability) async throws {
        let id = day.id
        let descriptor = FetchDescriptor<PersistentDayAvailability>(
            predicate: #Predicate { $0.id == id }
        )
        
        if let existing = try context.fetch(descriptor).first {
            // Update existing record
            existing.statusValue = day.status.rawValue
            existing.note = day.note
            try context.save()
            print("✅ SwiftData Updated: \(day.date.formatted()) is now \(day.status.displayName)")
        } else {
            // Insert new record
            let newPersistent = PersistentDayAvailability(
                id: day.id,
                date: day.date,
                statusValue: day.status.rawValue,
                note: day.note
            )
            context.insert(newPersistent)
            try context.save()
            print("✅ SwiftData Inserted: \(day.date.formatted()) as \(day.status.displayName)")
        }
    }

    /// Fetch friends' schedules (Sprint 3 scope)
    /// - Returns: Empty array (not implemented in Sprint 2)
    @MainActor
    public func getFriendsSchedules() async throws -> [UserSchedule] {
        return []
    }
    
    // MARK: - Private Helpers
    
    /// Generate initial 7-day schedule starting from today with .unknown status
    private func generateNextSevenDays() -> [DayAvailability] {
        (0..<7).map { i in
            DayAvailability(
                date: Calendar.current.date(byAdding: .day, value: i, to: Date())!,
                status: .unknown
            )
        }
    }
}
