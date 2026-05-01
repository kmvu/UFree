//
//  PersistentDayAvailability.swift
//  UFree
//
//  Created by Khang Vu on 29/12/25.
//

import Foundation
import SwiftData

/// SwiftData persistence model for DayAvailability
/// Decoupled from Domain layer - allows schema evolution without affecting business logic
@Model
final class PersistentTimeBlock {
    @Attribute(.unique) var id: UUID
    var startTime: Date
    var endTime: Date
    var statusValue: Int
    var day: PersistentDayAvailability?

    init(id: UUID, startTime: Date, endTime: Date, statusValue: Int) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.statusValue = statusValue
    }

    func toDomain() -> TimeBlock {
        TimeBlock(
            id: id,
            startTime: startTime,
            endTime: endTime,
            status: AvailabilityStatus(rawValue: statusValue) ?? .busy
        )
    }
}

/// SwiftData persistence model for DayAvailability
/// Decoupled from Domain layer - allows schema evolution without affecting business logic
@Model
final class PersistentDayAvailability {
    @Attribute(.unique) var id: UUID
    var date: Date
    var note: String?
    
    @Relationship(deleteRule: .cascade, inverse: \PersistentTimeBlock.day)
    var persistentTimeBlocks: [PersistentTimeBlock] = []

    init(id: UUID, date: Date, note: String? = nil) {
        self.id = id
        self.date = date
        self.note = note
    }
    
    /// Maps persisted data back to domain entity
    func toDomain() -> DayAvailability {
        DayAvailability(
            id: id,
            date: date,
            timeBlocks: persistentTimeBlocks.map { $0.toDomain() },
            note: note
        )
    }
}

extension DayAvailability {
    /// Maps domain entity to persistence model
    func toPersistent() -> PersistentDayAvailability {
        let persistent = PersistentDayAvailability(
            id: id,
            date: date,
            note: note
        )
        persistent.persistentTimeBlocks = timeBlocks.map { block in
            PersistentTimeBlock(
                id: block.id,
                startTime: block.startTime,
                endTime: block.endTime,
                statusValue: block.status.rawValue
            )
        }
        return persistent
    }
}
