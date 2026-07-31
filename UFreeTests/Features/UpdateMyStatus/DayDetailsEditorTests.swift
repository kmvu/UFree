//
//  DayDetailsEditorTests.swift
//  UFreeTests
//

import XCTest
@testable import UFree

@MainActor
final class DayDetailsEditorTests: XCTestCase {

    /// A fixed, non-today date so `defaultStartTime` is deterministic.
    private let date = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 15))!

    // MARK: - Initial State

    func test_init_carriesOverExistingBlocks() {
        let editor = makeEditor(freeRanges: [(9, 12)])

        XCTAssertEqual(editor.freeBlocks.count, 1)
        XCTAssertEqual(editor.freeBlocks.first?.startTime, hour(9))
        XCTAssertEqual(editor.freeBlocks.first?.endTime, hour(12))
    }

    func test_freeBlocks_excludeBusyBlocksAndSortChronologically() {
        let seeded = DayAvailability(date: date, timeBlocks: [
            TimeBlock(startTime: hour(17), endTime: hour(22), status: .free),
            TimeBlock(startTime: hour(12), endTime: hour(17), status: .busy)
        ])
        var editor = DayDetailsEditor(day: seeded)

        editor.addFreeWindow(from: hour(9), to: hour(12))

        XCTAssertEqual(editor.freeBlocks.map(\.startTime), [hour(9), hour(17)])
        XCTAssertTrue(editor.blocks.contains { $0.status == .busy })
    }

    // MARK: - Default Picker Values

    func test_defaultStartTime_forAnotherDay_isNineAM() {
        let editor = makeEditor(freeRanges: [])

        XCTAssertEqual(editor.defaultStartTime(now: date.addingTimeInterval(-86_400 * 5)), hour(9))
    }

    func test_defaultStartTime_forToday_isNow() {
        let now = hour(14).addingTimeInterval(37 * 60)
        let editor = makeEditor(freeRanges: [])

        XCTAssertEqual(editor.defaultStartTime(now: now), now)
    }

    func test_defaultEndTime_isOneHourAfterStart() {
        let editor = makeEditor(freeRanges: [])
        let now = date.addingTimeInterval(-86_400 * 5)

        XCTAssertEqual(
            editor.defaultEndTime(now: now).timeIntervalSince(editor.defaultStartTime(now: now)),
            3600
        )
    }

    // MARK: - Adding Custom Windows

    func test_addFreeWindow_appendsNewWindow() {
        var editor = makeEditor(freeRanges: [])

        editor.addFreeWindow(from: hour(9), to: hour(11))

        XCTAssertEqual(editor.freeBlocks.count, 1)
        XCTAssertEqual(editor.freeBlocks.first?.endTime, hour(11))
    }

    func test_addFreeWindow_normalizesPickerDatesOntoTheEditedDay() {
        var editor = makeEditor(freeRanges: [])
        // Picker values often carry today's date, not the day being edited.
        let unrelatedDay = Calendar.current.date(from: DateComponents(year: 2020, month: 1, day: 1))!
        let start = Calendar.current.date(bySettingHour: 14, minute: 30, second: 0, of: unrelatedDay)!
        let end = Calendar.current.date(bySettingHour: 16, minute: 0, second: 0, of: unrelatedDay)!

        editor.addFreeWindow(from: start, to: end)

        XCTAssertEqual(editor.freeBlocks.first?.startTime, time(hour: 14, minute: 30))
        XCTAssertEqual(editor.freeBlocks.first?.endTime, hour(16))
    }

    func test_addFreeWindow_rejectsInvertedRange() {
        var editor = makeEditor(freeRanges: [])

        editor.addFreeWindow(from: hour(15), to: hour(10))

        XCTAssertTrue(editor.freeBlocks.isEmpty)
    }

    func test_addFreeWindow_rejectsZeroLengthRange() {
        var editor = makeEditor(freeRanges: [])

        editor.addFreeWindow(from: hour(10), to: hour(10))

        XCTAssertTrue(editor.freeBlocks.isEmpty)
    }

    // MARK: - Merging

    func test_addFreeWindow_mergesOverlappingWindows() {
        var editor = makeEditor(freeRanges: [(9, 12)])

        editor.addFreeWindow(from: hour(11), to: hour(14))

        XCTAssertEqual(editor.freeBlocks.count, 1)
        XCTAssertEqual(editor.freeBlocks.first?.startTime, hour(9))
        XCTAssertEqual(editor.freeBlocks.first?.endTime, hour(14))
    }

    func test_addFreeWindow_mergesAdjacentWindows() {
        var editor = makeEditor(freeRanges: [(9, 12)])

        editor.addFreeWindow(from: hour(12), to: hour(15))

        XCTAssertEqual(editor.freeBlocks.count, 1)
        XCTAssertEqual(editor.freeBlocks.first?.endTime, hour(15))
    }

    func test_addFreeWindow_keepsDisjointWindowsSeparate() {
        var editor = makeEditor(freeRanges: [(9, 11)])

        editor.addFreeWindow(from: hour(14), to: hour(16))

        XCTAssertEqual(editor.freeBlocks.count, 2)
    }

    func test_addFreeWindow_absorbsFullyContainedWindow() {
        var editor = makeEditor(freeRanges: [(9, 18)])

        editor.addFreeWindow(from: hour(12), to: hour(13))

        XCTAssertEqual(editor.freeBlocks.count, 1)
        XCTAssertEqual(editor.freeBlocks.first?.startTime, hour(9))
        XCTAssertEqual(editor.freeBlocks.first?.endTime, hour(18))
    }

    func test_addFreeWindow_bridgesTwoWindowsIntoOne() {
        var editor = makeEditor(freeRanges: [(9, 11), (14, 16)])

        editor.addFreeWindow(from: hour(11), to: hour(14))

        XCTAssertEqual(editor.freeBlocks.count, 1)
        XCTAssertEqual(editor.freeBlocks.first?.startTime, hour(9))
        XCTAssertEqual(editor.freeBlocks.first?.endTime, hour(16))
    }

    // MARK: - Quick Fills

    func test_quickFillHours_matchTheProductWindows() {
        XCTAssertEqual(DayDetailsEditor.QuickFill.morning.startHour, 9)
        XCTAssertEqual(DayDetailsEditor.QuickFill.morning.endHour, 12)
        XCTAssertEqual(DayDetailsEditor.QuickFill.afternoon.startHour, 12)
        XCTAssertEqual(DayDetailsEditor.QuickFill.afternoon.endHour, 17)
        XCTAssertEqual(DayDetailsEditor.QuickFill.evening.startHour, 17)
        XCTAssertEqual(DayDetailsEditor.QuickFill.evening.endHour, 22)
        XCTAssertEqual(DayDetailsEditor.QuickFill.allCases.count, 3)
    }

    func test_isQuickFillActive_falseWhenNoFreeTime() {
        let editor = makeEditor(freeRanges: [])

        for quickFill in DayDetailsEditor.QuickFill.allCases {
            XCTAssertFalse(editor.isQuickFillActive(quickFill))
        }
    }

    func test_isQuickFillActive_trueWhenWindowFullyCovered() {
        let editor = makeEditor(freeRanges: [(8, 13)])

        XCTAssertTrue(editor.isQuickFillActive(.morning))
        XCTAssertFalse(editor.isQuickFillActive(.afternoon))
    }

    func test_isQuickFillActive_falseWhenOnlyPartiallyCovered() {
        let editor = makeEditor(freeRanges: [(9, 11)])

        XCTAssertFalse(editor.isQuickFillActive(.morning))
    }

    func test_toggleQuickFill_addsWindowWhenInactive() {
        var editor = makeEditor(freeRanges: [])

        let didAdd = editor.toggleQuickFill(.afternoon)

        XCTAssertTrue(didAdd)
        XCTAssertTrue(editor.isQuickFillActive(.afternoon))
        XCTAssertEqual(editor.freeBlocks.first?.startTime, hour(12))
        XCTAssertEqual(editor.freeBlocks.first?.endTime, hour(17))
    }

    func test_toggleQuickFill_clearsWindowWhenActive() {
        var editor = makeEditor(freeRanges: [])
        editor.toggleQuickFill(.evening)

        let didAdd = editor.toggleQuickFill(.evening)

        XCTAssertFalse(didAdd)
        XCTAssertFalse(editor.isQuickFillActive(.evening))
        XCTAssertTrue(editor.freeBlocks.isEmpty)
    }

    func test_toggleQuickFill_twiceForEachWindow_returnsToEmpty() {
        var editor = makeEditor(freeRanges: [])

        for quickFill in DayDetailsEditor.QuickFill.allCases {
            editor.toggleQuickFill(quickFill)
            editor.toggleQuickFill(quickFill)
        }

        XCTAssertTrue(editor.freeBlocks.isEmpty)
    }

    func test_toggleQuickFill_adjacentWindowsMergeIntoOne() {
        var editor = makeEditor(freeRanges: [])

        editor.toggleQuickFill(.morning)
        editor.toggleQuickFill(.afternoon)

        XCTAssertEqual(editor.freeBlocks.count, 1)
        XCTAssertEqual(editor.freeBlocks.first?.startTime, hour(9))
        XCTAssertEqual(editor.freeBlocks.first?.endTime, hour(17))
    }

    func test_toggleQuickFill_offSplitsSurroundingWindow() {
        var editor = makeEditor(freeRanges: [(9, 22)])

        let didAdd = editor.toggleQuickFill(.afternoon)

        XCTAssertFalse(didAdd)
        XCTAssertEqual(editor.freeBlocks.count, 2)
        XCTAssertEqual(editor.freeBlocks[0].startTime, hour(9))
        XCTAssertEqual(editor.freeBlocks[0].endTime, hour(12))
        XCTAssertEqual(editor.freeBlocks[1].startTime, hour(17))
        XCTAssertEqual(editor.freeBlocks[1].endTime, hour(22))
    }

    func test_toggleQuickFill_offTruncatesLeadingOverlap() {
        var editor = makeEditor(freeRanges: [(9, 17)])

        editor.toggleQuickFill(.afternoon)

        XCTAssertEqual(editor.freeBlocks.count, 1)
        XCTAssertEqual(editor.freeBlocks.first?.startTime, hour(9))
        XCTAssertEqual(editor.freeBlocks.first?.endTime, hour(12))
    }

    func test_toggleQuickFill_offLeavesDisjointWindowsUntouched() {
        var editor = makeEditor(freeRanges: [(7, 8), (12, 17)])

        editor.toggleQuickFill(.afternoon)

        XCTAssertEqual(editor.freeBlocks.count, 1)
        XCTAssertEqual(editor.freeBlocks.first?.startTime, hour(7))
    }

    // MARK: - Removing

    func test_removeBlock_dropsTargetWindowOnly() {
        var editor = makeEditor(freeRanges: [(9, 11), (14, 16)])
        let target = editor.freeBlocks[0]

        editor.removeBlock(id: target.id)

        XCTAssertEqual(editor.freeBlocks.map(\.startTime), [hour(14)])
    }

    func test_removeBlock_unknownId_isNoOp() {
        var editor = makeEditor(freeRanges: [(9, 11)])

        editor.removeBlock(id: UUID())

        XCTAssertEqual(editor.freeBlocks.count, 1)
    }

    // MARK: - Saving

    func test_makeUpdatedDay_padsGapsWithBusyBlocks() {
        var editor = makeEditor(freeRanges: [])
        editor.toggleQuickFill(.morning)

        let day = editor.makeUpdatedDay(from: DayAvailability(date: date, timeBlocks: []))

        XCTAssertEqual(day.timeBlocks.count, 3)
        XCTAssertEqual(day.timeBlocks[0].status, .busy)
        XCTAssertEqual(day.timeBlocks[1].status, .free)
        XCTAssertEqual(day.timeBlocks[2].status, .busy)
    }

    func test_makeUpdatedDay_coversTheWholeDayWithoutGaps() {
        var editor = makeEditor(freeRanges: [])
        editor.toggleQuickFill(.morning)
        editor.toggleQuickFill(.evening)

        let day = editor.makeUpdatedDay(from: DayAvailability(date: date, timeBlocks: []))

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        XCTAssertEqual(day.timeBlocks.first?.startTime, startOfDay)
        XCTAssertEqual(day.timeBlocks.last?.endTime, endOfDay)
        for (previous, next) in zip(day.timeBlocks, day.timeBlocks.dropFirst()) {
            XCTAssertEqual(previous.endTime, next.startTime)
        }
    }

    func test_makeUpdatedDay_withNoFreeTime_isBusyAllDay() {
        let editor = makeEditor(freeRanges: [])

        let day = editor.makeUpdatedDay(from: DayAvailability(date: date, timeBlocks: []))

        XCTAssertEqual(day.timeBlocks.count, 1)
        XCTAssertEqual(day.timeBlocks.first?.status, .busy)
        XCTAssertEqual(day.status, .busy)
    }

    func test_makeUpdatedDay_freeTillMidnight_omitsTrailingBusyBlock() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let midnight = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let seeded = DayAvailability(date: date, timeBlocks: [
            TimeBlock(startTime: startOfDay, endTime: midnight, status: .free)
        ])
        let editor = DayDetailsEditor(day: seeded)

        let day = editor.makeUpdatedDay(from: seeded)

        XCTAssertEqual(day.timeBlocks.count, 1)
        XCTAssertEqual(day.timeBlocks.first?.status, .free)
    }

    func test_addFreeWindow_cannotExpressMidnightEnd() {
        var editor = makeEditor(freeRanges: [])
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let midnight = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        // Picker values are reduced to hour/minute, so 00:00 the next day collapses
        // onto 00:00 of the edited day and the range is rejected as empty.
        editor.addFreeWindow(from: startOfDay, to: midnight)

        XCTAssertTrue(editor.freeBlocks.isEmpty)
    }

    func test_makeUpdatedDay_preservesIdentityAndNote() {
        let original = DayAvailability(date: date, timeBlocks: [], note: "Gym day")
        var editor = DayDetailsEditor(day: original)
        editor.toggleQuickFill(.morning)

        let day = editor.makeUpdatedDay(from: original)

        XCTAssertEqual(day.id, original.id)
        XCTAssertEqual(day.note, "Gym day")
    }

    func test_makeUpdatedDay_morningQuickFill_readsBackAsMorningOnly() {
        var editor = makeEditor(freeRanges: [])
        editor.toggleQuickFill(.morning)

        let day = editor.makeUpdatedDay(from: DayAvailability(date: date, timeBlocks: []))

        XCTAssertEqual(day.status, .morningOnly)
    }

    // MARK: - Helpers

    private func makeEditor(freeRanges: [(Int, Int)]) -> DayDetailsEditor {
        let blocks = freeRanges.map { TimeBlock(startTime: hour($0.0), endTime: hour($0.1), status: .free) }
        return DayDetailsEditor(day: DayAvailability(date: date, timeBlocks: blocks))
    }

    private func hour(_ value: Int) -> Date {
        time(hour: value, minute: 0)
    }

    private func time(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: startOfDay)!
    }
}
