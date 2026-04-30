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
    private var cancellables = Set<AnyCancellable>()
    
    public init(repository: NotificationRepository) {
        self.repository = repository
        
        // Setup lifecycle observers for Hybrid Listener strategy
        setupLifecycleObservers()
        
        // Start listening if initialized in foreground
        startListening()
    }
    
    deinit {
        task?.cancel()
    }
    
    private func setupLifecycleObservers() {
        // Detach listener when backgrounding to save database reads
        NotificationCenter.default.publisher(for: UIScene.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.stopListening()
            }
            .store(in: &cancellables)
            
        // Re-attach when returning to active
        NotificationCenter.default.publisher(for: UIScene.didActivateNotification)
            .sink { [weak self] _ in
                self?.startListening()
            }
            .store(in: &cancellables)
            
        // Listen for FCM token updates
        NotificationCenter.default.publisher(for: .didReceiveFCMToken)
            .sink { [weak self] notification in
                if let token = notification.userInfo?["token"] as? String {
                    Task { [weak self] in
                        try? await self?.repository.updatePushToken(token)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    public func startListening() {
        // Ensure we don't start multiple listeners
        stopListening()
        
        task = Task {
            for await notes in repository.listenToNotifications() {
                withAnimation {
                    self.notifications = notes
                }
            }
        }
    }
    
    public func stopListening() {
        task?.cancel()
        task = nil
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
            
            // Contextual Permission Prompt: Request APNs permission after first successful interaction
            requestPermissions()
        } catch {
            print("Error sending nudge: \(error)")
        }
    }
    
    /// Triggers the system notification permission dialog.
    /// This is called contextually after a user sends a nudge or accepts a friend request.
    public func requestPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted.")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
}
