//
//  AvailabilityStatusTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 22/12/25.
//

import XCTest
@testable import UFree

final class AvailabilityStatusTests: XCTestCase {
    
    func test_allCases_hasSevenCases() {
        let allCases = AvailabilityStatus.allCases
        XCTAssertEqual(allCases.count, 7) // busy, free, morningOnly, afternoonOnly, eveningOnly, mixed, unknown
    }
    
    func test_rawValues_matchExpectedIntValues() {
        XCTAssertEqual(AvailabilityStatus.busy.rawValue, 0)
        XCTAssertEqual(AvailabilityStatus.free.rawValue, 1)
        XCTAssertEqual(AvailabilityStatus.morningOnly.rawValue, 2)
        XCTAssertEqual(AvailabilityStatus.afternoonOnly.rawValue, 3)
        XCTAssertEqual(AvailabilityStatus.eveningOnly.rawValue, 4)
        XCTAssertEqual(AvailabilityStatus.mixed.rawValue, 5)
        XCTAssertEqual(AvailabilityStatus.unknown.rawValue, 6)
    }
    
    func test_displayName_returnsCorrectStrings() {
        XCTAssertEqual(AvailabilityStatus.busy.displayName, "Busy")
        XCTAssertEqual(AvailabilityStatus.free.displayName, "Free")
        XCTAssertEqual(AvailabilityStatus.morningOnly.displayName, "Free\nMorning")
        XCTAssertEqual(AvailabilityStatus.afternoonOnly.displayName, "Free\nAfternoon")
        XCTAssertEqual(AvailabilityStatus.eveningOnly.displayName, "Free\nEvening")
        XCTAssertEqual(AvailabilityStatus.mixed.displayName, "Mixed")
        XCTAssertEqual(AvailabilityStatus.unknown.displayName, "Unknown")
    }
    
    func test_codable_encodesAndDecodesCorrectly() throws {
        let statuses: [AvailabilityStatus] = [.busy, .free, .morningOnly, .afternoonOnly, .eveningOnly, .mixed, .unknown]
        
        for status in statuses {
            let encoded = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(AvailabilityStatus.self, from: encoded)
            XCTAssertEqual(decoded, status, "Failed to encode/decode \(status)")
        }
    }
    
    func test_initFromRawValue_createsCorrectCases() {
        XCTAssertEqual(AvailabilityStatus(rawValue: 0), .busy)
        XCTAssertEqual(AvailabilityStatus(rawValue: 1), .free)
        XCTAssertEqual(AvailabilityStatus(rawValue: 2), .morningOnly)
        XCTAssertEqual(AvailabilityStatus(rawValue: 3), .afternoonOnly)
        XCTAssertEqual(AvailabilityStatus(rawValue: 4), .eveningOnly)
        XCTAssertEqual(AvailabilityStatus(rawValue: 5), .mixed)
        XCTAssertEqual(AvailabilityStatus(rawValue: 6), .unknown)
        XCTAssertNil(AvailabilityStatus(rawValue: 99))
    }
}
