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
            statusValue: AvailabilityStatus.free.rawValue,
            note: note
        )
        
        assertPersistentDay(sut, matchesId: id, date: date, statusValue: 1, note: note)
    }

    func test_init_withoutNote_setsNoteToNil() {
        let sut = makePersistentDay(statusValue: 0, note: nil)
        XCTAssertNil(sut.note)
    }

    // MARK: - Domain Conversion Tests

    func test_toDomain_convertsToPersistentModel() {
        let id = UUID()
        let date = Date()
        let persistent = makePersistentDay(id: id, date: date, status: .free, note: "Dinner")
        
        let domain = persistent.toDomain()
        
        assertDomainDay(domain, matchesId: id, date: date, status: .free, note: "Dinner")
    }

    func test_toDomain_withBusyStatus_convertsCorrectly() {
        let persistent = makePersistentDay(status: .busy)
        XCTAssertEqual(persistent.toDomain().status, .busy)
    }

    func test_toDomain_withInvalidStatusValue_defaultsToBusy() {
        let persistent = PersistentDayAvailability(id: UUID(), date: Date(), statusValue: 999)
        XCTAssertEqual(persistent.toDomain().status, .busy)
    }

    // MARK: - Persistence Conversion Tests

    func test_toPersistent_convertsFromDomain() {
        let domain = makeDomainDay(status: .busy, note: "Meeting")
        
        let persistent = domain.toPersistent()
        
        assertPersistentDay(persistent, status: .busy, note: "Meeting")
    }

    func test_toPersistent_withoutNote_convertsCorrectly() {
        let domain = makeDomainDay(status: .eveningOnly, note: nil)
        let persistent = domain.toPersistent()
        
        XCTAssertEqual(persistent.statusValue, AvailabilityStatus.eveningOnly.rawValue)
        XCTAssertNil(persistent.note)
    }

    // MARK: - Round-trip Conversion Tests

    func test_roundTripConversion_preservesAllData() {
        let original = makeDomainDay(status: .free, note: "Lunch available")
        
        let persistent = original.toPersistent()
        let restored = persistent.toDomain()
        
        assertDomainDay(restored, matchesId: original.id, date: original.date, 
                       status: original.status, note: original.note)
    }

    func test_roundTripConversion_allStatusValues() {
        for status in [AvailabilityStatus.busy, .free, .morningOnly, .afternoonOnly, .eveningOnly] {
            let original = makeDomainDay(status: status)
            let restored = original.toPersistent().toDomain()
            XCTAssertEqual(restored.status, status, "Status \(status) not preserved")
        }
    }
    
    // MARK: - Helpers
    
    private func makePersistentDay(
        id: UUID = UUID(),
        date: Date = Date(),
        status: AvailabilityStatus = .busy,
        statusValue: Int? = nil,
        note: String? = nil
    ) -> PersistentDayAvailability {
        PersistentDayAvailability(
            id: id,
            date: date,
            statusValue: statusValue ?? status.rawValue,
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
        statusValue: Int? = nil,
        status: AvailabilityStatus? = nil,
        note: String? = nil
    ) {
        if let id = id {
            XCTAssertEqual(persistent.id, id)
        }
        if let date = date {
            XCTAssertEqual(persistent.date, date)
        }
        if let statusValue = statusValue {
            XCTAssertEqual(persistent.statusValue, statusValue)
        } else if let status = status {
            XCTAssertEqual(persistent.statusValue, status.rawValue)
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
