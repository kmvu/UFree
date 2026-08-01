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

    /// Empty on purpose. A MainActor-isolated deallocation path under
    /// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` trips an iOS 26.2 XCTest bug:
    /// `pointer being freed was not allocated`.
    nonisolated deinit {}

    // MARK: - Update Logic (Write-Through)

    func updateMySchedule(for day: DayAvailability) async throws {
        // 1. Update Local (Instant)
        // This ensures the UI reflects the change immediately.
        try await local.updateMySchedule(for: day)

        // 2. Update Remote (Background)
        // Use a MainActor-bound unstructured Task (not detached) so background sync
        // participates in the cooperative pool — deterministic in XCTest via drainPendingTasks().
        // Capture repos only (not `self`) so teardown does not race XCTest deallocation.
        let remote = self.remote
        Task { @MainActor in
            do {
                try await remote.updateMySchedule(for: day)
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
        let remote = self.remote
        let local = self.local
        Task { @MainActor in
            do {
                let remoteSchedule = try await remote.getMySchedule()

                // Sync remote days back into local storage, but only if they have a known status
                // (Avoid overwriting local data with "unknown" gap-filler values)
                for day in remoteSchedule.weeklyStatus {
                    if day.status != .unknown {
                        try await local.updateMySchedule(for: day)
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
