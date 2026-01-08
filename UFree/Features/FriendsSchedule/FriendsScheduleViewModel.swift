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
}
