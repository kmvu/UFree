//
//  StatusBannerViewTests.swift
//  UFreeTests
//

import SwiftUI
import XCTest
@testable import UFree

/// Renders `StatusBannerView` in both its collapsed and expanded forms.
///
/// The banner owns its `StatusBannerViewModel` as a `@StateObject`, so the expanded drawer
/// is normally only reachable by tapping. These tests inject the ViewModel instead and set
/// `isExpanded` directly, which exercises the same `body` branches without simulating input.
@MainActor
final class StatusBannerViewTests: XCTestCase {

    private var scheduleViewModel: MyScheduleViewModel!
    private var bannerViewModel: StatusBannerViewModel!

    override func setUp() {
        super.setUp()
        let repository = MockAvailabilityRepository()
        scheduleViewModel = MyScheduleViewModel(
            updateUseCase: UpdateMyStatusUseCase(repository: repository),
            repository: repository
        )
        bannerViewModel = StatusBannerViewModel(scheduler: ImmediateTaskScheduler())
    }

    override func tearDown() async throws {
        await drainPendingTasks()
        bannerViewModel = nil
        scheduleViewModel = nil
        await drainPendingTasks()
        try await super.tearDown()
    }

    private func makeView() -> some View {
        StatusBannerView(
            scheduleViewModel: self.scheduleViewModel,
            viewModel: self.bannerViewModel
        )
    }

    /// The banner derives its status from the schedule, so days are set rather than the
    /// ViewModel's `currentStatus`, which `configure(with:)` would immediately recompute.
    private func setStatus(_ status: AvailabilityStatus, onDayAt index: Int) {
        var day = scheduleViewModel.weeklySchedule[index]
        day.status = status
        scheduleViewModel.weeklySchedule[index] = day
    }

    // MARK: - Collapsed

    func test_render_collapsed_showsTodaysStatus() async {
        setStatus(.free, onDayAt: 0)

        await ViewHost.renderAwaitingUpdates(makeView(), size: CGSize(width: 402, height: 400))

        XCTAssertFalse(bannerViewModel.isExpanded)
        XCTAssertEqual(bannerViewModel.currentStatus, .free)
    }

    func test_render_collapsed_acrossEveryStatus() async {
        let statuses: [AvailabilityStatus] = [
            .free, .busy, .morningOnly, .afternoonOnly, .eveningOnly, .unknown
        ]

        for status in statuses {
            setStatus(status, onDayAt: 0)
            bannerViewModel = StatusBannerViewModel(scheduler: ImmediateTaskScheduler())

            await ViewHost.renderAwaitingUpdates(makeView(), size: CGSize(width: 402, height: 400))
        }
    }

    func test_render_collapsed_withMixedDay_showsCustomTitle() async {
        let calendar = Calendar.current
        let date = scheduleViewModel.weeklySchedule[0].date
        let startOfDay = calendar.startOfDay(for: date)
        // 11:00–13:00 straddles morning and afternoon, which the domain calls "mixed".
        scheduleViewModel.weeklySchedule[0] = DayAvailability(
            date: date,
            timeBlocks: [
                TimeBlock(
                    startTime: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: startOfDay)!,
                    endTime: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: startOfDay)!,
                    status: .free
                )
            ]
        )

        await ViewHost.renderAwaitingUpdates(makeView(), size: CGSize(width: 402, height: 400))

        XCTAssertEqual(bannerViewModel.currentStatus, .mixed)
        XCTAssertNotNil(bannerViewModel.customMixedTitle)
    }

    func test_render_collapsed_withFutureDaySelected_showsWeekdayName() async {
        setStatus(.free, onDayAt: 2)
        scheduleViewModel.selectedDate = scheduleViewModel.weeklySchedule[2].date

        await ViewHost.renderAwaitingUpdates(makeView(), size: CGSize(width: 402, height: 400))

        XCTAssertFalse(Calendar.current.isDateInToday(bannerViewModel.selectedDate))
    }

    // MARK: - Expanded

    func test_render_expanded_showsEveryStatusOption() async {
        setStatus(.free, onDayAt: 0)
        bannerViewModel.isExpanded = true

        await ViewHost.renderAwaitingUpdates(makeView(), size: CGSize(width: 402, height: 400))

        XCTAssertTrue(bannerViewModel.isExpanded)
    }

    func test_render_expanded_highlightsTheSelectedOptionForEachStatus() async {
        // The option buttons draw a filled circle for the current status and an outlined one
        // for the rest, so every status needs its own render to cover both branches.
        let statuses: [AvailabilityStatus] = [
            .free, .morningOnly, .afternoonOnly, .eveningOnly, .busy
        ]

        for status in statuses {
            setStatus(status, onDayAt: 0)
            bannerViewModel = StatusBannerViewModel(scheduler: ImmediateTaskScheduler())
            bannerViewModel.isExpanded = true

            await ViewHost.renderAwaitingUpdates(makeView(), size: CGSize(width: 402, height: 400))
        }
    }

    func test_render_expanded_withFutureDaySelected_showsWeekdayInHeader() async {
        setStatus(.busy, onDayAt: 3)
        scheduleViewModel.selectedDate = scheduleViewModel.weeklySchedule[3].date
        bannerViewModel.isExpanded = true

        await ViewHost.renderAwaitingUpdates(makeView(), size: CGSize(width: 402, height: 400))

        XCTAssertFalse(Calendar.current.isDateInToday(bannerViewModel.selectedDate))
    }

    func test_render_expanded_thenCollapsed_rendersBothForms() async {
        setStatus(.free, onDayAt: 0)
        bannerViewModel.isExpanded = true
        await ViewHost.renderAwaitingUpdates(makeView(), size: CGSize(width: 402, height: 400))

        bannerViewModel.toggleExpansion()
        await ViewHost.renderAwaitingUpdates(makeView(), size: CGSize(width: 402, height: 400))

        XCTAssertFalse(bannerViewModel.isExpanded)
    }

    // MARK: - Adaptive Layout

    func test_render_expanded_compactLandscape_fitsStatusOptions() async {
        setStatus(.free, onDayAt: 0)
        bannerViewModel.isExpanded = true

        await ViewHost.renderAwaitingUpdates(
            makeView().environment(\.verticalSizeClass, .compact),
            size: ViewHost.compactLandscapeSize
        )

        XCTAssertTrue(bannerViewModel.isExpanded)
    }

    func test_render_collapsed_compactLandscape_usesShorterBanner() async {
        setStatus(.free, onDayAt: 0)

        await ViewHost.renderAwaitingUpdates(
            makeView().environment(\.verticalSizeClass, .compact),
            size: ViewHost.compactLandscapeSize
        )

        XCTAssertFalse(bannerViewModel.isExpanded)
    }
}
