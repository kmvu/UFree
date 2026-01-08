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
    func sendNudge(to userId: String) async throws
}
