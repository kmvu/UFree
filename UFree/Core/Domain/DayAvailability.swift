//
//  DayAvailability.swift
//  UFree
//
//  Created by Khang Vu on 22/12/25.
//

import Foundation

fileprivate struct QuickFillWindows {
    static let morningStartHour: Int = 9
    static let morningEndHour: Int = 12
    static let afternoonEndHour: Int = 17
    static let activeEndHour: Int = 22

    struct Boundaries {
        let startOfDay: Date
        let endOfDay: Date
        let activeStart: Date      // 09:00
        let morningEnd: Date       // 12:00
        let afternoonStart: Date   // 12:00
        let afternoonEnd: Date     // 17:00
        let eveningStart: Date     // 17:00
        let activeEnd: Date        // 22:00
    }

    static func boundaries(for date: Date, calendar: Calendar = .current) -> Boundaries {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        let activeStart = calendar.date(bySettingHour: morningStartHour, minute: 0, second: 0, of: startOfDay)!
        let morningEnd = calendar.date(bySettingHour: morningEndHour, minute: 0, second: 0, of: startOfDay)!
        let afternoonStart = morningEnd
        let afternoonEnd = calendar.date(bySettingHour: afternoonEndHour, minute: 0, second: 0, of: startOfDay)!
        let eveningStart = afternoonEnd
        let activeEnd = calendar.date(bySettingHour: activeEndHour, minute: 0, second: 0, of: startOfDay)!

        return Boundaries(
            startOfDay: startOfDay,
            endOfDay: endOfDay,
            activeStart: activeStart,
            morningEnd: morningEnd,
            afternoonStart: afternoonStart,
            afternoonEnd: afternoonEnd,
            eveningStart: eveningStart,
            activeEnd: activeEnd
        )
    }
}

public struct DayAvailability: Identifiable, Codable {
    public let id: UUID
    public let date: Date
    public var timeBlocks: [TimeBlock]
    public var note: String?

    public init(id: UUID = UUID(), date: Date, timeBlocks: [TimeBlock]? = nil, note: String? = nil) {
        self.id = id
        self.date = date
        self.note = note
        
        if let timeBlocks = timeBlocks {
            self.timeBlocks = timeBlocks
        } else {
            // Default to a single busy block covering the whole day
            let startOfDay = Calendar.current.startOfDay(for: date)
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? date
            self.timeBlocks = [
                TimeBlock(startTime: startOfDay, endTime: endOfDay, status: .busy)
            ]
        }
    }

    /// Backwards compatibility initializer
    public init(id: UUID = UUID(), date: Date, status: AvailabilityStatus, note: String? = nil) {
        self.id = id
        self.date = date
        self.note = note
        self.timeBlocks = [] // Temporary
        self.status = status // Use the setter logic
    }

    /// Computed property for backward compatibility
    public var overallStatus: AvailabilityStatus {
        if timeBlocks.isEmpty {
            return .unknown
        }
        
        // If there is only one block and it's a specific quick-fill window, return it directly.
        if timeBlocks.count == 1 {
            let status = timeBlocks[0].status
            // Return aggregate statuses directly. Mixed is allowed as a placeholder for legacy data.
            if status == .morningOnly || status == .afternoonOnly || status == .eveningOnly || status == .unknown || status == .mixed {
                return status
            }
        }
        
        let freeBlocks = timeBlocks.filter { $0.status == .free }.sorted { $0.startTime < $1.startTime }
        
        if freeBlocks.isEmpty {
            return .busy
        }
        
        let calendar = Calendar.current
        let b = QuickFillWindows.boundaries(for: date, calendar: calendar)
        let activeStart = b.activeStart
        let morningEnd = b.morningEnd
        let afternoonStart = b.afternoonStart
        let afternoonEnd = b.afternoonEnd
        let eveningStart = b.eveningStart
        let activeEnd = b.activeEnd
        
        let totalFreeStart = freeBlocks.map { $0.startTime }.min()!
        let totalFreeEnd = freeBlocks.map { $0.endTime }.max()!

        // Helper to check if a date is at or before another, ignoring seconds
        func isAtOrBefore(_ d1: Date, _ d2: Date) -> Bool {
            return calendar.compare(d1, to: d2, toGranularity: .minute) != .orderedDescending
        }
        
        // Helper to check if a date is at or after another, ignoring seconds
        func isAtOrAfter(_ d1: Date, _ d2: Date) -> Bool {
            return calendar.compare(d1, to: d2, toGranularity: .minute) != .orderedAscending
        }

        // If core active hours are fully covered, it's considered .free
        // We must ensure the start is at or before activeStart AND end is at or after activeEnd
        // AND there are no gaps between activeStart and activeEnd.
        if isAtOrBefore(totalFreeStart, activeStart) && isAtOrAfter(totalFreeEnd, activeEnd) {
            let sortedFree = freeBlocks.sorted { $0.startTime < $1.startTime }
            
            // Re-verify start/end with sorted blocks to be safe
            if isAtOrBefore(sortedFree.first!.startTime, activeStart) && isAtOrAfter(sortedFree.last!.endTime, activeEnd) {
                var currentEnd = sortedFree.first!.endTime
                var hasGap = false
                for i in 1..<sortedFree.count {
                    // If this block starts after currentEnd, there's a gap
                    // Check if this gap starts before activeEnd and ends after activeStart
                    if calendar.compare(sortedFree[i].startTime, to: currentEnd, toGranularity: .minute) == .orderedDescending {
                        if calendar.compare(sortedFree[i].startTime, to: activeEnd, toGranularity: .minute) == .orderedAscending &&
                           calendar.compare(currentEnd, to: activeStart, toGranularity: .minute) == .orderedDescending {
                            hasGap = true
                            break
                        }
                    }
                    currentEnd = max(currentEnd, sortedFree[i].endTime)
                }
                if !hasGap { return .free }
            }
        }
        
        // If free time falls within one of the quick fill windows
        func isWithinWindow(start: Date, end: Date) -> Bool {
            return isAtOrAfter(totalFreeStart, start) && isAtOrBefore(totalFreeEnd, end)
        }

        if isWithinWindow(start: activeStart, end: morningEnd) {
            return .morningOnly
        } else if isWithinWindow(start: afternoonStart, end: afternoonEnd) {
            return .afternoonOnly
        } else if isWithinWindow(start: eveningStart, end: activeEnd) {
            return .eveningOnly
        }
        
        // If none of the specific windows match, it's mixed
        return .mixed
    }

    /// Returns a human-readable string for the earliest free time block, if any.
    public var earliestFreeBlockInfo: String? {
        let freeBlocks = timeBlocks.filter { $0.status == .free }.sorted { $0.startTime < $1.startTime }
        guard let firstFree = freeBlocks.first else { return nil }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "Free starting\n\(formatter.string(from: firstFree.startTime))"
    }

    /// Alias for overallStatus to maintain backward compatibility with existing code
    public var status: AvailabilityStatus {
        get { overallStatus }
        set {
            let calendar = Calendar.current
            let b = QuickFillWindows.boundaries(for: date, calendar: calendar)
            let startOfDay = b.startOfDay
            let endOfDay = b.endOfDay
            
            switch newValue {
            case .free:
                self.timeBlocks = [TimeBlock(startTime: startOfDay, endTime: endOfDay, status: .free)]
            case .busy:
                self.timeBlocks = [TimeBlock(startTime: startOfDay, endTime: endOfDay, status: .busy)]
            case .morningOnly:
                let mStart = b.activeStart
                let mEnd = b.morningEnd
                self.timeBlocks = [
                    TimeBlock(startTime: startOfDay, endTime: mStart, status: .busy),
                    TimeBlock(startTime: mStart, endTime: mEnd, status: .free),
                    TimeBlock(startTime: mEnd, endTime: endOfDay, status: .busy)
                ]
            case .afternoonOnly:
                let aStart = b.afternoonStart
                let aEnd = b.afternoonEnd
                self.timeBlocks = [
                    TimeBlock(startTime: startOfDay, endTime: aStart, status: .busy),
                    TimeBlock(startTime: aStart, endTime: aEnd, status: .free),
                    TimeBlock(startTime: aEnd, endTime: endOfDay, status: .busy)
                ]
            case .eveningOnly:
                let eStart = b.eveningStart
                let eEnd = b.activeEnd
                self.timeBlocks = [
                    TimeBlock(startTime: startOfDay, endTime: eStart, status: .busy),
                    TimeBlock(startTime: eStart, endTime: eEnd, status: .free),
                    TimeBlock(startTime: eEnd, endTime: endOfDay, status: .busy)
                ]
            case .mixed:
                // For legacy mixed status without blocks, we use a single mixed block as placeholder
                self.timeBlocks = [TimeBlock(startTime: startOfDay, endTime: endOfDay, status: .mixed)]
            case .unknown:
                // Unknown means no availability data yet
                self.timeBlocks = []
            }
        }
    }
}
