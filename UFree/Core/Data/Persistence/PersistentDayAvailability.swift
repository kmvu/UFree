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
            status: AvailabilityStatus(rawValue: statusValue) ?? .unknown
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
    /// Firebase Auth UID that owns this local row (prevents account-switch leaks).
    var ownerUserId: String
    /// True until a remote write ack succeeds — blocks stale cloud overwrite.
    var isPendingSync: Bool
    /// Wall-clock time of the last local edit (compared to Firestore `updatedAt`).
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \PersistentTimeBlock.day)
    var persistentTimeBlocks: [PersistentTimeBlock] = []

    init(
        id: UUID,
        date: Date,
        note: String? = nil,
        ownerUserId: String = "",
        isPendingSync: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.note = note
        self.ownerUserId = ownerUserId
        self.isPendingSync = isPendingSync
        self.updatedAt = updatedAt
    }

    /// Maps persisted data back to domain entity
    func toDomain() -> DayAvailability {
        DayAvailability(
            id: id,
            date: date,
            timeBlocks: persistentTimeBlocks.map { $0.toDomain() },
            note: note,
            updatedAt: updatedAt
        )
    }
}

extension DayAvailability {
    /// Maps domain entity to persistence model
    func toPersistent(ownerUserId: String) -> PersistentDayAvailability {
        let persistent = PersistentDayAvailability(
            id: id,
            date: date,
            note: note,
            ownerUserId: ownerUserId,
            isPendingSync: false,
            updatedAt: updatedAt ?? Date()
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

    /// Legacy helper — prefer `toPersistent(ownerUserId:)`.
    func toPersistent() -> PersistentDayAvailability {
        toPersistent(ownerUserId: "")
    }
}
