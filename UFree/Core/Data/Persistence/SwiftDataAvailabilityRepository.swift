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
    /// Bound Firebase Auth UID — scopes all reads/writes to this owner.
    private(set) var userId: String

    /// Initialize with a SwiftData ModelContainer
    /// - Parameter container: The configured ModelContainer
    /// - Parameter userId: Local user identifier (default: "local_user" until auth binds)
    public init(container: ModelContainer, userId: String = "local_user") {
        self.container = container
        self.context = ModelContext(container)
        self.userId = userId
    }

    /// Rebind to the signed-in Firebase UID so account switches cannot leak schedules.
    public func bind(userId: String) {
        self.userId = userId
    }

    /// Empty on purpose. A MainActor-isolated deallocation path under
    /// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` trips an iOS 26.2 XCTest bug:
    /// `pointer being freed was not allocated`.
    nonisolated deinit {}

    /// Fetch the current user's schedule from persistent storage
    /// - Returns: UserSchedule with all persisted DayAvailability objects
    /// - Note: If database is empty, generates initial 7-day schedule with .unknown status
    @MainActor
    public func getMySchedule() async throws -> UserSchedule {
        let owner = userId
        let descriptor = FetchDescriptor<PersistentDayAvailability>(
            predicate: #Predicate { $0.ownerUserId == owner },
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
        let owner = userId
        let descriptor = FetchDescriptor<PersistentDayAvailability>(
            predicate: #Predicate { $0.id == id && $0.ownerUserId == owner }
        )

        let stamp = day.updatedAt ?? Date()

        if let existing = try context.fetch(descriptor).first {
            existing.note = day.note
            existing.updatedAt = stamp
            existing.ownerUserId = owner

            existing.persistentTimeBlocks.forEach { context.delete($0) }

            existing.persistentTimeBlocks = day.timeBlocks.map { block in
                PersistentTimeBlock(
                    id: block.id,
                    startTime: block.startTime,
                    endTime: block.endTime,
                    statusValue: block.status.rawValue
                )
            }

            try context.save()
            #if DEBUG
            print("✅ SwiftData Updated: \(day.date.formatted()) with \(day.timeBlocks.count) blocks")
            #endif
        } else {
            // Prefer matching an existing row for the same calendar day (UUID may differ after remote sync)
            let dayKey = DateFormatter.yyyyMMdd.string(from: day.date)
            if let sameDay = try fetchOwnedDay(matchingDayKey: dayKey) {
                sameDay.note = day.note
                sameDay.updatedAt = stamp
                sameDay.persistentTimeBlocks.forEach { context.delete($0) }
                sameDay.persistentTimeBlocks = day.timeBlocks.map { block in
                    PersistentTimeBlock(
                        id: block.id,
                        startTime: block.startTime,
                        endTime: block.endTime,
                        statusValue: block.status.rawValue
                    )
                }
                // Keep stable local id unless remote provided a different one we should adopt
                try context.save()
                #if DEBUG
                print("✅ SwiftData Updated (same day): \(day.date.formatted())")
                #endif
            } else {
                let newPersistent = day.toPersistent(ownerUserId: owner)
                newPersistent.updatedAt = stamp
                context.insert(newPersistent)
                try context.save()
                #if DEBUG
                print("✅ SwiftData Inserted: \(day.date.formatted()) with \(day.timeBlocks.count) blocks")
                #endif
            }
        }
    }

    /// Marks a day as awaiting remote ack (or clears the flag after success).
    @MainActor
    public func setPendingSync(for day: DayAvailability, pending: Bool) async throws {
        let dayKey = DateFormatter.yyyyMMdd.string(from: day.date)
        let existing = try fetchOwnedDay(matchingDayKey: dayKey) ?? fetchOwnedDay(id: day.id)
        guard let existing else {
            // Ensure the day exists so pending survives process death
            var stamped = day
            stamped.updatedAt = day.updatedAt ?? Date()
            try await updateMySchedule(for: stamped)
            if let created = try fetchOwnedDay(matchingDayKey: dayKey) {
                created.isPendingSync = pending
                try context.save()
            }
            return
        }
        existing.isPendingSync = pending
        if let updatedAt = day.updatedAt {
            existing.updatedAt = updatedAt
        }
        try context.save()
    }

    /// Days that still need a successful remote write.
    @MainActor
    public func pendingDaysForSync() async throws -> [DayAvailability] {
        let owner = userId
        let descriptor = FetchDescriptor<PersistentDayAvailability>(
            predicate: #Predicate { $0.ownerUserId == owner && $0.isPendingSync == true },
            sortBy: [SortDescriptor(\.date)]
        )
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    /// Sync metadata for conflict checks (nil if no local row for that UTC day key).
    @MainActor
    public func syncState(forDayKey dayKey: String) async throws -> (isPending: Bool, updatedAt: Date)? {
        guard let day = try fetchOwnedDay(matchingDayKey: dayKey) else { return nil }
        return (day.isPendingSync, day.updatedAt)
    }

    /// Fetch friends' schedules (not applicable for local storage)
    /// - Returns: Empty array (friends' schedules come from Firebase)
    @MainActor
    public func getSchedules(for userIds: [String]) async throws -> [UserSchedule] {
        return [] // Local storage only has current user's schedule
    }

    // MARK: - Private Helpers

    @MainActor
    private func fetchOwnedDay(id: UUID) throws -> PersistentDayAvailability? {
        let owner = userId
        let descriptor = FetchDescriptor<PersistentDayAvailability>(
            predicate: #Predicate { $0.id == id && $0.ownerUserId == owner }
        )
        return try context.fetch(descriptor).first
    }

    @MainActor
    private func fetchOwnedDay(matchingDayKey dayKey: String) throws -> PersistentDayAvailability? {
        let owner = userId
        let descriptor = FetchDescriptor<PersistentDayAvailability>(
            predicate: #Predicate { $0.ownerUserId == owner }
        )
        let owned = try context.fetch(descriptor)
        return owned.first { DateFormatter.yyyyMMdd.string(from: $0.date) == dayKey }
    }

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
