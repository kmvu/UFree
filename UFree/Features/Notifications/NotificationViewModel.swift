//
//  NotificationViewModel.swift
//  UFree
//
//  Created by Khang Vu on 08/01/26.
//

import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public class NotificationViewModel: ObservableObject {
    @Published public var notifications: [AppNotification] = []
    @Published public var highlightedSenderId: String?
    @Published public var isProcessing: Bool = false
    @Published public var errorMessage: String?
    
    // Computed property for the red badge
    public var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }
    
    private let repository: NotificationRepository
    private weak var friendsViewModel: FriendsViewModel?
    private weak var scheduleViewModel: MyScheduleViewModel?
    private weak var rootViewModel: RootViewModel?

    /// `nonisolated(unsafe)` so `deinit` can cancel without hopping to the MainActor.
    /// A non-empty `@MainActor deinit` trips a Swift 6.2 / iOS 26.2 XCTest bug
    /// (`swift_task_deinitOnExecutorImpl` → "pointer being freed was not allocated").
    nonisolated(unsafe) var task: Task<Void, Never>?
    nonisolated(unsafe) private var cancellables = Set<AnyCancellable>()
    
    public init(
        repository: NotificationRepository,
        /// Scene activate/background observers. Off by default under XCTest — view-hosting
        /// tests install a second window on the host scene, and making it key would otherwise
        /// re-fire `didActivateNotification` and restart every live listener mid-teardown.
        observesSceneLifecycle: Bool = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    ) {
        self.repository = repository
        
        // Setup lifecycle observers for Hybrid Listener strategy
        setupLifecycleObservers(observesSceneLifecycle: observesSceneLifecycle)
        
        // Start listening if initialized in foreground
        startListening()
    }

    public func bind(
        friendsViewModel: FriendsViewModel,
        scheduleViewModel: MyScheduleViewModel,
        rootViewModel: RootViewModel
    ) {
        self.friendsViewModel = friendsViewModel
        self.scheduleViewModel = scheduleViewModel
        self.rootViewModel = rootViewModel
    }
    
    /// Empty on purpose — see `task` / `cancellables` notes above. Callers (and tests)
    /// must `stopListening()` before release; `deinit` only cancels as a backstop.
    nonisolated deinit {
        task?.cancel()
        cancellables.removeAll()
    }
    
    private func setupLifecycleObservers(observesSceneLifecycle: Bool) {
        #if canImport(UIKit)
        if observesSceneLifecycle {
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
        }
        #endif
            
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
        
        task = Task { [weak self] in
            guard let repository = self?.repository else { return }
            for await notes in repository.listenToNotifications() {
                guard !Task.isCancelled else { return }
                // Avoid `withAnimation` here: hosting tests tear the `List` down while this
                // yield can still be in flight, and an in-flight animation transaction on a
                // disappearing hierarchy is one of the paths that trips the iOS 26.2
                // XCTest allocator abort.
                self?.notifications = notes
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
        
        Task { [weak self] in
            try? await self?.repository.markAsRead(note)
        }
    }
    
    public func sendNudge(to userId: String, targetDate: Date? = nil) async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            try await repository.sendNudge(to: userId, targetDate: targetDate)
            
            // Contextual Permission Prompt: Request APNs permission after first successful interaction
            requestPermissions()
        } catch {
            print("Error sending nudge: \(error)")
        }
    }

    public func acceptFriendRequest(from note: AppNotification) async {
        guard note.type == .friendRequest, let friendsVM = friendsViewModel else { return }
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        // Keep the live listener warm, but do not require its cache — resolve via
        // relatedRequestId, cache, or one-shot pending fetch.
        friendsVM.listenToRequests()

        guard let request = await friendsVM.resolveIncomingRequest(
            fromSenderId: note.senderId,
            relatedRequestId: note.relatedRequestId,
            senderName: note.senderName,
            recipientId: note.recipientId
        ) else {
            errorMessage = "Couldn't find this friend request. Try Friends tab."
            return
        }

        let accepted = await friendsVM.acceptRequest(request)
        if accepted {
            markRead(note)
            errorMessage = nil
        } else if friendsVM.errorMessage != nil {
            errorMessage = friendsVM.errorMessage
        }
    }

    public func replyToNudge(_ note: AppNotification, response: AppNotification.NudgeResponse) async {
        guard note.type == .nudge, !note.hasResponded else { return }
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await repository.sendNudgeReply(
                to: note.senderId,
                targetDateString: note.targetDateString,
                response: response
            )
            try await repository.markNudgeResponded(note, response: response)

            if let index = notifications.firstIndex(where: { $0.id == note.id }) {
                notifications[index].isRead = true
                notifications[index].nudgeResponse = response.rawValue
            }

            await applyAvailabilitySideEffect(for: note, response: response)

            AnalyticsManager.logNudgeReplySent(response: response.rawValue)
            OnboardingProgressStore.shared.recordWeekendActivity()
            HapticManager.success()
        } catch {
            errorMessage = "Couldn't send reply. Try again."
            HapticManager.warning()
        }
    }

    private func applyAvailabilitySideEffect(
        for note: AppNotification,
        response: AppNotification.NudgeResponse
    ) async {
        guard response == .imIn || response == .busy else { return }
        guard let dateString = note.targetDateString,
              let date = AppNotification.date(from: dateString),
              let scheduleVM = scheduleViewModel else { return }

        var day = scheduleVM.weeklySchedule.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }) ?? DayAvailability(date: date, status: response == .imIn ? .free : .busy)

        day.status = response == .imIn ? .free : .busy
        await scheduleVM.updateStatus(for: day).value
    }
    
    /// Triggers the system notification permission dialog.
    /// This is called contextually after a user sends a nudge or accepts a friend request.
    public func requestPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted.")
                #if canImport(UIKit)
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                #endif
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
}
