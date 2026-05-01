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
    let status: Int          // Calculated overall status (for legacy/querying)
    let note: String?
    let timeBlocks: [FirestoreTimeBlockDTO]?
    let updatedAt: Date?     // Server timestamp

    struct FirestoreTimeBlockDTO: Codable {
        let id: String
        let startTime: Date
        let endTime: Date
        let status: Int
        
        static func fromDomain(_ block: TimeBlock) -> [String: Any] {
            return [
                "id": block.id.uuidString,
                "startTime": block.startTime,
                "endTime": block.endTime,
                "status": block.status.rawValue
            ]
        }
        
        func toDomain() -> TimeBlock {
            return TimeBlock(
                id: UUID(uuidString: id) ?? UUID(),
                startTime: startTime,
                endTime: endTime,
                status: AvailabilityStatus(rawValue: status) ?? .busy
            )
        }
    }

    // MARK: - Mappers

    /// Converts a Domain Entity into a format Firestore accepts
    static func fromDomain(_ day: DayAvailability) -> [String: Any] {
        let formatter = DateFormatter.yyyyMMdd
        return [
            "id": day.id.uuidString,
            "dateString": formatter.string(from: day.date),
            "status": day.overallStatus.rawValue,
            "note": day.note as Any,
            "timeBlocks": day.timeBlocks.map { FirestoreTimeBlockDTO.fromDomain($0) },
            "updatedAt": FieldValue.serverTimestamp(), // Let server set the time
        ]
    }

    /// Converts Firestore data back into a Domain Entity
    func toDomain(originalDate: Date) -> DayAvailability {
        // We try to restore the UUID, or generate a new one if missing
        let uuid = UUID(uuidString: id) ?? UUID()

        if let timeBlocks = timeBlocks, !timeBlocks.isEmpty {
            return DayAvailability(
                id: uuid,
                date: originalDate,
                timeBlocks: timeBlocks.map { $0.toDomain() },
                note: note
            )
        } else {
            // Fallback for legacy data without timeBlocks
            return DayAvailability(
                id: uuid,
                date: originalDate,
                status: AvailabilityStatus(rawValue: status) ?? .unknown,
                note: note
            )
        }
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
