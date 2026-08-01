//
//  AvailabilityTruth.swift
//  UFree
//
//  Shared availability predicates for heatmap, nudge, and discovery.
//

import Foundation

public enum AvailabilityTruth {
    /// True when the day has any free window (full-day free or partial free blocks).
    public static func isAvailable(_ day: DayAvailability) -> Bool {
        if day.status == .free
            || day.status == .morningOnly
            || day.status == .afternoonOnly
            || day.status == .eveningOnly {
            return true
        }
        return day.timeBlocks.contains { $0.status == .free }
    }

    /// True when a friend's status for a date should count toward heatmap / Nudge All.
    public static func isAvailable(status: AvailabilityStatus, timeBlocks: [TimeBlock] = []) -> Bool {
        switch status {
        case .free, .morningOnly, .afternoonOnly, .eveningOnly:
            return true
        case .mixed:
            return timeBlocks.contains { $0.status == .free }
        case .busy, .unknown:
            return false
        }
    }
}

public extension DayAvailability {
    var isAvailable: Bool {
        AvailabilityTruth.isAvailable(self)
    }
}
