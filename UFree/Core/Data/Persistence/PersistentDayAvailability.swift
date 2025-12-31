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
final class PersistentDayAvailability {
    @Attribute(.unique) var id: UUID
    var date: Date
    var statusValue: Int
    var note: String?

    init(id: UUID, date: Date, statusValue: Int, note: String? = nil) {
        self.id = id
        self.date = date
        self.statusValue = statusValue
        self.note = note
    }
    
    /// Maps persisted data back to domain entity
    func toDomain() -> DayAvailability {
        DayAvailability(
            id: id,
            date: date,
            status: AvailabilityStatus(rawValue: statusValue) ?? .unknown,
            note: note
        )
    }
}

extension DayAvailability {
    /// Maps domain entity to persistence model
    func toPersistent() -> PersistentDayAvailability {
        PersistentDayAvailability(
            id: id,
            date: date,
            statusValue: status.rawValue,
            note: note
        )
    }
}
