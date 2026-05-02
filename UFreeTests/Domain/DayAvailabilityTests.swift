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
        // Note: New logic defaults to a single busy block covering the whole day.
        XCTAssertEqual(day.status, AvailabilityStatus.busy)
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
    
    // MARK: - TimeBlock Tests
    
    func test_overallStatus_withMultipleDistinctStatuses_returnsMixed() {
        let date = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        // 9 AM to 5 PM (covers Morning and Afternoon) -> Mixed
        let morningStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: startOfDay)!
        let afternoonEnd = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: startOfDay)!
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let blocks = [
            TimeBlock(startTime: startOfDay, endTime: morningStart, status: .busy),
            TimeBlock(startTime: morningStart, endTime: afternoonEnd, status: .free),
            TimeBlock(startTime: afternoonEnd, endTime: endOfDay, status: .busy)
        ]
        
        let day = DayAvailability(date: date, timeBlocks: blocks)
        
        XCTAssertEqual(day.overallStatus, .mixed)
    }
    
    func test_overallStatus_detectsMorningOnly() {
        let date = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let morningStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: startOfDay)!
        let morningEnd = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: startOfDay)!
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let blocks = [
            TimeBlock(startTime: startOfDay, endTime: morningStart, status: .busy),
            TimeBlock(startTime: morningStart, endTime: morningEnd, status: .free),
            TimeBlock(startTime: morningEnd, endTime: endOfDay, status: .busy)
        ]
        
        let day = DayAvailability(date: date, timeBlocks: blocks)
        XCTAssertEqual(day.overallStatus, .morningOnly)
    }
    
    func test_overallStatus_detectsAfternoonOnly() {
        let date = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let afternoonStart = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: startOfDay)!
        let afternoonEnd = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: startOfDay)!
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let blocks = [
            TimeBlock(startTime: startOfDay, endTime: afternoonStart, status: .busy),
            TimeBlock(startTime: afternoonStart, endTime: afternoonEnd, status: .free),
            TimeBlock(startTime: afternoonEnd, endTime: endOfDay, status: .busy)
        ]
        
        let day = DayAvailability(date: date, timeBlocks: blocks)
        XCTAssertEqual(day.overallStatus, .afternoonOnly)
    }
    
    func test_overallStatus_detectsEveningOnly() {
        let date = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let eveningStart = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: startOfDay)!
        let eveningEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: startOfDay)!
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let blocks = [
            TimeBlock(startTime: startOfDay, endTime: eveningStart, status: .busy),
            TimeBlock(startTime: eveningStart, endTime: eveningEnd, status: .free),
            TimeBlock(startTime: eveningEnd, endTime: endOfDay, status: .busy)
        ]
        
        let day = DayAvailability(date: date, timeBlocks: blocks)
        XCTAssertEqual(day.overallStatus, .eveningOnly)
    }
    
    func test_overallStatus_withAllSameStatuses_returnsThatStatus() {
        let date = Date()
        let startOfDay = Calendar.current.startOfDay(for: date)
        let noon = Calendar.current.date(byAdding: .hour, value: 12, to: startOfDay)!
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let blocks = [
            TimeBlock(startTime: startOfDay, endTime: noon, status: .free),
            TimeBlock(startTime: noon, endTime: endOfDay, status: .free)
        ]
        
        let day = DayAvailability(date: date, timeBlocks: blocks)
        
        XCTAssertEqual(day.overallStatus, .free)
    }
    
    func test_overallStatus_withOnlyBusyBlocks_returnsBusy() {
        let date = Date()
        let startOfDay = Calendar.current.startOfDay(for: date)
        let afternoon = Calendar.current.date(byAdding: .hour, value: 12, to: startOfDay)!
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let blocks = [
            TimeBlock(startTime: startOfDay, endTime: afternoon, status: .busy),
            TimeBlock(startTime: afternoon, endTime: endOfDay, status: .busy)
        ]
        
        let day = DayAvailability(date: date, timeBlocks: blocks)
        
        XCTAssertEqual(day.overallStatus, .busy)
    }
    
    func test_statusSetter_replacesTimeBlocks() {
        let date = Date()
        var day = DayAvailability(date: date, timeBlocks: [
            TimeBlock(startTime: date, endTime: date.addingTimeInterval(3600), status: .busy)
        ])
        
        XCTAssertEqual(day.timeBlocks.count, 1)
        
        day.status = .free
        
        XCTAssertEqual(day.timeBlocks.count, 1)
        XCTAssertEqual(day.timeBlocks[0].status, .free)
        XCTAssertEqual(day.overallStatus, .free)
    }
    
    func test_statusSetter_createsCorrectBlocksForMorningOnly() {
        let date = Date()
        var day = DayAvailability(date: date)
        
        day.status = .morningOnly
        
        XCTAssertEqual(day.overallStatus, .morningOnly)
        // Should have 3 blocks: Busy(0-9), Free(9-12), Busy(12-24)
        XCTAssertEqual(day.timeBlocks.count, 3)
        XCTAssertEqual(day.timeBlocks[1].status, .free)
    }
    
    func test_overallStatus_detectsFreeForCoreActiveHours() {
        let date = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let activeStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: startOfDay)!
        let activeEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: startOfDay)!
        
        let blocks = [
            TimeBlock(startTime: startOfDay, endTime: activeStart, status: .busy),
            TimeBlock(startTime: activeStart, endTime: activeEnd, status: .free),
            TimeBlock(startTime: activeEnd, endTime: calendar.date(byAdding: .day, value: 1, to: startOfDay)!, status: .busy)
        ]
        
        let day = DayAvailability(date: date, timeBlocks: blocks)
        XCTAssertEqual(day.overallStatus, .free)
    }
    
    func test_overallStatus_detectsMixedForGapInActiveHours() {
        let date = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let activeStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: startOfDay)!
        let gapStart = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: startOfDay)!
        let gapEnd = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: startOfDay)!
        let activeEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: startOfDay)!
        
        let blocks = [
            TimeBlock(startTime: activeStart, endTime: gapStart, status: .free),
            TimeBlock(startTime: gapStart, endTime: gapEnd, status: .busy),
            TimeBlock(startTime: gapEnd, endTime: activeEnd, status: .free)
        ]
        
        let day = DayAvailability(date: date, timeBlocks: blocks)
        XCTAssertEqual(day.overallStatus, .mixed)
    }
    
    func test_overallStatus_detectsMorningOnly_forSmallWindowWithinRange() {
        let date = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let freeStart = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: startOfDay)!
        let freeEnd = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: startOfDay)!
        
        let blocks = [
            TimeBlock(startTime: freeStart, endTime: freeEnd, status: .free)
        ]
        
        let day = DayAvailability(date: date, timeBlocks: blocks)
        XCTAssertEqual(day.overallStatus, .morningOnly) // Falls within Morning (9-12)
    }

    func test_statusSetter_createsCorrectBlocksForAfternoonAndEvening() {
        let date = Date()
        var day = DayAvailability(date: date)
        
        day.status = .afternoonOnly
        XCTAssertEqual(day.overallStatus, .afternoonOnly)
        XCTAssertEqual(day.timeBlocks.filter { $0.status == .free }.count, 1)
        
        day.status = .eveningOnly
        XCTAssertEqual(day.overallStatus, .eveningOnly)
        XCTAssertEqual(day.timeBlocks.filter { $0.status == .free }.count, 1)
    }
}
