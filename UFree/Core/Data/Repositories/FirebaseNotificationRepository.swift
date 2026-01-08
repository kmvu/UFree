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
    
    public func listenToNotifications() -> AsyncStream<[AppNotification]> {
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
                        print("Error listening to notifications: \(error)")
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
    
    public func sendNudge(to userId: String) async throws {
        guard let currentUid = auth.currentUser?.uid,
              let currentName = auth.currentUser?.displayName else { return }
        
        let note = AppNotification(
            recipientId: userId,
            senderId: currentUid,
            senderName: currentName,
            type: .nudge,
            date: Date(),
            isRead: false
        )
        
        // Write to the RECIPIENT'S subcollection
        try db.collection("users").document(userId).collection("notifications")
            .addDocument(from: note)
    }
}
