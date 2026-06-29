//
//  CompositeAvailabilityRepository.swift
//  UFree
//
//  Created by Khang Vu on 3/1/26.
//

import Foundation

/// Composite repository orchestrating local-first + background remote sync.
/// Implements the "Write-Through, Read-Back" offline-first resilience pattern.
///
/// Strategy:
/// - updateMySchedule: Update local (instant) → sync remote (fire-and-forget, non-blocking)
/// - getMySchedule: Return local (fast) → refresh from remote in background
///
/// This ensures the UI never blocks on network calls while keeping data in sync.
class CompositeAvailabilityRepository: AvailabilityRepository {
    private let local: AvailabilityRepository
    private let remote: AvailabilityRepository

    // MARK: - Initialization

    init(local: AvailabilityRepository, remote: AvailabilityRepository) {
        self.local = local
        self.remote = remote
    }

    // MARK: - Update Logic (Write-Through)

    func updateMySchedule(for day: DayAvailability) async throws {
        // 1. Update Local (Instant)
        // This ensures the UI reflects the change immediately.
        try await local.updateMySchedule(for: day)

        // 2. Update Remote (Background)
        // We use a detached Task to fire-and-forget the cloud update.
        // If it fails, the local version remains the source of truth for now.
        Task.detached {
            do {
                try await self.remote.updateMySchedule(for: day)
                print("☁️ Remote sync successful for \(day.date.formatted(date: .abbreviated, time: .omitted))")
            } catch {
                print("⚠️ Remote sync failed: \(error.localizedDescription)")
                // Future improvement: Add a 'pending sync' flag to the local DB
            }
        }
    }

    // MARK: - Fetch Logic (Read-Back)

    func getMySchedule() async throws -> UserSchedule {
        // 1. Get Local Data immediately for a fast UI start
        let localSchedule = try await local.getMySchedule()

        // 2. Refresh from Remote in the background
        Task.detached {
            do {
                let remoteSchedule = try await self.remote.getMySchedule()

                // Sync remote days back into local storage, but only if they have a known status
                // (Avoid overwriting local data with "unknown" gap-filler values)
                for day in remoteSchedule.weeklyStatus {
                    if day.status != .unknown {
                        try await self.local.updateMySchedule(for: day)
                    }
                }
                print("🔄 Local storage refreshed from Cloud")
            } catch {
                print("⚠️ Could not refresh from remote: \(error.localizedDescription)")
            }
        }

        return localSchedule
    }

    // MARK: - Friends Schedules (Remote-First)

    func getSchedules(for userIds: [String]) async throws -> [UserSchedule] {
        // Friends' schedules are always remote-first
        return try await remote.getSchedules(for: userIds)
    }
}
