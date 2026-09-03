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
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var successMessage: String?
    @Published public var isNudging: Bool = false
    @Published public var selectedDate: Date?
    /// Latest nudge replies keyed by `friendId|yyyy-MM-dd`.
    @Published public private(set) var nudgeRepliesByFriendDay: [String: AppNotification.NudgeResponse] = [:]

    private let friendRepository: FriendRepositoryProtocol
    private let availabilityRepository: AvailabilityRepository
    private let notificationRepository: NotificationRepository

    /// Display model combining friend info with their schedule
    public struct FriendScheduleDisplay: Identifiable {
        public let id: String
        public let displayName: String
        public var userSchedule: UserSchedule

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
        
        // Default selectedDate to today
        self.selectedDate = Calendar.current.startOfDay(for: Date())
    }

    /// Empty `nonisolated` deinit works around a Swift 6.2 / iOS 26.2 XCTest bug where
    /// MainActor-isolated class teardown aborts with "pointer being freed was not allocated".
    nonisolated deinit {}

    // MARK: - Date Selection
    
    public func toggleDate(_ date: Date) {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        if let current = selectedDate, Calendar.current.isDate(current, inSameDayAs: normalizedDate) {
            selectedDate = nil
        } else {
            selectedDate = normalizedDate
        }
    }

    /// Focus a day chip without toggling off when already selected.
    public func focusDate(_ date: Date) {
        selectedDate = Calendar.current.startOfDay(for: date)
    }

    /// Next free day for a friend (today or later), if any.
    public func nextFreeDate(forFriendId friendId: String, from reference: Date = Date()) -> Date? {
        let start = Calendar.current.startOfDay(for: reference)
        guard let display = friendSchedules.first(where: { $0.id == friendId }) else { return nil }
        return display.userSchedule.weeklyStatus
            .filter { $0.isAvailable && Calendar.current.startOfDay(for: $0.date) >= start }
            .sorted { $0.date < $1.date }
            .first
            .map { Calendar.current.startOfDay(for: $0.date) }
    }

    /// Resolve friend id by display name for mission-chip targeting.
    public func friendId(named displayName: String) -> String? {
        friendSchedules.first(where: { $0.displayName == displayName })?.id
            ?? friendSchedules.first?.id
    }

    // MARK: - Nudge replies (inviter Who's Free)

    public func nudgeReplyKey(friendId: String, date: Date) -> String {
        "\(friendId)|\(AppNotification.dateString(from: date))"
    }

    public func nudgeReply(forFriendId friendId: String, date: Date) -> AppNotification.NudgeResponse? {
        nudgeRepliesByFriendDay[nudgeReplyKey(friendId: friendId, date: date)]
    }

    /// Apply an incoming `.nudgeReply` so Who's Free shows In/Maybe/Busy immediately.
    public func applyNudgeReply(from note: AppNotification) {
        guard note.type == .nudgeReply,
              let response = note.nudgeResponse.flatMap(AppNotification.NudgeResponse.init(rawValue:)) else {
            return
        }
        let targetDate = note.targetDateString.flatMap(AppNotification.date(from:))
        applyNudgeReply(from: note.senderId, response: response, targetDate: targetDate)
    }

    public func applyNudgeReply(
        from senderId: String,
        response: AppNotification.NudgeResponse,
        targetDate: Date?
    ) {
        let day = Calendar.current.startOfDay(for: targetDate ?? selectedDate ?? Date())
        nudgeRepliesByFriendDay[nudgeReplyKey(friendId: senderId, date: day)] = response
        focusDate(day)

        if response == .imIn || response == .busy {
            patchFriendAvailability(
                friendId: senderId,
                date: day,
                status: response == .imIn ? .free : .busy
            )
        }
    }

    private func patchFriendAvailability(
        friendId: String,
        date: Date,
        status: AvailabilityStatus
    ) {
        guard let index = friendSchedules.firstIndex(where: { $0.id == friendId }) else { return }
        var display = friendSchedules[index]
        var schedule = display.userSchedule
        if let dayIndex = schedule.weeklyStatus.firstIndex(where: {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }) {
            schedule.weeklyStatus[dayIndex].status = status
        } else {
            schedule.weeklyStatus.append(DayAvailability(date: date, status: status))
        }
        display.userSchedule = schedule
        friendSchedules[index] = display
    }

    private func reapplyNudgeReplyPatches() {
        for (key, response) in nudgeRepliesByFriendDay {
            let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  let date = AppNotification.date(from: parts[1]),
                  response == .imIn || response == .busy else { continue }
            patchFriendAvailability(
                friendId: parts[0],
                date: date,
                status: response == .imIn ? .free : .busy
            )
        }
    }

    // MARK: - Data Loading

    /// Counts friends with any free window on a specific date (full-day or partial).
    public func freeFriendCount(for date: Date, friendsSchedules: [FriendScheduleDisplay]) -> Int {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        
        return friendsSchedules.filter { display in
            guard let day = display.userSchedule.weeklyStatus.first(where: {
                Calendar.current.isDate($0.date, inSameDayAs: normalizedDate)
            }) else {
                return false
            }
            return day.isAvailable
        }.count
    }

    /// True when my schedule has any free window on `date`.
    public func isMeFree(on date: Date, mySchedule: [DayAvailability]) -> Bool {
        guard let day = mySchedule.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }) else {
            return false
        }
        return day.isAvailable
    }

    /// True when the friend is available on `date` and I am also free that day.
    public func isBothFree(
        friendDisplay: FriendScheduleDisplay,
        on date: Date,
        mySchedule: [DayAvailability]
    ) -> Bool {
        guard isMeFree(on: date, mySchedule: mySchedule) else { return false }
        guard let day = friendDisplay.userSchedule.weeklyStatus.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }) else {
            return false
        }
        return day.isAvailable
    }

    /// True when friends exist but every day in `days` is still unset (unknown).
    public func hasUnknownOnlyFriends(
        in friendsSchedules: [FriendScheduleDisplay],
        days: [Date]
    ) -> Bool {
        guard !friendsSchedules.isEmpty, !days.isEmpty else { return false }
        return friendsSchedules.allSatisfy { display in
            days.allSatisfy { date in
                let day = display.userSchedule.weeklyStatus.first(where: {
                    Calendar.current.isDate($0.date, inSameDayAs: date)
                })
                let status = day?.status ?? .unknown
                let blocks = day?.timeBlocks ?? []
                return status == .unknown
                    && !AvailabilityTruth.isAvailable(status: status, timeBlocks: blocks)
            }
        }
    }
    
    public func loadFriendsSchedules(showLoading: Bool = true) async {
        if showLoading {
            isLoading = true
        }
        errorMessage = nil
        defer {
            if showLoading {
                isLoading = false
            }
        }

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

            // Keep optimistic In/Busy patches if the remote schedule is still catching up.
            reapplyNudgeReplyPatches()

            // If no schedules found for any friends, log it but don't error
            if friendSchedules.isEmpty && !friends.isEmpty {
                #if DEBUG
                print("⚠️ No schedules found for \(friends.count) friends")
                #endif
            }

        } catch {
            // Quota Resilience: Handle Firestore Quota Exhaustion (code 8)
            let nsError = error as NSError
            if nsError.domain == "FirestoreErrorDomain" && nsError.code == 8 {
                errorMessage = "Quota exhausted. Discovery functions are currently limited."
            } else {
                self.errorMessage = "Failed to load friends' schedules: \(error.localizedDescription)"
            }
            #if DEBUG
            print("❌ Error loading friends schedules: \(error)")
            #endif
        }
    }

    public func sendNudge(to userId: String, targetDate: Date? = nil) async {
        // Rapid-tap protection: guard against concurrent nudges
        guard !isNudging else { return }

        isNudging = true
        errorMessage = nil
        defer { isNudging = false }

        do {
            let day = targetDate ?? selectedDate
            try await notificationRepository.sendNudge(to: userId, targetDate: day)
            AnalyticsManager.logNudgeSent(isBatch: false)
            OnboardingProgressStore.shared.recordWeekendActivity()
            OnboardingProgressStore.shared.dismissPostConnectCoach()
            HapticManager.success()
        } catch {
            self.errorMessage = "Failed to send nudge: \(error.localizedDescription)"
            HapticManager.warning()
            #if DEBUG
            print("❌ Error sending nudge to \(userId): \(error)")
            #endif
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

        // Filter friends who have any free window on this date
        let freeFriendIds = friendSchedules
            .filter { display in
                guard let day = display.userSchedule.weeklyStatus.first(where: {
                    Calendar.current.isDate($0.date, inSameDayAs: normalizedDate)
                }) else {
                    return false
                }
                return day.isAvailable
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
                            try await self.notificationRepository.sendNudge(
                                to: friendId,
                                targetDate: normalizedDate
                            )
                            return true  // Success
                        } catch {
                            #if DEBUG
                            print("⚠️ Failed to nudge \(friendId): \(error)")
                            #endif
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
            
            // Log analytics if any nudges succeeded
            if successCount > 0 {
                AnalyticsManager.logNudgeSent(isBatch: true)
                AnalyticsManager.logBatchNudge(recipientCount: successCount)
                OnboardingProgressStore.shared.dismissPostConnectCoach()
            }
            
            let dayLabel = normalizedDate.formatted(.dateTime.weekday(.abbreviated))
            if successCount == totalCount {
                // All succeeded
                let friendWord = totalCount == 1 ? "friend" : "friends"
                self.successMessage = "Asked all \(totalCount) \(friendWord) about \(dayLabel)"
                OnboardingProgressStore.shared.recordWeekendActivity()
                HapticManager.success()
            } else if successCount > 0 {
                // Partial success
                self.successMessage = "Nudged \(successCount) of \(totalCount) friends for \(dayLabel)"
                OnboardingProgressStore.shared.recordWeekendActivity()
                HapticManager.warning()
            } else {
                // All failed
                self.errorMessage = "Failed to nudge friends. Please try again."
                HapticManager.warning()
            }

            #if DEBUG
            print("✅ Group nudge complete: \(successCount) of \(freeFriendIds.count) succeeded")
            #endif

        } catch {
            self.errorMessage = "Failed to send group nudges: \(error.localizedDescription)"
            HapticManager.warning()
            #if DEBUG
            print("❌ Error in group nudge: \(error)")
            #endif
        }
    }
}
