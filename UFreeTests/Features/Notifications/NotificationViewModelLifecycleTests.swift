//
//  NotificationViewModelLifecycleTests.swift
//  UFreeTests
//

import UIKit
import XCTest
@testable import UFree

/// Covers the parts of `NotificationViewModel` that `NotificationViewModelTests` leaves out:
/// the hybrid listener's scene-lifecycle observers, and the nudge and read-receipt write paths.
@MainActor
final class NotificationViewModelLifecycleTests: XCTestCase {

    private var repository: MockNotificationRepository!
    private var sut: NotificationViewModel!

    override func setUp() {
        super.setUp()
        repository = MockNotificationRepository()
    }

    override func tearDown() async throws {
        sut?.stopListening()
        await drainPendingTasks()
        sut = nil
        repository = nil
        await drainPendingTasks()
        try await super.tearDown()
    }

    /// Seeds the repository and only then builds the subject.
    ///
    /// The listener started in `init` captures the feed as it stands at that moment, so
    /// seeding afterwards leaves it racing the listener started by whatever the test does
    /// next, and either one can win.
    private func start(with notifications: [AppNotification] = []) async {
        repository.mockNotifications = notifications
        // Opt into scene observers — production default, but off under XCTest so view-hosting
        // suites don't restart listeners when ViewHost touches the host scene.
        sut = NotificationViewModel(repository: repository, observesSceneLifecycle: true)
        await waitUntil("the initial listener delivers \(notifications.count) notification(s)") {
            self.sut.notifications.count == notifications.count
        }
    }

    // MARK: - Scene Lifecycle

    func test_enteringBackground_detachesTheListener() async {
        await start()
        sut.startListening()
        XCTAssertNotNil(sut.task)

        NotificationCenter.default.post(name: UIScene.didEnterBackgroundNotification, object: nil)

        await waitUntil("the background observer stops the listener") { self.sut.task == nil }
    }

    func test_returningToForeground_reattachesTheListener() async {
        await start()
        NotificationCenter.default.post(name: UIScene.didEnterBackgroundNotification, object: nil)
        await waitUntil("the listener is detached first") { self.sut.task == nil }

        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: nil)

        await waitUntil("the activation observer restarts the listener") { self.sut.task != nil }
    }

    func test_returningToForeground_deliversTheCurrentFeed() async {
        await start(with: [TestNotificationBuilder.nudge(senderName: "Bob")])
        sut.notifications = []

        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: nil)

        await waitUntil("the restarted listener delivers the feed again") {
            self.sut.notifications.count == 1
        }
    }

    // MARK: - Read Receipts

    func test_markRead_persistsThroughTheRepository() async {
        var note = TestNotificationBuilder.friendRequest(isRead: false)
        note.id = "n1"
        await start(with: [note])

        sut.markRead(note)

        await waitUntil("the repository records the read receipt") {
            self.repository.mockNotifications.first?.isRead == true
        }
    }

    func test_markRead_forUnknownNotification_stillWritesThrough() async {
        var note = TestNotificationBuilder.nudge(isRead: false)
        note.id = "missing"
        await start()

        sut.markRead(note)

        await drainPendingTasks()
        XCTAssertTrue(sut.notifications.isEmpty)
    }

    // MARK: - Nudges

    func test_sendNudge_appendsToTheRepositoryFeed() async {
        await start()

        await sut.sendNudge(to: "friend_1")

        XCTAssertEqual(repository.mockNotifications.count, 1)
        XCTAssertEqual(repository.mockNotifications.first?.recipientId, "friend_1")
        XCTAssertFalse(sut.isProcessing)
    }

    func test_sendNudge_clearsIsProcessingAfterwards() async {
        await start()

        await sut.sendNudge(to: "friend_1")

        XCTAssertFalse(sut.isProcessing)
    }

    func test_sendNudge_whenRateLimited_leavesTheFeedUntouched() async {
        await start()
        repository.shouldThrowRateLimit = true

        await sut.sendNudge(to: "friend_1")

        XCTAssertTrue(repository.mockNotifications.isEmpty)
        XCTAssertFalse(sut.isProcessing)
    }

    func test_sendNudge_whenTheRecipientFails_leavesTheFeedUntouched() async {
        await start()
        repository.userIdsToFailFor = ["friend_1"]

        await sut.sendNudge(to: "friend_1")

        XCTAssertTrue(repository.mockNotifications.isEmpty)
        XCTAssertFalse(sut.isProcessing)
    }
}
