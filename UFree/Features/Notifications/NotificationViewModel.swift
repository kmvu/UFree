//
//  NotificationViewModel.swift
//  UFree
//
//  Created by Khang Vu on 08/01/26.
//

import SwiftUI
import Combine

@MainActor
public class NotificationViewModel: ObservableObject {
    @Published public var notifications: [AppNotification] = []
    @Published public var highlightedSenderId: String?
    @Published public var isProcessing: Bool = false
    
    // Computed property for the red badge
    public var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }
    
    private let repository: NotificationRepository
    private var task: Task<Void, Never>?
    
    public init(repository: NotificationRepository) {
        self.repository = repository
        
        // Start listening immediately upon init (or call this from onAppear)
        startListening()
    }
    
    deinit {
        task?.cancel()
    }
    
    public func startListening() {
        task = Task {
            for await notes in repository.listenToNotifications() {
                withAnimation {
                    self.notifications = notes
                }
            }
        }
    }
    
    public func markRead(_ note: AppNotification) {
        guard !note.isRead else { return }
        
        // Optimistic UI update
        if let index = notifications.firstIndex(where: { $0.id == note.id }) {
            notifications[index].isRead = true
        }
        
        Task {
            try? await repository.markAsRead(note)
        }
    }
    
    public func sendNudge(to userId: String) async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            try await repository.sendNudge(to: userId)
        } catch {
            print("Error sending nudge: \(error)")
        }
    }
}
