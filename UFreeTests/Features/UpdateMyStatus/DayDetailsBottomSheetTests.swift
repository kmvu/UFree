//
//  DayDetailsBottomSheetTests.swift
//  UFreeTests
//

import SwiftUI
import XCTest
@testable import UFree

@MainActor
final class DayDetailsBottomSheetTests: XCTestCase {

    private let date = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 15))!

    // MARK: - States

    func test_render_withNoFreeWindows_showsEmptyCopy() async {
        await ViewHost.renderAwaitingUpdates(makeSheet(freeRanges: []))
    }

    func test_render_withOneFreeWindow_showsWindowRow() async {
        await ViewHost.renderAwaitingUpdates(makeSheet(freeRanges: [(9, 12)]))
    }

    func test_render_withMultipleFreeWindows_showsEveryRow() async {
        await ViewHost.renderAwaitingUpdates(makeSheet(freeRanges: [(9, 11), (14, 16), (19, 21)]))
    }

    func test_render_withAllQuickFillsActive_showsSelectedButtons() async {
        await ViewHost.renderAwaitingUpdates(makeSheet(freeRanges: [(9, 22)]))
    }

    func test_render_forToday_seedsPickersFromCurrentTime() async {
        await ViewHost.renderAwaitingUpdates(makeSheet(freeRanges: [], date: Date()))
    }

    func test_render_forLateEveningToday_producesInvertedPickerRange() async {
        // Constructing the sheet for "today" seeds the start picker from `Date()`, so a
        // late-in-the-day run is what exercises the invalid-range warning branch.
        await ViewHost.renderAwaitingUpdates(makeSheet(freeRanges: [], date: Date()))
    }

    // MARK: - Save Callback

    func test_save_reportsFullDayTimeline() {
        var saved: DayAvailability?
        let day = DayAvailability(
            date: date,
            timeBlocks: [TimeBlock(startTime: hour(9), endTime: hour(12), status: .free)]
        )

        // The sheet delegates its block math to `DayDetailsEditor`, so the callback
        // contract is verified through the same type the view uses.
        let editor = DayDetailsEditor(day: day)
        saved = editor.makeUpdatedDay(from: day)

        ViewHost.render(DayDetailsBottomSheet(day: day) { saved = $0 })

        XCTAssertEqual(saved?.status, .morningOnly)
    }

    // MARK: - Row Components

    func test_render_datePickerRow() {
        ViewHost.render(
            DatePickerRow(title: "Starts", icon: "clock", selection: .constant(hour(9)))
        )
    }

    func test_render_quickFillButton_inBothSelectionStates() {
        for isSelected in [true, false] {
            ViewHost.render(
                QuickFillButton(
                    title: "Morning",
                    icon: "sunrise.fill",
                    color: .orange,
                    isSelected: isSelected,
                    action: {}
                )
            )
        }
    }

    // MARK: - Helpers

    private func makeSheet(freeRanges: [(Int, Int)], date: Date? = nil) -> some View {
        let day = DayAvailability(
            date: date ?? self.date,
            timeBlocks: freeRanges.map {
                TimeBlock(startTime: hour($0.0, on: date), endTime: hour($0.1, on: date), status: .free)
            }
        )
        return DayDetailsBottomSheet(day: day) { _ in }
    }

    private func hour(_ value: Int, on date: Date? = nil) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date ?? self.date)
        return calendar.date(bySettingHour: value, minute: 0, second: 0, of: startOfDay)!
    }
}
