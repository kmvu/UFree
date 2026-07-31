//
//  MyScheduleViewTests.swift
//  UFreeTests
//

import SwiftUI
import XCTest
@testable import UFree

/// Renders `MyScheduleView` across its major states. Hosting the view is what forces
/// `body` — and every branch reachable from the injected ViewModel state — to execute.
@MainActor
final class MyScheduleViewTests: XCTestCase {

    private var scene: TestScene!

    override func setUp() {
        super.setUp()
        scene = TestScene()
    }

    override func tearDown() async throws {
        scene.tearDown()
        scene = nil
        await drainPendingTasks()
        try await super.tearDown()
    }

    private func makeView() -> some View {
        MyScheduleView(viewModel: scene.scheduleViewModel, rootViewModel: scene.rootViewModel)
            .environment(\.notificationViewModel, scene.notificationViewModel)
    }

    // MARK: - Empty States

    func test_render_withEmptySchedule_showsEmptyState() async {
        scene.scheduleViewModel.weeklySchedule = []

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withScheduleButNoFriends_showsOnboardingCard() async {
        await ViewHost.renderAwaitingUpdates(makeView())

        XCTAssertTrue(scene.friendsScheduleViewModel.friendSchedules.isEmpty)
    }

    // MARK: - Populated States

    func test_render_withFreeFriends_showsDiscoverySection() async {
        scene.addFriendSchedules(count: 3, status: .free)

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withMoreThanFiveFreeFriends_showsOverflowBadge() async {
        scene.addFriendSchedules(count: 8, status: .free)

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withBusyFriends_showsNoneFreeCopy() async {
        scene.addFriendSchedules(count: 3, status: .busy)

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withSingleFreeFriend_usesSingularCopy() async {
        scene.addFriendSchedules(count: 1, status: .free)

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withNoSelectedDate_usesGenericDiscoveryTitle() async {
        scene.addFriendSchedules(count: 2, status: .free)
        scene.friendsScheduleViewModel.selectedDate = nil

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withTomorrowSelected_usesTomorrowTitle() async {
        scene.addFriendSchedules(count: 2, status: .free)
        scene.friendsScheduleViewModel.selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withLaterWeekdaySelected_usesWeekdayTitle() async {
        scene.addFriendSchedules(count: 2, status: .free)
        scene.friendsScheduleViewModel.selectedDate = Calendar.current.date(byAdding: .day, value: 4, to: Date())

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    // MARK: - Per-Day Status Variants

    func test_render_acrossEveryDayStatus() async {
        let statuses: [AvailabilityStatus] = [
            .free, .busy, .morningOnly, .afternoonOnly, .eveningOnly, .unknown
        ]

        for (index, status) in statuses.enumerated() {
            scene.setMyStatus(status, onDayAt: index)
        }

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    // MARK: - Chrome

    func test_render_withoutDisplayName_fallsBackToPlainGreeting() async {
        scene = TestScene(user: User(id: "me", isAnonymous: true, displayName: nil))

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withEmptyDisplayName_fallsBackToPlainGreeting() async {
        scene = TestScene(user: User(id: "me", isAnonymous: true, displayName: ""))

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withUnreadNotifications_showsBellBadge() async {
        // Seeded before the ViewModel is built rather than assigned onto it afterwards.
        // NotificationViewModel starts a listener in `init` and starts another whenever the
        // scene activates — which hosting a view does — so a feed that is only correct after
        // init races with the listener that init already started.
        scene.tearDown()
        scene = TestScene(notifications: [
            TestScene.makeNudge(id: "n1"),
            TestScene.makeNudge(id: "n2")
        ])

        await ViewHost.renderAwaitingUpdates(makeView())

        XCTAssertEqual(scene.notificationViewModel.unreadCount, 2)
    }

    func test_render_withErrorMessage_showsAlert() async {
        scene.scheduleViewModel.errorMessage = "Failed to load schedule"

        await ViewHost.renderAwaitingUpdates(makeView())
    }
}
