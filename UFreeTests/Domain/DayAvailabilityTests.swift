//
//  DayAvailabilityTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 22/12/25.
//

import XCTest
import Foundation
@testable import UFree

final class DayAvailabilityTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func test_init_withDefaultValues_createsDayWithBusyStatus() {
        let date = Date()
        let day = DayAvailability(date: date)
        
        XCTAssertEqual(day.date.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(day.status, .busy)
        XCTAssertNil(day.note)
        XCTAssertNotNil(day.id)
    }
    
    func test_init_withAllParameters_createsDayWithAllValues() {
        let id = UUID()
        let date = Date()
        let status = AvailabilityStatus.free
        let note = "Free for dinner"
        
        let day = DayAvailability(id: id, date: date, status: status, note: note)
        
        XCTAssertEqual(day.id, id)
        XCTAssertEqual(day.date.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(day.status, status)
        XCTAssertEqual(day.note, note)
    }
    
    func test_init_withoutId_generatesUniqueId() {
        let date = Date()
        let day1 = DayAvailability(date: date)
        let day2 = DayAvailability(date: date)
        
        XCTAssertNotEqual(day1.id, day2.id)
    }
    
    // MARK: - Mutability Tests
    
    func test_properties_canBeMutated() {
        var day = DayAvailability(date: Date(), status: .busy)
        
        day.status = .free
        XCTAssertEqual(day.status, .free)
        
        day.status = .busy
        XCTAssertEqual(day.status, .busy)
        
        day.note = "Free for dinner"
        XCTAssertEqual(day.note, "Free for dinner")
        
        day.note = nil
        XCTAssertNil(day.note)
    }
    
    // MARK: - Codable Tests
    
    func test_codable_encodesAndDecodesWithAllValues() throws {
        let date = Date()
        let original = DayAvailability(
            id: UUID(),
            date: date,
            status: .eveningOnly,
            note: "Free for dinner"
        )
        
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DayAvailability.self, from: encoded)
        
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.date.timeIntervalSince1970, original.date.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(decoded.status, original.status)
        XCTAssertEqual(decoded.note, original.note)
    }
    
    func test_codable_encodesAndDecodesWithoutNote() throws {
        let date = Date()
        let original = DayAvailability(date: date, status: .free)
        
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DayAvailability.self, from: encoded)
        
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.status, original.status)
        XCTAssertNil(decoded.note)
    }
}

