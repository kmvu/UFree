//
//  StatusBannerViewModelScheduleTests.swift
//  UFreeTests
//

import XCTest
@testable import UFree

/// Covers the `configure(with:)` / schedule-mapping half of `StatusBannerViewModel`.
/// `StatusBannerViewModelTests` only exercises the standalone banner state.
@MainActor
final class StatusBannerViewModelScheduleTests: XCTestCase {

    private var scheduleViewModel: MyScheduleViewModel!
    private var useCase: RecordingUpdateMyStatusUseCase!
    private var sut: StatusBannerViewModel!

    override func setUp() {
        super.setUp()
        useCase = RecordingUpdateMyStatusUseCase()
        scheduleViewModel = MyScheduleViewModel(
            updateUseCase: useCase,
            repository: EmptyAvailabilityRepository()
        )
        sut = StatusBannerViewModel(scheduler: ImmediateTaskScheduler())
        trackForMemoryLeaks(sut)
    }

    override func tearDown() async throws {
        sut = nil
        scheduleViewModel = nil
        useCase = nil
        await drainPendingTasks()
        verifyNoMemoryLeaks()
        try await super.tearDown()
    }

    // MARK: - Status Mapping

    func test_configure_mapsFreeDayToFreeStatus() async {
        setStatus(.free, onDayAt: 0)

        sut.configure(with: scheduleViewModel)
        sut.setFocusDate(scheduleViewModel.weeklySchedule[0].date)

        XCTAssertEqual(sut.currentStatus, .free)
        XCTAssertNil(sut.customMixedTitle)
    }

    func test_configure_mapsBusyDayToBusyStatus() async {
        setStatus(.busy, onDayAt: 0)

        sut.configure(with: scheduleViewModel)
        sut.setFocusDate(scheduleViewModel.weeklySchedule[0].date)

        XCTAssertEqual(sut.currentStatus, .busy)
        XCTAssertNil(sut.customMixedTitle)
    }

    func test_configure_mapsMorningOnlyAndExposesBlockInfo() async {
        setStatus(.morningOnly, onDayAt: 0)

        sut.configure(with: scheduleViewModel)
        sut.setFocusDate(scheduleViewModel.weeklySchedule[0].date)

        XCTAssertEqual(sut.currentStatus, .morning)
        XCTAssertNotNil(sut.customMixedTitle)
    }

    func test_configure_mapsAfternoonOnly() async {
        setStatus(.afternoonOnly, onDayAt: 0)

        sut.configure(with: scheduleViewModel)
        sut.setFocusDate(scheduleViewModel.weeklySchedule[0].date)

        XCTAssertEqual(sut.currentStatus, .afternoon)
    }

    func test_configure_mapsEveningOnly() async {
        setStatus(.eveningOnly, onDayAt: 0)

        sut.configure(with: scheduleViewModel)
        sut.setFocusDate(scheduleViewModel.weeklySchedule[0].date)

        XCTAssertEqual(sut.currentStatus, .evening)
    }

    func test_configure_mapsUnknownToCheckSchedule() async {
        setStatus(.unknown, onDayAt: 0)

        sut.configure(with: scheduleViewModel)
        sut.setFocusDate(scheduleViewModel.weeklySchedule[0].date)

        XCTAssertEqual(sut.currentStatus, .checkSchedule)
    }

    func test_configure_mapsMixedDayWithBlockInfo() async {
        let calendar = Calendar.current
        let date = scheduleViewModel.weeklySchedule[0].date
        let startOfDay = calendar.startOfDay(for: date)
        // 11:00–13:00 straddles morning and afternoon, which the domain calls "mixed".
        let blocks = [
            TimeBlock(
                startTime: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: startOfDay)!,
                endTime: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: startOfDay)!,
                status: .free
            )
        ]
        scheduleViewModel.weeklySchedule[0] = DayAvailability(date: date, timeBlocks: blocks)

        sut.configure(with: scheduleViewModel)
        sut.setFocusDate(date)

        XCTAssertEqual(sut.currentStatus, .mixed)
        XCTAssertNotNil(sut.customMixedTitle)
    }

    func test_setFocusDate_dateOutsideSchedule_fallsBackToCheckSchedule() async {
        setStatus(.free, onDayAt: 0)
        sut.configure(with: scheduleViewModel)

        let farFuture = Calendar.current.date(byAdding: .day, value: 60, to: Date())!
        sut.setFocusDate(farFuture)

        XCTAssertEqual(sut.currentStatus, .checkSchedule)
        XCTAssertNil(sut.customMixedTitle)
    }

    func test_setFocusDate_updatesSelectedDate() {
        let target = Calendar.current.date(byAdding: .day, value: 3, to: Date())!

        sut.setFocusDate(target)

        XCTAssertEqual(sut.selectedDate, target)
    }

    // MARK: - Writing Back to the Schedule

    func test_setStatus_writesMappedStatusToSchedule() async {
        sut.configure(with: scheduleViewModel)
        let date = scheduleViewModel.weeklySchedule[0].date
        sut.setFocusDate(date)
        sut.toggleExpansion()

        sut.setStatus(.free)
        await waitUntil("use case executed") { self.useCase.executedDays.count == 1 }

        XCTAssertEqual(useCase.executedDays.first?.status, .free)
    }

    func test_setStatus_checkSchedule_persistsAsBusy() async {
        sut.configure(with: scheduleViewModel)
        let date = scheduleViewModel.weeklySchedule[0].date
        sut.setFocusDate(date)
        sut.toggleExpansion()

        sut.setStatus(.checkSchedule)
        await waitUntil("use case executed") { self.useCase.executedDays.count == 1 }

        XCTAssertEqual(useCase.executedDays.first?.status, .busy)
    }

    func test_setStatus_mapsEachUserStatusToAvailability() async {
        sut.configure(with: scheduleViewModel)
        let date = scheduleViewModel.weeklySchedule[0].date
        sut.setFocusDate(date)

        let expected: [(UserStatus, AvailabilityStatus)] = [
            (.morning, .morningOnly),
            (.afternoon, .afternoonOnly),
            (.evening, .eveningOnly),
            (.busy, .busy)
        ]

        for (index, pair) in expected.enumerated() {
            sut.toggleExpansion()
            sut.setStatus(pair.0)
            await waitUntil("use case executed for \(pair.0)") { self.useCase.executedDays.count == index + 1 }
            XCTAssertEqual(useCase.executedDays[index].status, pair.1)
        }
    }

    func test_setStatus_whileCollapsed_isIgnored() {
        sut.configure(with: scheduleViewModel)

        sut.setStatus(.free)

        XCTAssertEqual(sut.currentStatus, .checkSchedule)
        XCTAssertTrue(useCase.executedDays.isEmpty)
    }

    func test_setStatus_withoutScheduleViewModel_stillUpdatesBanner() {
        sut.toggleExpansion()

        sut.setStatus(.free)

        XCTAssertEqual(sut.currentStatus, .free)
        XCTAssertFalse(sut.isExpanded)
    }

    // MARK: - Helpers

    private func setStatus(_ status: AvailabilityStatus, onDayAt index: Int) {
        var day = scheduleViewModel.weeklySchedule[index]
        day.status = status
        scheduleViewModel.weeklySchedule[index] = day
    }
}

// MARK: - Test Doubles

private final class RecordingUpdateMyStatusUseCase: UpdateMyStatusUseCaseProtocol {
    var executedDays: [DayAvailability] = []

    func execute(day: DayAvailability) async throws {
        executedDays.append(day)
    }
}

private final class EmptyAvailabilityRepository: AvailabilityRepository {
    func getSchedules(for userIds: [String]) async throws -> [UserSchedule] { [] }
    func updateMySchedule(for day: DayAvailability) async throws {}
    func getMySchedule() async throws -> UserSchedule {
        UserSchedule(id: "test", name: "Test", weeklyStatus: [])
    }
}
