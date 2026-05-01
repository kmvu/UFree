//
//  TimeBlock.swift
//  UFree
//
//  Created by Cline on 5/1/26.
//

import Foundation

public struct TimeBlock: Identifiable, Codable, Equatable {
    public let id: UUID
    public var startTime: Date
    public var endTime: Date
    public var status: AvailabilityStatus

    public init(id: UUID = UUID(), startTime: Date, endTime: Date, status: AvailabilityStatus) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
    }
}
