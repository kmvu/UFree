//
//  CompositeAvailabilityRepository.swift
//  UFree
//
//  Created by Khang Vu on 3/1/26.
//

import Foundation
import Network
#if canImport(UIKit)
import UIKit
#endif

/// Composite repository orchestrating local-first + background remote sync.
/// Implements the "Write-Through, Read-Back" offline-first resilience pattern.
///
/// Strategy:
/// - updateMySchedule: Update local (instant) → mark pending → sync remote → clear pending
/// - getMySchedule: Return local (fast) → refresh from remote only when not pending / newer
/// - Retries pending writes on foreground and network regain
class CompositeAvailabilityRepository: AvailabilityRepository {
    private let local: AvailabilityRepository
    private let remote: AvailabilityRepository
    private let localStore: SwiftDataAvailabilityRepository?
    private let pathMonitor: NWPathMonitor
    private let pathMonitorQueue = DispatchQueue(label: "com.ufree.availability.pathMonitor")
    /// In-memory pending queue (also mirrored to SwiftData when available).
    private var pendingByDayKey: [String: DayAvailability] = [:]
    private var foregroundObserver: NSObjectProtocol?

    // MARK: - Initialization

    init(
        local: AvailabilityRepository,
        remote: AvailabilityRepository,
        observesLifecycle: Bool = true
    ) {
        self.local = local
        self.remote = remote
        self.localStore = local as? SwiftDataAvailabilityRepository
        self.pathMonitor = NWPathMonitor()
        if observesLifecycle {
            observeLifecycle()
        }
    }

    /// Empty on purpose. A MainActor-isolated deallocation path under
    /// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` trips an iOS 26.2 XCTest bug:
    /// `pointer being freed was not allocated`.
    nonisolated deinit {
        // pathMonitor and observer cleaned on MainActor via stopObserving if needed;
        // avoid MainActor work in deinit (XCTest crash).
    }

    // MARK: - Update Logic (Write-Through)

    func updateMySchedule(for day: DayAvailability) async throws {
        var stamped = day
        stamped.updatedAt = Date()

        // 1. Update Local (Instant)
        try await local.updateMySchedule(for: stamped)

        let key = Self.dayKey(stamped.date)
        pendingByDayKey[key] = stamped
        try await localStore?.setPendingSync(for: stamped, pending: true)

        // 2. Update Remote (Background)
        let remote = self.remote
        Task { @MainActor [weak self] in
            do {
                try await remote.updateMySchedule(for: stamped)
                self?.pendingByDayKey.removeValue(forKey: key)
                try await self?.localStore?.setPendingSync(for: stamped, pending: false)
                #if DEBUG
                print("☁️ Remote sync successful for \(stamped.date.formatted(date: .abbreviated, time: .omitted))")
                #endif
            } catch {
                #if DEBUG
                print("⚠️ Remote sync failed (kept pending): \(error.localizedDescription)")
                #endif
            }
        }
    }

    // MARK: - Fetch Logic (Read-Back)

    func getMySchedule() async throws -> UserSchedule {
        let localSchedule = try await local.getMySchedule()

        let remote = self.remote
        let local = self.local
        Task { @MainActor [weak self] in
            do {
                let remoteSchedule = try await remote.getMySchedule()

                for day in remoteSchedule.weeklyStatus where day.status != .unknown {
                    guard let self else { return }
                    let key = Self.dayKey(day.date)

                    if self.pendingByDayKey[key] != nil {
                        continue
                    }

                    if let state = try await self.localStore?.syncState(forDayKey: key) {
                        if state.isPending { continue }
                        if let remoteUpdated = day.updatedAt, state.updatedAt >= remoteUpdated {
                            continue
                        }
                    } else if let localDay = localSchedule.weeklyStatus.first(where: {
                        Self.dayKey($0.date) == key
                    }), let localUpdated = localDay.updatedAt,
                       let remoteUpdated = day.updatedAt,
                       localUpdated >= remoteUpdated {
                        continue
                    }

                    try await local.updateMySchedule(for: day)
                }
                #if DEBUG
                print("🔄 Local storage refreshed from Cloud")
                #endif
            } catch {
                #if DEBUG
                print("⚠️ Could not refresh from remote: \(error.localizedDescription)")
                #endif
            }

            await self?.retryPendingSync()
        }

        return localSchedule
    }

    // MARK: - Friends Schedules (Remote-First)

    func getSchedules(for userIds: [String]) async throws -> [UserSchedule] {
        return try await remote.getSchedules(for: userIds)
    }

    // MARK: - Pending Sync

    /// Retry dirty local days that never received a remote ack.
    @MainActor
    func retryPendingSync() async {
        var candidates = Array(pendingByDayKey.values)
        if let stored = try? await localStore?.pendingDaysForSync() {
            for day in stored {
                let key = Self.dayKey(day.date)
                if pendingByDayKey[key] == nil {
                    pendingByDayKey[key] = day
                    candidates.append(day)
                }
            }
        }

        guard !candidates.isEmpty else { return }

        for day in candidates {
            let key = Self.dayKey(day.date)
            do {
                try await remote.updateMySchedule(for: day)
                pendingByDayKey.removeValue(forKey: key)
                try await localStore?.setPendingSync(for: day, pending: false)
                #if DEBUG
                print("☁️ Pending sync flushed for \(key)")
                #endif
            } catch {
                #if DEBUG
                print("⚠️ Pending sync still failing for \(key): \(error.localizedDescription)")
                #endif
            }
        }
    }

    /// Shared flush used by foreground and path-monitor regain.
    @MainActor
    func handleConnectivityRestored() async {
        await retryPendingSync()
    }

    // MARK: - Lifecycle

    private func observeLifecycle() {
        #if canImport(UIKit)
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleConnectivityRestored()
            }
        }
        #endif

        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in
                await self?.handleConnectivityRestored()
            }
        }
        pathMonitor.start(queue: pathMonitorQueue)
    }

    private static func dayKey(_ date: Date) -> String {
        DateFormatter.yyyyMMdd.string(from: date)
    }
}
