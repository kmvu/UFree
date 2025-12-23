//
//  AvailabilityStatusTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 22/12/25.
//

import XCTest
@testable import UFree

final class AvailabilityStatusTests: XCTestCase {
    
    func test_allCases_hasFourCases() {
        let allCases = AvailabilityStatus.allCases
        XCTAssertEqual(allCases.count, 4)
    }
    
    func test_rawValues_matchExpectedIntValues() {
        XCTAssertEqual(AvailabilityStatus.busy.rawValue, 0)
        XCTAssertEqual(AvailabilityStatus.free.rawValue, 1)
        XCTAssertEqual(AvailabilityStatus.eveningOnly.rawValue, 2)
        XCTAssertEqual(AvailabilityStatus.unknown.rawValue, 3)
    }
    
    func test_displayName_returnsCorrectStrings() {
        XCTAssertEqual(AvailabilityStatus.busy.displayName, "Busy")
        XCTAssertEqual(AvailabilityStatus.free.displayName, "Free")
        XCTAssertEqual(AvailabilityStatus.eveningOnly.displayName, "Evening Only")
        XCTAssertEqual(AvailabilityStatus.unknown.displayName, "No Status")
    }
    
    func test_codable_encodesAndDecodesCorrectly() throws {
        let statuses: [AvailabilityStatus] = [.busy, .free, .eveningOnly, .unknown]
        
        for status in statuses {
            let encoded = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(AvailabilityStatus.self, from: encoded)
            XCTAssertEqual(decoded, status, "Failed to encode/decode \(status)")
        }
    }
    
    func test_initFromRawValue_createsCorrectCases() {
        XCTAssertEqual(AvailabilityStatus(rawValue: 0), .busy)
        XCTAssertEqual(AvailabilityStatus(rawValue: 1), .free)
        XCTAssertEqual(AvailabilityStatus(rawValue: 2), .eveningOnly)
        XCTAssertEqual(AvailabilityStatus(rawValue: 3), .unknown)
        XCTAssertNil(AvailabilityStatus(rawValue: 99))
    }
}

