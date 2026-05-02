//
//  DayAvailability.swift
//  UFree
//
//  Created by Khang Vu on 22/12/25.
//

import Foundation

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
        
        // If there is only one block and it's an aggregate status, return it directly
        if timeBlocks.count == 1 && timeBlocks[0].status != .free && timeBlocks[0].status != .busy {
            return timeBlocks[0].status
        }
        
        let freeBlocks = timeBlocks.filter { $0.status == .free }.sorted { $0.startTime < $1.startTime }
        
        if freeBlocks.isEmpty {
            return .busy
        }
        
        // Determine if it matches a specific window
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        // Define windows (consistent with UI)
        let activeStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: startOfDay)!
        let morningEnd = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: startOfDay)!
        let afternoonStart = morningEnd
        let afternoonEnd = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: startOfDay)!
        let eveningStart = afternoonEnd
        let activeEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: startOfDay)!
        
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

    /// Alias for overallStatus to maintain backward compatibility with existing code
    public var status: AvailabilityStatus {
        get { overallStatus }
        set {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
            
            switch newValue {
            case .free:
                self.timeBlocks = [TimeBlock(startTime: startOfDay, endTime: endOfDay, status: .free)]
            case .busy:
                self.timeBlocks = [TimeBlock(startTime: startOfDay, endTime: endOfDay, status: .busy)]
            case .morningOnly:
                let mStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: startOfDay)!
                let mEnd = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: startOfDay)!
                self.timeBlocks = [
                    TimeBlock(startTime: startOfDay, endTime: mStart, status: .busy),
                    TimeBlock(startTime: mStart, endTime: mEnd, status: .free),
                    TimeBlock(startTime: mEnd, endTime: endOfDay, status: .busy)
                ]
            case .afternoonOnly:
                let aStart = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: startOfDay)!
                let aEnd = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: startOfDay)!
                self.timeBlocks = [
                    TimeBlock(startTime: startOfDay, endTime: aStart, status: .busy),
                    TimeBlock(startTime: aStart, endTime: aEnd, status: .free),
                    TimeBlock(startTime: aEnd, endTime: endOfDay, status: .busy)
                ]
            case .eveningOnly:
                let eStart = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: startOfDay)!
                let eEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: startOfDay)!
                self.timeBlocks = [
                    TimeBlock(startTime: startOfDay, endTime: eStart, status: .busy),
                    TimeBlock(startTime: eStart, endTime: eEnd, status: .free),
                    TimeBlock(startTime: eEnd, endTime: endOfDay, status: .busy)
                ]
            default:
                self.timeBlocks = [TimeBlock(startTime: startOfDay, endTime: endOfDay, status: newValue)]
            }
        }
    }
}

