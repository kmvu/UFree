//
//  AvailabilityTruthTests.swift
//  UFreeTests
//

import XCTest
@testable import UFree

final class AvailabilityTruthTests: XCTestCase {
    func test_fullDayFree_isAvailable() {
        let day = DayAvailability(date: Date(), status: .free)
        XCTAssertTrue(day.isAvailable)
    }

    func test_partialStatuses_areAvailable() {
        XCTAssertTrue(DayAvailability(date: Date(), status: .morningOnly).isAvailable)
        XCTAssertTrue(DayAvailability(date: Date(), status: .afternoonOnly).isAvailable)
        XCTAssertTrue(DayAvailability(date: Date(), status: .eveningOnly).isAvailable)
    }

    func test_busyAndUnknown_areNotAvailable() {
        XCTAssertFalse(DayAvailability(date: Date(), status: .busy).isAvailable)
        XCTAssertFalse(DayAvailability(date: Date(), status: .unknown).isAvailable)
    }

    func test_defaultInit_isUnknown() {
        let day = DayAvailability(date: Date())
        XCTAssertEqual(day.status, .unknown)
        XCTAssertTrue(day.timeBlocks.isEmpty)
    }
}
