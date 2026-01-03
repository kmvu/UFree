//
//  FirestoreDayDTO.swift
//  UFree
//
//  Created by Khang Vu on 3/1/26.
//

import Foundation
import FirebaseFirestore

struct FirestoreDayDTO: Codable {
    let id: String           // The original UUID string
    let dateString: String   // YYYY-MM-DD (Used for sorting/querying)
    let status: Int          // 0=Busy, 1=Free, etc.
    let note: String?
    let updatedAt: Date?     // Server timestamp

    // MARK: - Mappers

    /// Converts a Domain Entity into a format Firestore accepts
    static func fromDomain(_ day: DayAvailability) -> [String: Any] {
        let formatter = DateFormatter.yyyyMMdd
        return [
            "id": day.id.uuidString,
            "dateString": formatter.string(from: day.date),
            "status": day.status.rawValue,
            "note": day.note as Any,
            "updatedAt": FieldValue.serverTimestamp(), // Let server set the time
        ]
    }

    /// Converts Firestore data back into a Domain Entity
    func toDomain(originalDate: Date) -> DayAvailability {
        // We try to restore the UUID, or generate a new one if missing
        let uuid = UUID(uuidString: id) ?? UUID()

        return DayAvailability(
            id: uuid,
            date: originalDate,
            status: AvailabilityStatus(rawValue: status) ?? .unknown,
            note: note
        )
    }
}

// MARK: - Helper for consistent date formatting

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC ensures "Friday" is "Friday" everywhere
        return formatter
    }()
}
