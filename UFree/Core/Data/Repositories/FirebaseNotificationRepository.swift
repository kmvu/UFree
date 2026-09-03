//
//  FirebaseNotificationRepository.swift
//  UFree
//
//  Created by Khang Vu on 08/01/26.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

public class FirebaseNotificationRepository: NotificationRepository {
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    
    public init() {}

    /// Empty on purpose. A MainActor-isolated deallocation path under
    /// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` trips an iOS 26.2 XCTest bug:
    /// `pointer being freed was not allocated`.
    nonisolated deinit {}
    
    public nonisolated func listenToNotifications() -> AsyncStream<[AppNotification]> {
        AsyncStream { continuation in
            guard let uid = auth.currentUser?.uid else {
                continuation.finish()
                return
            }
            
            // Listen to my notifications, ordered by newest first
            let listener = db.collection("users").document(uid).collection("notifications")
                .order(by: "date", descending: true)
                .limit(to: 50)
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        #if DEBUG
                        print("Error listening to notifications: \(error)")
                        #endif
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    let notes = documents.compactMap { try? $0.data(as: AppNotification.self) }
                    continuation.yield(notes)
                }
            
            continuation.onTermination = { _ in listener.remove() }
        }
    }
    
    public func markAsRead(_ notification: AppNotification) async throws {
        guard let uid = auth.currentUser?.uid, let noteId = notification.id else { return }
        
        try await db.collection("users").document(uid).collection("notifications")
            .document(noteId)
            .updateData(["isRead": true])
    }

    public func markAsUnread(_ notification: AppNotification) async throws {
        guard let uid = auth.currentUser?.uid, let noteId = notification.id else { return }

        try await db.collection("users").document(uid).collection("notifications")
            .document(noteId)
            .updateData(["isRead": false])
    }

    public func deleteNotification(_ notification: AppNotification) async throws {
        guard let uid = auth.currentUser?.uid, let noteId = notification.id else { return }

        try await db.collection("users").document(uid).collection("notifications")
            .document(noteId)
            .delete()
    }
    
    public func sendNudge(to userId: String, targetDate: Date?) async throws {
        guard let currentUid = auth.currentUser?.uid else {
            throw NSError(
                domain: "FirebaseNotificationRepository",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "User not logged in"]
            )
        }
        guard let currentName = auth.currentUser?.displayName, !currentName.isEmpty else {
            throw NSError(
                domain: "FirebaseNotificationRepository",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Display name required to send a nudge"]
            )
        }

        var data: [String: Any] = [
            "recipientId": userId,
            "senderId": currentUid,
            "senderName": currentName,
            "type": AppNotification.NotificationType.nudge.rawValue,
            "date": Timestamp(date: Date()),
            "isRead": false
        ]
        if let targetDate {
            data["targetDateString"] = AppNotification.dateString(from: targetDate)
        }

        // Explicit dictionary write — avoids Codable/@DocumentID quirks under security rules.
        _ = try await db.collection("users").document(userId).collection("notifications")
            .addDocument(data: data)
    }

    public func sendNudgeReply(
        to userId: String,
        targetDateString: String?,
        response: AppNotification.NudgeResponse
    ) async throws {
        guard let currentUid = auth.currentUser?.uid,
              let currentName = auth.currentUser?.displayName else { return }

        let note = AppNotification(
            recipientId: userId,
            senderId: currentUid,
            senderName: currentName,
            type: .nudgeReply,
            date: Date(),
            isRead: false,
            targetDateString: targetDateString,
            nudgeResponse: response.rawValue
        )

        _ = try await db.collection("users").document(userId).collection("notifications")
            .addDocument(from: note)
    }

    public func markNudgeResponded(
        _ notification: AppNotification,
        response: AppNotification.NudgeResponse
    ) async throws {
        guard let uid = auth.currentUser?.uid, let noteId = notification.id else { return }

        try await db.collection("users").document(uid).collection("notifications")
            .document(noteId)
            .updateData([
                "isRead": true,
                "nudgeResponse": response.rawValue
            ])
    }
    
    public func updatePushToken(_ token: String) async throws {
        guard let uid = auth.currentUser?.uid else { return }
        
        try await db.collection("users").document(uid).updateData([
            "fcmToken": token,
            "lastTokenUpdate": FieldValue.serverTimestamp()
        ])
    }
}
