//
//  DayDetailsEditor.swift
//  UFree
//

import Foundation

/// Time-block arithmetic behind the day-details editing sheet.
///
/// Lives outside the SwiftUI layer so the merge/split rules can be verified directly
/// instead of through view state.
struct DayDetailsEditor: Equatable {

    /// Hour boundaries for the "Morning / Afternoon / Evening" shortcuts.
    enum QuickFill: CaseIterable {
        case morning
        case afternoon
        case evening

        var startHour: Int {
            switch self {
            case .morning: return 9
            case .afternoon: return 12
            case .evening: return 17
            }
        }

        var endHour: Int {
            switch self {
            case .morning: return 12
            case .afternoon: return 17
            case .evening: return 22
            }
        }
    }

    private let date: Date
    private let calendar: Calendar

    private(set) var blocks: [TimeBlock]

    init(day: DayAvailability, calendar: Calendar = .current) {
        self.date = day.date
        self.calendar = calendar
        self.blocks = day.timeBlocks
    }

    // MARK: - Derived State

    /// Free windows in chronological order — what the sheet lists and what `isEmpty`
    /// checks in the UI are based on.
    var freeBlocks: [TimeBlock] {
        blocks.filter { $0.status == .free }.sorted { $0.startTime < $1.startTime }
    }

    /// The default "Starts" value: now for today, otherwise 09:00 on the target day.
    func defaultStartTime(now: Date = Date()) -> Date {
        if calendar.isDate(now, inSameDayAs: date) {
            return now
        }
        return hour(9)
    }

    /// The default "Ends" value: one hour after the start.
    func defaultEndTime(now: Date = Date()) -> Date {
        let start = defaultStartTime(now: now)
        return calendar.date(byAdding: .hour, value: 1, to: start) ?? start
    }

    func isQuickFillActive(_ quickFill: QuickFill) -> Bool {
        let start = hour(quickFill.startHour)
        let end = hour(quickFill.endHour)
        return blocks.contains { $0.status == .free && $0.startTime <= start && $0.endTime >= end }
    }

    // MARK: - Mutations

    /// Adds a free window using only the hour/minute of the given dates, so a picker
    /// value from another calendar day still lands on the day being edited.
    mutating func addFreeWindow(from start: Date, to end: Date) {
        let components: Set<Calendar.Component> = [.hour, .minute]
        let startParts = calendar.dateComponents(components, from: start)
        let endParts = calendar.dateComponents(components, from: end)

        guard let startHour = startParts.hour, let startMinute = startParts.minute,
              let endHour = endParts.hour, let endMinute = endParts.minute else { return }

        let normalizedStart = time(hour: startHour, minute: startMinute)
        let normalizedEnd = time(hour: endHour, minute: endMinute)

        guard normalizedStart < normalizedEnd else { return }

        merge(TimeBlock(startTime: normalizedStart, endTime: normalizedEnd, status: .free))
    }

    /// Adds the quick-fill window if it is not already covered, otherwise clears it.
    /// - Returns: `true` when the window was added, `false` when it was removed.
    @discardableResult
    mutating func toggleQuickFill(_ quickFill: QuickFill) -> Bool {
        let start = hour(quickFill.startHour)
        let end = hour(quickFill.endHour)

        if isQuickFillActive(quickFill) {
            subtractFreeRange(from: start, to: end)
            return false
        }

        merge(TimeBlock(startTime: start, endTime: end, status: .free))
        return true
    }

    mutating func removeBlock(id: UUID) {
        blocks.removeAll { $0.id == id }
    }

    // MARK: - Saving

    /// Rebuilds a full-day timeline by padding the gaps between free windows with
    /// busy blocks, so persisted days always cover midnight-to-midnight.
    func makeUpdatedDay(from day: DayAvailability) -> DayAvailability {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        var timeline: [TimeBlock] = []
        var cursor = startOfDay

        for freeBlock in freeBlocks {
            if freeBlock.startTime > cursor {
                timeline.append(TimeBlock(startTime: cursor, endTime: freeBlock.startTime, status: .busy))
            }
            timeline.append(freeBlock)
            cursor = freeBlock.endTime
        }

        if cursor < endOfDay {
            timeline.append(TimeBlock(startTime: cursor, endTime: endOfDay, status: .busy))
        }

        var updatedDay = day
        updatedDay.timeBlocks = timeline
        return updatedDay
    }

    // MARK: - Block Arithmetic

    /// Inserts `newBlock` and coalesces it with any free window it touches or overlaps.
    private mutating func merge(_ newBlock: TimeBlock) {
        var candidates = freeBlocks
        candidates.append(newBlock)
        candidates.sort { $0.startTime < $1.startTime }

        var merged: [TimeBlock] = []
        for block in candidates {
            if let last = merged.last, block.startTime <= last.endTime {
                merged[merged.count - 1].endTime = max(last.endTime, block.endTime)
            } else {
                merged.append(block)
            }
        }

        blocks = blocks.filter { $0.status != .free } + merged
    }

    /// Removes the given range from every free window, splitting windows that straddle it.
    private mutating func subtractFreeRange(from start: Date, to end: Date) {
        var remaining: [TimeBlock] = []

        for block in freeBlocks {
            let isDisjoint = block.endTime <= start || block.startTime >= end
            if isDisjoint {
                remaining.append(block)
                continue
            }

            if block.startTime < start {
                remaining.append(TimeBlock(startTime: block.startTime, endTime: start, status: .free))
            }
            if block.endTime > end {
                remaining.append(TimeBlock(startTime: end, endTime: block.endTime, status: .free))
            }
        }

        blocks = blocks.filter { $0.status != .free } + remaining
    }

    // MARK: - Date Helpers

    private func hour(_ value: Int) -> Date {
        time(hour: value, minute: 0)
    }

    private func time(hour: Int, minute: Int) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: startOfDay) ?? startOfDay
    }
}
