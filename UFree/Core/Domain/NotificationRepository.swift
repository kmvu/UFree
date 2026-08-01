//
//  NotificationRepository.swift
//  UFree
//
//  Created by Khang Vu on 08/01/26.
//

import Foundation

public protocol NotificationRepository {
    func listenToNotifications() -> AsyncStream<[AppNotification]>
    func markAsRead(_ notification: AppNotification) async throws
    func sendNudge(to userId: String, targetDate: Date?) async throws
    func sendNudgeReply(
        to userId: String,
        targetDateString: String?,
        response: AppNotification.NudgeResponse
    ) async throws
    func markNudgeResponded(_ notification: AppNotification, response: AppNotification.NudgeResponse) async throws

    /// Registers/updates the APNs device token for push notifications
    func updatePushToken(_ token: String) async throws
}

public extension NotificationRepository {
    func sendNudge(to userId: String) async throws {
        try await sendNudge(to: userId, targetDate: nil)
    }
}
