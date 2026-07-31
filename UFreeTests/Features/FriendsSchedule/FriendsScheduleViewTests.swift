//
//  FriendsScheduleViewTests.swift
//  UFreeTests
//

import SwiftUI
import XCTest
@testable import UFree

@MainActor
final class FriendsScheduleViewTests: XCTestCase {

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
        NavigationStack {
            FriendsScheduleView(
                viewModel: scene.friendsScheduleViewModel,
                rootViewModel: scene.rootViewModel
            )
        }
    }

    // MARK: - Empty and Loading

    func test_render_withNoFriends_showsOnboardingCard() async {
        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_whileLoadingFirstTime_showsSpinner() async {
        scene.friendsScheduleViewModel.isLoading = true

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_whileRefreshingWithExistingData_keepsListVisible() async {
        scene.addFriendSchedules(count: 2, status: .free)
        scene.friendsScheduleViewModel.isLoading = true

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    // MARK: - Populated

    func test_render_withFreeFriends_showsHeatmapAndNudgeAll() async {
        scene.addFriendSchedules(count: 3, status: .free)

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withSingleFreeFriend_showsSingularNudgeCopy() async {
        scene.addFriendSchedules(count: 1, status: .free)

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withBusyFriends_hidesNudgeAllButton() async {
        scene.addFriendSchedules(count: 2, status: .busy)

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withNoDaySelected_hidesNudgeAllButton() async {
        scene.addFriendSchedules(count: 2, status: .free)
        scene.friendsScheduleViewModel.selectedDate = nil

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_whileNudging_disablesActions() async {
        scene.addFriendSchedules(count: 2, status: .free)
        scene.friendsScheduleViewModel.isNudging = true

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    // MARK: - Status Pills

    func test_render_acrossEveryFriendStatus() async {
        let statuses: [AvailabilityStatus] = [
            .free, .busy, .morningOnly, .afternoonOnly, .eveningOnly, .mixed, .unknown
        ]

        scene.friendsScheduleViewModel.friendSchedules = statuses.enumerated().map { index, status in
            FriendsScheduleViewModel.FriendScheduleDisplay(
                id: "friend_\(index)",
                displayName: "Friend \(index)",
                userSchedule: UserSchedule(
                    id: "friend_\(index)",
                    name: "Friend \(index)",
                    weeklyStatus: scene.week.map { DayAvailability(date: $0, status: status) }
                )
            )
        }

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withFriendMissingScheduleForDay_showsUnknownPill() async {
        scene.friendsScheduleViewModel.friendSchedules = [
            FriendsScheduleViewModel.FriendScheduleDisplay(
                id: "friend_0",
                displayName: "Friend 0",
                userSchedule: UserSchedule(id: "friend_0", name: "Friend 0", weeklyStatus: [])
            )
        ]

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    // MARK: - Alerts

    func test_render_withErrorMessage_showsErrorAlert() async {
        scene.friendsScheduleViewModel.errorMessage = "Failed to load"

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withSuccessMessage_showsSuccessAlert() async {
        scene.addFriendSchedules(count: 2, status: .free)
        scene.friendsScheduleViewModel.successMessage = "All 2 friends nudged! 👋"

        await ViewHost.renderAwaitingUpdates(makeView())
    }
}
