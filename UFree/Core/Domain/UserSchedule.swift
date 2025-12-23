//
//  UserSchedule.swift
//  UFree
//
//  Created by Khang Vu on 22/12/25.
//

import Foundation

public struct UserSchedule: Identifiable {
    public let id: String // The User's Unique ID
    public let name: String
    public let avatarURL: URL?
    public var weeklyStatus: [DayAvailability]
    
    public init(id: String, name: String, avatarURL: URL? = nil, weeklyStatus: [DayAvailability]) {
        self.id = id
        self.name = name
        self.avatarURL = avatarURL
        self.weeklyStatus = weeklyStatus
    }
    
    // Helper to find status for a specific day
    public func status(for date: Date) -> DayAvailability? {
        return weeklyStatus.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
}

