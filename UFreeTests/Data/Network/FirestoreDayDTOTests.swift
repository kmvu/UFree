//
//  FirestoreDayDTOTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 3/1/26.
//

import XCTest
@testable import UFree

final class FirestoreDayDTOTests: XCTestCase {
    
    // MARK: - Tests: Domain to Firestore (Encoding)
    
    func test_fromDomain_convertsStatusCorrectly() {
        // Arrange
        let day = DayAvailability(
            date: Date(),
            status: .free,
            note: "Available now"
        )
        
        // Act
        let data = FirestoreDayDTO.fromDomain(day)
        
        // Assert
        XCTAssertEqual(data["status"] as? Int, 1) // free = 1
        XCTAssertEqual(data["note"] as? String, "Available now")
        XCTAssertEqual(data["id"] as? String, day.id.uuidString)
    }
    
    func test_fromDomain_includesDateString_inYYYYMMDDFormat() {
        // Arrange
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 3
        components.timeZone = TimeZone(secondsFromGMT: 0)
        
        let date = calendar.date(from: components)!
        let day = DayAvailability(date: date, status: .busy)
        
        // Act
        let data = FirestoreDayDTO.fromDomain(day)
        
        // Assert
        XCTAssertEqual(data["dateString"] as? String, "2026-01-03")
    }
    
    func test_fromDomain_handlesNilNote() {
        // Arrange
        let day = DayAvailability(date: Date(), status: .busy, note: nil)
        
        // Act
        let data = FirestoreDayDTO.fromDomain(day)
        
        // Assert
        XCTAssertNotNil(data["note"]) // Should be included as Any type
    }
    
    func test_fromDomain_allStatusValues() {
        // Test all status rawValues map correctly
        let statuses: [(AvailabilityStatus, Int)] = [
            (.busy, 0),
            (.free, 1),
            (.morningOnly, 2),
            (.afternoonOnly, 3),
            (.eveningOnly, 4),
            (.unknown, 5),
        ]
        
        for (status, expectedRawValue) in statuses {
            let day = DayAvailability(date: Date(), status: status)
            let data = FirestoreDayDTO.fromDomain(day)
            XCTAssertEqual(data["status"] as? Int, expectedRawValue, "Status \(status) should have rawValue \(expectedRawValue)")
        }
    }
    
    // MARK: - Tests: Firestore to Domain (Decoding)
    
    func test_toDomain_convertsStatusFromInt() {
        // Arrange
        let date = Date()
        let dto = FirestoreDayDTO(
            id: UUID().uuidString,
            dateString: DateFormatter.yyyyMMdd.string(from: date),
            status: 1, // free
            note: "Test note",
            updatedAt: Date()
        )
        
        // Act
        let domain = dto.toDomain(originalDate: date)
        
        // Assert
        XCTAssertEqual(domain.status, .free)
        XCTAssertEqual(domain.note, "Test note")
        XCTAssertEqual(domain.date, date)
    }
    
    func test_toDomain_restoresUUIDFromString() {
        // Arrange
        let originalUUID = UUID()
        let date = Date()
        let dto = FirestoreDayDTO(
            id: originalUUID.uuidString,
            dateString: DateFormatter.yyyyMMdd.string(from: date),
            status: 0,
            note: nil,
            updatedAt: nil
        )
        
        // Act
        let domain = dto.toDomain(originalDate: date)
        
        // Assert
        XCTAssertEqual(domain.id, originalUUID)
    }
    
    func test_toDomain_generatesNewUUID_whenStringInvalid() {
        // Arrange
        let date = Date()
        let dto = FirestoreDayDTO(
            id: "invalid-uuid-string",
            dateString: DateFormatter.yyyyMMdd.string(from: date),
            status: 0,
            note: nil,
            updatedAt: nil
        )
        
        // Act
        let domain = dto.toDomain(originalDate: date)
        
        // Assert
        // Should generate a new UUID instead of crashing
        XCTAssertNotNil(domain.id)
        // We can't assert the exact UUID, but we verify it's a valid UUID
        XCTAssertTrue(domain.id.uuidString.count == 36) // UUID string format
    }
    
    func test_toDomain_defaultsToUnknownStatus_forInvalidStatus() {
        // Arrange
        let date = Date()
        let dto = FirestoreDayDTO(
            id: UUID().uuidString,
            dateString: DateFormatter.yyyyMMdd.string(from: date),
            status: 999, // Invalid status
            note: nil,
            updatedAt: nil
        )
        
        // Act
        let domain = dto.toDomain(originalDate: date)
        
        // Assert
        XCTAssertEqual(domain.status, .unknown)
    }
    
    func test_toDomain_allStatusValuesRoundTrip() {
        // Test all status rawValues decode correctly
        let date = Date()
        let statuses: [(Int, AvailabilityStatus)] = [
            (0, .busy),
            (1, .free),
            (2, .morningOnly),
            (3, .afternoonOnly),
            (4, .eveningOnly),
            (5, .unknown),
        ]
        
        for (statusInt, expectedStatus) in statuses {
            let dto = FirestoreDayDTO(
                id: UUID().uuidString,
                dateString: DateFormatter.yyyyMMdd.string(from: date),
                status: statusInt,
                note: nil,
                updatedAt: nil
            )
            let domain = dto.toDomain(originalDate: date)
            XCTAssertEqual(domain.status, expectedStatus, "Status int \(statusInt) should decode to \(expectedStatus)")
        }
    }
    
    // MARK: - Tests: Round-Trip Consistency
    
    func test_roundTrip_encodeDecodePreservesData() {
        // Arrange
        let originalDay = DayAvailability(
            date: Date(),
            status: .afternoonOnly,
            note: "Only available in afternoon"
        )
        
        // Act
        let encodedData = FirestoreDayDTO.fromDomain(originalDay)
        let dto = FirestoreDayDTO(
            id: encodedData["id"] as! String,
            dateString: encodedData["dateString"] as! String,
            status: encodedData["status"] as! Int,
            note: encodedData["note"] as? String,
            updatedAt: encodedData["updatedAt"] as? Date
        )
        let decodedDay = dto.toDomain(originalDate: originalDay.date)
        
        // Assert
        XCTAssertEqual(decodedDay.id, originalDay.id)
        XCTAssertEqual(decodedDay.status, originalDay.status)
        XCTAssertEqual(decodedDay.note, originalDay.note)
        // Date might have precision loss, so just check they're the same day
        XCTAssertTrue(Calendar.current.isDate(decodedDay.date, inSameDayAs: originalDay.date))
    }
    
    func test_dateFormatter_yyyyMMdd_usesUTC() {
        // Ensure consistent date formatting across timezones
        let formatter = DateFormatter.yyyyMMdd
        
        XCTAssertEqual(formatter.timeZone, TimeZone(secondsFromGMT: 0))
        XCTAssertEqual(formatter.dateFormat, "yyyy-MM-dd")
        XCTAssertEqual(formatter.calendar.identifier, .gregorian)
    }
    
    func test_dateFormatter_parsesAndFormatsConsistently() {
        // Arrange
        let formatter = DateFormatter.yyyyMMdd
        let dateString = "2026-01-15"
        
        // Act
        guard let parsedDate = formatter.date(from: dateString) else {
            XCTFail("Failed to parse date string")
            return
        }
        let reformattedString = formatter.string(from: parsedDate)
        
        // Assert
        XCTAssertEqual(reformattedString, dateString)
    }
}
