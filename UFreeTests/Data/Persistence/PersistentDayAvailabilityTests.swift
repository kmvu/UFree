//
//  PersistentDayAvailabilityTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 29/12/25.
//

import XCTest
@testable import UFree

final class PersistentDayAvailabilityTests: XCTestCase {

    // MARK: - Initialization Tests

    func test_init_setsAllProperties() {
        let id = UUID()
        let date = Date()
        let note = "Test note"
        
        let sut = PersistentDayAvailability(
            id: id,
            date: date,
            note: note
        )
        
        assertPersistentDay(sut, matchesId: id, date: date, note: note)
    }

    func test_init_withoutNote_setsNoteToNil() {
        let sut = makePersistentDay(note: nil)
        XCTAssertNil(sut.note)
    }

    // MARK: - Domain Conversion Tests

    func test_toDomain_convertsFromPersistentModel() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let date = calendar.date(bySettingHour: 2, minute: 0, second: 0, of: startOfDay)! // 2 AM to ensure outside quick-fill windows
        let id = UUID()
        let persistent = makePersistentDay(id: id, date: date, note: "Dinner")
        let blockId = UUID()
        let block = PersistentTimeBlock(id: blockId, startTime: date, endTime: date.addingTimeInterval(3600), statusValue: AvailabilityStatus.free.rawValue)
        persistent.persistentTimeBlocks = [block]
        
        let domain = persistent.toDomain()
        
        assertDomainDay(domain, matchesId: id, date: date, status: .mixed, note: "Dinner")
        XCTAssertEqual(domain.timeBlocks.count, 1)
        XCTAssertEqual(domain.timeBlocks[0].id, blockId)
    }

    // MARK: - Persistence Conversion Tests

    func test_toPersistent_convertsFromDomain() {
        let domain = makeDomainDay(status: .busy, note: "Meeting")
        
        let persistent = domain.toPersistent()
        
        assertPersistentDay(persistent, note: "Meeting")
        XCTAssertEqual(persistent.persistentTimeBlocks.count, 1)
        XCTAssertEqual(persistent.persistentTimeBlocks[0].statusValue, AvailabilityStatus.busy.rawValue)
    }

    // MARK: - Round-trip Conversion Tests

    func test_roundTripConversion_preservesAllData() {
        let now = Date()
        let block1 = TimeBlock(startTime: now, endTime: now.addingTimeInterval(3600), status: .free)
        let block2 = TimeBlock(startTime: now.addingTimeInterval(3600), endTime: now.addingTimeInterval(7200), status: .busy)
        let original = DayAvailability(id: UUID(), date: now, timeBlocks: [block1, block2], note: "Multi block")
        
        let persistent = original.toPersistent()
        let restored = persistent.toDomain()
        
        assertDomainDay(restored, matchesId: original.id, date: original.date, note: original.note)
        XCTAssertEqual(restored.timeBlocks.count, 2)
        XCTAssertEqual(restored.timeBlocks[0].status, .free)
        XCTAssertEqual(restored.timeBlocks[1].status, .busy)
    }

    // MARK: - Helpers
    
    private func makePersistentDay(
        id: UUID = UUID(),
        date: Date = Date(),
        note: String? = nil
    ) -> PersistentDayAvailability {
        PersistentDayAvailability(
            id: id,
            date: date,
            note: note
        )
    }
    
    private func makeDomainDay(
        id: UUID = UUID(),
        date: Date = Date(),
        status: AvailabilityStatus = .busy,
        note: String? = nil
    ) -> DayAvailability {
        DayAvailability(id: id, date: date, status: status, note: note)
    }
    
    private func assertPersistentDay(
        _ persistent: PersistentDayAvailability,
        matchesId id: UUID? = nil,
        date: Date? = nil,
        note: String? = nil
    ) {
        if let id = id {
            XCTAssertEqual(persistent.id, id)
        }
        if let date = date {
            XCTAssertEqual(persistent.date, date)
        }
        if let note = note {
            XCTAssertEqual(persistent.note, note)
        }
    }
    
    private func assertDomainDay(
        _ domain: DayAvailability,
        matchesId id: UUID? = nil,
        date: Date? = nil,
        status: AvailabilityStatus? = nil,
        note: String? = nil
    ) {
        if let id = id {
            XCTAssertEqual(domain.id, id)
        }
        if let date = date {
            XCTAssertEqual(domain.date, date)
        }
        if let status = status {
            XCTAssertEqual(domain.status, status)
        }
        if let note = note {
            XCTAssertEqual(domain.note, note)
        }
    }
}

