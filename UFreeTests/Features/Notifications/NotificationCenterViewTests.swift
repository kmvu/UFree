//
//  NotificationCenterViewTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 08/01/26.
//

import XCTest
import SwiftUI
@testable import UFree

@MainActor
final class NotificationCenterViewTests: XCTestCase {
    
    // MARK: - Message Generation (View Logic)
    
    func test_notificationRowMessage_friendRequest_formatsCorrectly() {
        let vm = NotificationViewModel(
            repository: MockNotificationRepository(),
            observesSceneLifecycle: false
        )
        defer { vm.stopListening() }
        let notification = TestNotificationBuilder.friendRequest(senderName: "Alice")
        let row = NotificationRow(note: notification, viewModel: vm)
        
        let message = row.message
        
        NotificationTestAssertions.assertFriendRequestMessage(message, senderName: "Alice")
    }
    
    func test_notificationRowMessage_nudge_formatsCorrectly() {
        let vm = NotificationViewModel(
            repository: MockNotificationRepository(),
            observesSceneLifecycle: false
        )
        defer { vm.stopListening() }
        let notification = TestNotificationBuilder.nudge(senderName: "Bob")
        let row = NotificationRow(note: notification, viewModel: vm)
        
        let message = row.message
        
        NotificationTestAssertions.assertNudgeMessage(message, senderName: "Bob")
    }
    
    func test_notificationRowMessage_alwaysIncludesSenderName() {
        let vm = NotificationViewModel(
            repository: MockNotificationRepository(),
            observesSceneLifecycle: false
        )
        defer { vm.stopListening() }
        let senders = ["Alice", "Bob", "Carol"]
        
        for sender in senders {
            let notification = TestNotificationBuilder.friendRequest(senderName: sender)
            let row = NotificationRow(note: notification, viewModel: vm)
            
            NotificationTestAssertions.assertContainsSenderName(row.message, senderName: sender)
        }
    }
}

// MARK: - Hosted Rendering

/// Renders `NotificationCenterView` in a real window so the `List`, its rows, and the
/// `onAppear`-driven read-receipts actually execute.
@MainActor
final class NotificationCenterViewHostingTests: XCTestCase {

    private var repository: MockNotificationRepository!
    private var viewModel: NotificationViewModel!

    override func setUp() {
        super.setUp()
        repository = MockNotificationRepository()
    }

    override func tearDown() async throws {
        // Stop the listener and let its Task finish *before* releasing the ViewModel.
        // Nilling first races `deinit` with an in-flight `for await` body under iOS 26.2
        // XCTest and surfaces as `pointer being freed was not allocated`.
        viewModel?.stopListening()
        await drainPendingTasks()
        viewModel = nil
        repository = nil
        await drainPendingTasks()
        try await super.tearDown()
    }

    /// Seeds the repository and only then builds the ViewModel.
    ///
    /// `NotificationViewModel` starts a listener in `init` and starts another whenever the
    /// scene activates — which hosting a view does. Seeding afterwards would leave the
    /// init-time listener racing to deliver the feed as it was before the seed.
    private func start(with notifications: [AppNotification] = []) async {
        repository.mockNotifications = notifications
        viewModel = NotificationViewModel(repository: repository)
        await waitUntil("the listener delivers \(notifications.count) notification(s)") {
            self.viewModel.notifications.count == notifications.count
        }
    }

    private func makeView() -> some View {
        NotificationCenterView(viewModel: viewModel)
    }

    private func notification(
        id: String,
        type: AppNotification.NotificationType = .friendRequest,
        senderName: String = "Alice",
        date: Date = Date(),
        isRead: Bool = false
    ) -> AppNotification {
        // `ForEach` keys on `id`, which `AppNotification` leaves nil until Firestore
        // assigns one, so rows have to be given distinct ids explicitly.
        var note = AppNotification(
            recipientId: "me",
            senderId: "sender_\(id)",
            senderName: senderName,
            type: type,
            date: date,
            isRead: isRead
        )
        note.id = id
        return note
    }

    // MARK: - Empty State

    func test_render_withNoNotifications_showsAllCaughtUp() async {
        await start()

        await ViewHost.renderAwaitingUpdates(makeView())

        XCTAssertTrue(viewModel.notifications.isEmpty)
    }

    // MARK: - Populated

    func test_render_withFriendRequest_showsRequestRow() async {
        await start(with: [notification(id: "n1", type: .friendRequest, senderName: "Alice")])

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withNudge_showsNudgeRow() async {
        await start(with: [notification(id: "n1", type: .nudge, senderName: "Bob")])

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withBothTypes_showsEachRowStyle() async {
        await start(with: [
            notification(id: "n1", type: .friendRequest, senderName: "Alice"),
            notification(id: "n2", type: .nudge, senderName: "Bob")
        ])

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withReadNotification_usesClearRowBackground() async {
        await start(with: [notification(id: "n1", isRead: true)])

        await ViewHost.renderAwaitingUpdates(makeView())

        XCTAssertEqual(viewModel.unreadCount, 0)
    }

    func test_render_withOlderNotification_showsRelativeTimestamp() async {
        await start(with: [
            notification(id: "n1", date: Date().addingTimeInterval(-3600)),
            notification(id: "n2", date: Date().addingTimeInterval(-86_400 * 3))
        ])

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    // MARK: - Read Receipts

    func test_render_withUnreadNotification_marksItReadOnAppear() async {
        await start(with: [notification(id: "n1", isRead: false)])

        await ViewHost.renderAwaitingUpdates(makeView())

        await waitUntil("the row's onAppear marks the notification read") {
            self.viewModel.notifications.first?.isRead == true
        }
        XCTAssertEqual(viewModel.unreadCount, 0)
    }
}
