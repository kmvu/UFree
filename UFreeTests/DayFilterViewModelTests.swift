//
//  DayFilterViewModelTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 01/01/26.
//

import XCTest
@testable import UFree

@MainActor
final class DayFilterViewModelTests: XCTestCase {
    var viewModel: DayFilterViewModel!

    override func setUp() {
        super.setUp()
        viewModel = DayFilterViewModel()
    }

    func test_initialSelectedDay_isNil() {
        XCTAssertNil(viewModel.selectedDay)
    }

    func test_toggleDay_selectsDay() {
        let date = Date()
        viewModel.toggleDay(date)
        XCTAssertEqual(viewModel.selectedDay, date)
    }

    func test_toggleDay_deselectsDay() {
        let date = Date()
        viewModel.toggleDay(date)
        viewModel.toggleDay(date)
        XCTAssertNil(viewModel.selectedDay)
    }

    func test_toggleDay_switchesBetweenDays() {
        let date1 = Date()
        let date2 = Date().addingTimeInterval(86400) // Next day

        viewModel.toggleDay(date1)
        XCTAssertEqual(viewModel.selectedDay, date1)

        viewModel.toggleDay(date2)
        XCTAssertEqual(viewModel.selectedDay, date2)
    }

    func test_rapidToggle_same_day() {
        let date = Date()

        // Rapid toggles on same day
        viewModel.toggleDay(date)
        viewModel.toggleDay(date)
        viewModel.toggleDay(date)

        // Final state should be selected (odd number of toggles)
        XCTAssertEqual(viewModel.selectedDay, date)
    }

    func test_clearSelection() {
        let date = Date()
        viewModel.toggleDay(date)
        XCTAssertEqual(viewModel.selectedDay, date)

        viewModel.clearSelection()
        XCTAssertNil(viewModel.selectedDay)
    }

    func test_multipleSelectionChanges() {
        let date1 = Date()
        let date2 = Date().addingTimeInterval(86400)
        let date3 = Date().addingTimeInterval(172800)

        viewModel.toggleDay(date1)
        XCTAssertEqual(viewModel.selectedDay, date1)

        viewModel.toggleDay(date2)
        XCTAssertEqual(viewModel.selectedDay, date2)

        viewModel.toggleDay(date3)
        XCTAssertEqual(viewModel.selectedDay, date3)

        viewModel.clearSelection()
        XCTAssertNil(viewModel.selectedDay)
    }
}
