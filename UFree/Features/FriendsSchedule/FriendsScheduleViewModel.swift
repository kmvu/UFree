//
//  FriendsScheduleViewModel.swift
//  UFree
//
//  Created by Khang Vu on 07/01/26.
//

import Foundation
import Combine

@MainActor
public final class FriendsScheduleViewModel: ObservableObject {
    @Published public var friendSchedules: [FriendScheduleDisplay] = []
    @Published public var isLoading = false
    @Published public var isNudging = false
    @Published public var errorMessage: String?
    @Published public var successMessage: String?

    private let friendRepository: FriendRepositoryProtocol
    private let availabilityRepository: AvailabilityRepository
    private let notificationRepository: NotificationRepository

    /// Display model combining friend info with their schedule
    public struct FriendScheduleDisplay: Identifiable {
        public let id: String
        public let displayName: String
        public let userSchedule: UserSchedule

        public init(id: String, displayName: String, userSchedule: UserSchedule) {
            self.id = id
            self.displayName = displayName
            self.userSchedule = userSchedule
        }

        /// Get availability status for a specific date
        public func status(for date: Date) -> AvailabilityStatus {
            return userSchedule.status(for: date)?.status ?? .unknown
        }
    }

    public init(
        friendRepository: FriendRepositoryProtocol,
        availabilityRepository: AvailabilityRepository,
        notificationRepository: NotificationRepository
    ) {
        self.friendRepository = friendRepository
        self.availabilityRepository = availabilityRepository
        self.notificationRepository = notificationRepository
    }

    /// Counts how many friends are "Free" on a specific date (Phase 1 - Sprint 6 heatmap)
    /// Only counts .free status (excludes afternoonOnly, eveningOnly, busy, unknown)
    public func freeFriendCount(for date: Date, friendsSchedules: [FriendScheduleDisplay]) -> Int {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        
        return friendsSchedules.filter { display in
            display.status(for: normalizedDate) == .free
        }.count
    }
    
    public func loadFriendsSchedules() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // 1. Get my friends list
            let friends = try await friendRepository.getMyFriends()
            let friendIds = friends.compactMap { $0.id }

            if friendIds.isEmpty {
                self.friendSchedules = []
                return
            }

            // 2. Fetch their schedules in parallel
            let schedules = try await availabilityRepository.getSchedules(for: friendIds)

            // 3. Merge friend profiles with their schedules
            self.friendSchedules = friends.compactMap { friend in
                guard let friendId = friend.id,
                      let userSchedule = schedules.first(where: { $0.id == friendId }) else {
                    return nil
                }
                return FriendScheduleDisplay(
                    id: friendId,
                    displayName: friend.displayName,
                    userSchedule: userSchedule
                )
            }

            // If no schedules found for any friends, log it but don't error
            if friendSchedules.isEmpty && !friends.isEmpty {
                print("⚠️ No schedules found for \(friends.count) friends")
            }

        } catch {
            self.errorMessage = "Failed to load friends' schedules: \(error.localizedDescription)"
            print("❌ Error loading friends schedules: \(error)")
        }
    }

    public func sendNudge(to userId: String) async {
        // Rapid-tap protection: guard against concurrent nudges
        guard !isNudging else { return }

        isNudging = true
        errorMessage = nil
        defer { isNudging = false }

        do {
            try await notificationRepository.sendNudge(to: userId)
            HapticManager.success()
        } catch {
            self.errorMessage = "Failed to send nudge: \(error.localizedDescription)"
            HapticManager.warning()
            print("❌ Error sending nudge to \(userId): \(error)")
        }
    }

    /// Sends nudge notifications to all friends who are free on a specific day (Phase 3 - Sprint 6)
    /// Uses parallel processing with TaskGroup for performance
    public func nudgeAllFree(for date: Date) async {
        // Rapid-tap protection: guard against concurrent group nudges
        guard !isNudging else { return }

        isNudging = true
        errorMessage = nil
        successMessage = nil
        defer { isNudging = false }

        // Normalize date
        let normalizedDate = Calendar.current.startOfDay(for: date)

        // Filter friends who are free on this date
        let freeFriendIds = friendSchedules
            .filter { display in
                display.status(for: normalizedDate) == .free
            }
            .map { $0.id }

        // Early exit if no friends are free
        guard !freeFriendIds.isEmpty else {
            self.errorMessage = "No friends available to nudge on this day"
            HapticManager.warning()
            return
        }

        // Haptic feedback: immediate medium feedback on tap
        HapticManager.medium()

        // Parallel processing: use TaskGroup to send nudges concurrently
        do {
            var successCount = 0

            try await withThrowingTaskGroup(of: Bool.self) { group in
                for friendId in freeFriendIds {
                    group.addTask {
                        do {
                            try await self.notificationRepository.sendNudge(to: friendId)
                            return true  // Success
                        } catch {
                            print("⚠️ Failed to nudge \(friendId): \(error)")
                            return false  // Failure
                        }
                    }
                }

                // Wait for all tasks to complete and count successes
                for try await success in group {
                    if success {
                        successCount += 1
                    }
                }
            }

            // Set success message with count
            let totalCount = freeFriendIds.count
            if successCount == totalCount {
                // All succeeded
                let friendWord = totalCount == 1 ? "friend" : "friends"
                self.successMessage = "All \(totalCount) \(friendWord) nudged! 👋"
                HapticManager.success()
            } else if successCount > 0 {
                // Partial success
                self.successMessage = "Nudged \(successCount) of \(totalCount) friends"
                HapticManager.warning()
            } else {
                // All failed
                self.errorMessage = "Failed to nudge friends. Please try again."
                HapticManager.warning()
            }

            print("✅ Group nudge complete: \(successCount) of \(freeFriendIds.count) succeeded")

        } catch {
            self.errorMessage = "Failed to send group nudges: \(error.localizedDescription)"
            HapticManager.warning()
            print("❌ Error in group nudge: \(error)")
        }
    }
}
