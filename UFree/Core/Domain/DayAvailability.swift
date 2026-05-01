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
        
        // If there's only one block, return its status
        if timeBlocks.count == 1 {
            return timeBlocks[0].status
        }
        
        // Logic for multiple blocks:
        // If they are all the same, return that.
        let statuses = Set(timeBlocks.map { $0.status })
        if statuses.count == 1, let status = statuses.first {
            return status
        }
        
        // If mixed, prioritize 'free' for overall visibility.
        if timeBlocks.contains(where: { $0.status == .free }) {
            return .free
        }
        
        return timeBlocks.first?.status ?? .busy
    }

    /// Alias for overallStatus to maintain backward compatibility with existing code
    public var status: AvailabilityStatus {
        get { overallStatus }
        set {
            let startOfDay = Calendar.current.startOfDay(for: date)
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? date
            self.timeBlocks = [
                TimeBlock(startTime: startOfDay, endTime: endOfDay, status: newValue)
            ]
        }
    }
}

