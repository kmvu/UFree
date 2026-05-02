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
        
        // Create a default time block covering the whole day
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        self.timeBlocks = [
            TimeBlock(startTime: startOfDay, endTime: endOfDay, status: status)
        ]
    }

    /// Computed property for backward compatibility
    public var overallStatus: AvailabilityStatus {
        if timeBlocks.isEmpty {
            return .unknown
        }
        
        let freeBlocks = timeBlocks.filter { $0.status == .free }.sorted { $0.startTime < $1.startTime }
        
        if freeBlocks.isEmpty {
            return .busy
        }
        
        // Check if all blocks are free
        if timeBlocks.allSatisfy({ $0.status == .free }) {
            return .free
        }
        
        // Determine if it matches a specific window
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        // Define windows (consistent with UI)
        let activeStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: startOfDay)!
        let morningEnd = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: startOfDay)!
        let afternoonEnd = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: startOfDay)!
        let activeEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: startOfDay)!
        
        let totalFreeStart = freeBlocks.map { $0.startTime }.min()!
        let totalFreeEnd = freeBlocks.map { $0.endTime }.max()!
        
        // If core active hours are fully covered, it's considered .free
        if totalFreeStart <= activeStart && totalFreeEnd >= activeEnd {
            // Check for gaps within active hours
            var currentEnd = freeBlocks.first!.endTime
            var hasGap = false
            for i in 1..<freeBlocks.count {
                if freeBlocks[i].startTime > currentEnd && freeBlocks[i].startTime < activeEnd {
                    hasGap = true
                    break
                }
                currentEnd = max(currentEnd, freeBlocks[i].endTime)
            }
            if !hasGap { return .free }
        }
        
        // If free time is exactly within one of the quick fill windows
        if totalFreeStart >= activeStart && totalFreeEnd <= morningEnd {
            return .morningOnly
        } else if totalFreeStart >= morningEnd && totalFreeEnd <= afternoonEnd {
            return .afternoonOnly
        } else if totalFreeStart >= afternoonEnd && totalFreeEnd <= activeEnd {
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

