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
    public var status: AvailabilityStatus
    public var note: String?

    public init(id: UUID = UUID(), date: Date, status: AvailabilityStatus = .busy, note: String? = nil) {
        self.id = id
        self.date = date
        self.status = status
        self.note = note
    }
}

