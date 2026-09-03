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
    @Published public var notifications: [AppNotification] = [] {
        didSet { syncUnreadCount() }
    }
    @Published public var highlightedSenderId: String?
    @Published public var isProcessing: Bool = false
    /// Which inbox row is running Accept / nudge reply; avoids spinning every action button at once.
    @Published public private(set) var processingNotificationKey: String?
    @Published public var errorMessage: String?
    @Published public var showNotificationCenter = false
    @Published public var incomingBanner: AppNotification?
    @Published public private(set) var unreadCount = 0

    /// Seconds before an auto-presented foreground banner dismisses itself.
    var bannerAutoDismissSeconds: TimeInterval = 4.5
    /// Delay before auto-dismissing the inbox after a successful friend accept.
    var notificationCenterDismissDelayNanoseconds: UInt64 = 900_000_000
    
    private let repository: NotificationRepository
    private weak var friendsViewModel: FriendsViewModel?
    private weak var scheduleViewModel: MyScheduleViewModel?
    private weak var rootViewModel: RootViewModel?

    /// `nonisolated(unsafe)` so `deinit` can cancel without hopping to the MainActor.
    /// A non-empty `@MainActor deinit` trips a Swift 6.2 / iOS 26.2 XCTest bug
    /// (`swift_task_deinitOnExecutorImpl` → "pointer being freed was not allocated").
    nonisolated(unsafe) var task: Task<Void, Never>?
    nonisolated(unsafe) private var cancellables = Set<AnyCancellable>()
    private var knownNotificationKeys = Set<String>()
    private var handledFriendRequestKeys = Set<String>()
    private var deletedNotificationKeys = Set<String>()
    private var hasCompletedInitialNotificationSnapshot = false
    nonisolated(unsafe) private var bannerDismissTask: Task<Void, Never>?
    
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
        bannerDismissTask?.cancel()
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
                self?.applyNotificationsUpdate(notes)
            }
        }
    }

    func applyNotificationsUpdate(_ notes: [AppNotification]) {
        let remoteKeys = Set(notes.map(notificationKey))
        deletedNotificationKeys = deletedNotificationKeys.intersection(remoteKeys)

        let visible = notes.filter { !deletedNotificationKeys.contains(notificationKey($0)) }
        let merged = mergeHandledFriendRequests(into: visible)
        let currentKeys = Set(merged.map(notificationKey))

        if !hasCompletedInitialNotificationSnapshot {
            knownNotificationKeys = currentKeys
            hasCompletedInitialNotificationSnapshot = true
            notifications = merged
            syncUnreadCount()
            return
        }

        let newlyArrivedUnread = merged.filter { note in
            !note.isRead && !knownNotificationKeys.contains(notificationKey(note))
        }

        knownNotificationKeys = currentKeys
        notifications = merged
        syncUnreadCount()

        let newNudgeReplies = newlyArrivedUnread.filter { $0.type == .nudgeReply }
        for reply in newNudgeReplies {
            handleIncomingNudgeReply(reply)
        }

        guard let newest = newlyArrivedUnread.max(by: { $0.date < $1.date }) else { return }
        presentIncomingBanner(for: newest)
    }

    /// Surfaces a friend's nudge reply on Who's Free (focus day + In/Maybe/Busy).
    func handleIncomingNudgeReply(_ note: AppNotification) {
        guard note.type == .nudgeReply,
              let scheduleVM = rootViewModel?.friendsScheduleViewModel else { return }
        scheduleVM.applyNudgeReply(from: note)
        rootViewModel?.activeTab = .feed
        Task { [weak scheduleVM] in
            await scheduleVM?.loadFriendsSchedules()
        }
    }

    /// Banner tap: nudge replies jump to Who's Free; everything else opens the inbox.
    func handleIncomingBannerTap() {
        guard let banner = incomingBanner else {
            openNotificationCenter()
            return
        }
        if banner.type == .nudgeReply {
            dismissIncomingBanner()
            handleIncomingNudgeReply(banner)
        } else {
            openNotificationCenter()
        }
    }

    func isFriendRequestActionable(_ note: AppNotification) -> Bool {
        note.type == .friendRequest && !handledFriendRequestKeys.contains(notificationKey(note))
    }

    func isProcessingNotification(_ note: AppNotification) -> Bool {
        processingNotificationKey == notificationKey(note)
    }

    var hasActiveNotificationAction: Bool {
        processingNotificationKey != nil
    }

    private func mergeHandledFriendRequests(into notes: [AppNotification]) -> [AppNotification] {
        notes.map { note in
            guard note.type == .friendRequest,
                  handledFriendRequestKeys.contains(notificationKey(note)) else {
                return note
            }
            return acceptedCopy(from: note)
        }
    }

    private func acceptedCopy(from note: AppNotification) -> AppNotification {
        var accepted = AppNotification(
            recipientId: note.recipientId,
            senderId: note.senderId,
            senderName: note.senderName,
            type: .friendAccepted,
            date: note.date,
            isRead: true,
            relatedRequestId: note.relatedRequestId
        )
        accepted.id = note.id
        return accepted
    }

    private func syncUnreadCount() {
        unreadCount = notifications.filter { !$0.isRead }.count
    }

    func openNotificationCenter() {
        dismissIncomingBanner()
        showNotificationCenter = true
    }

    func dismissIncomingBanner() {
        bannerDismissTask?.cancel()
        bannerDismissTask = nil
        incomingBanner = nil
    }

    private func presentIncomingBanner(for note: AppNotification) {
        incomingBanner = note
        bannerDismissTask?.cancel()
        HapticManager.light()

        let dismissAfter = bannerAutoDismissSeconds
        bannerDismissTask = Task { [weak self] in
            let nanoseconds = UInt64(max(dismissAfter, 0) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                if self.notificationKey(note) == self.incomingBanner.map(self.notificationKey) {
                    self.incomingBanner = nil
                }
            }
        }
    }

    private func notificationKey(_ note: AppNotification) -> String {
        if let id = note.id, !id.isEmpty {
            return id
        }
        return "\(note.senderId)-\(note.type.rawValue)-\(Int(note.date.timeIntervalSince1970))"
    }
    
    public func stopListening() {
        task?.cancel()
        task = nil
    }
    
    public func markRead(_ note: AppNotification) {
        guard !note.isRead else { return }
        
        if let index = notifications.firstIndex(where: { notificationKey($0) == notificationKey(note) }) {
            notifications[index].isRead = true
            syncUnreadCount()
        }
        
        Task { [weak self] in
            try? await self?.repository.markAsRead(note)
        }
    }

    public func markUnread(_ note: AppNotification) {
        guard note.isRead else { return }

        if let index = notifications.firstIndex(where: { notificationKey($0) == notificationKey(note) }) {
            notifications[index].isRead = false
            syncUnreadCount()
        }

        Task { [weak self] in
            try? await self?.repository.markAsUnread(note)
        }
    }

    public func markAllRead() {
        let unread = notifications.filter { !$0.isRead }
        guard !unread.isEmpty else { return }

        for index in notifications.indices where !notifications[index].isRead {
            notifications[index].isRead = true
        }
        syncUnreadCount()
        dismissIncomingBanner()

        Task { [weak self] in
            for note in unread {
                try? await self?.repository.markAsRead(note)
            }
        }
    }

    public func clearNotification(_ note: AppNotification) {
        let key = notificationKey(note)
        deletedNotificationKeys.insert(key)
        knownNotificationKeys.remove(key)
        notifications.removeAll { notificationKey($0) == key }

        if incomingBanner.map(notificationKey) == key {
            dismissIncomingBanner()
        }

        Task { [weak self] in
            try? await self?.repository.deleteNotification(note)
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
            #if DEBUG
            print("Error sending nudge: \(error)")
            #endif
        }
    }

    public func acceptFriendRequest(from note: AppNotification) async {
        guard note.type == .friendRequest, let friendsVM = friendsViewModel else { return }
        guard processingNotificationKey == nil else { return }
        guard isFriendRequestActionable(note) else { return }
        let key = notificationKey(note)
        processingNotificationKey = key
        defer { processingNotificationKey = nil }

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
            markFriendRequestHandled(note)
            errorMessage = nil
            await handlePostFriendRequestAccept()
        } else if friendsVM.errorMessage != nil {
            errorMessage = friendsVM.errorMessage
        }
    }

    private func markFriendRequestHandled(_ note: AppNotification) {
        let key = notificationKey(note)
        handledFriendRequestKeys.insert(key)

        if let index = notifications.firstIndex(where: { notificationKey($0) == key }) {
            notifications[index] = acceptedCopy(from: note)
        }

        if incomingBanner.map(notificationKey) == key {
            dismissIncomingBanner()
        }

        markRead(note)
    }

    private func handlePostFriendRequestAccept() async {
        if let scheduleVM = scheduleViewModel {
            await scheduleVM.loadSchedule()
        }
        await rootViewModel?.friendsScheduleViewModel?.loadFriendsSchedules()

        // Tab / toast / mission quest come from `FriendsViewModel.onAcceptCompleted`
        // (wired in MainAppView). Inbox only refreshes schedules and dismisses.
        scheduleNotificationCenterDismiss()
    }

    private func scheduleNotificationCenterDismiss() {
        Task { [weak self] in
            let delay = self?.notificationCenterDismissDelayNanoseconds ?? 900_000_000
            try? await Task.sleep(nanoseconds: delay)
            await MainActor.run {
                self?.showNotificationCenter = false
            }
        }
    }

    public func replyToNudge(_ note: AppNotification, response: AppNotification.NudgeResponse) async {
        guard note.type == .nudge, !note.hasResponded else { return }
        guard processingNotificationKey == nil else { return }
        let key = notificationKey(note)
        processingNotificationKey = key
        defer { processingNotificationKey = nil }

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
            syncUnreadCount()

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
                #if DEBUG
                print("Notification permission granted.")
                #endif
                #if canImport(UIKit)
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                #endif
            } else if let error = error {
                #if DEBUG
                print("Notification permission error: \(error)")
                #endif
            }
        }
    }
}
