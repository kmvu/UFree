//
//  StatusBannerViewModelTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 01/01/26.
//

import XCTest
@testable import UFree

@MainActor
final class StatusBannerViewModelTests: XCTestCase {
    var viewModel: StatusBannerViewModel!

    override func setUp() {
        super.setUp()
        viewModel = StatusBannerViewModel()
    }

    func test_initialStatus_isCheckSchedule() {
        XCTAssertEqual(viewModel.currentStatus, .checkSchedule)
    }

    func test_initialProcessingState_isFalse() {
        XCTAssertFalse(viewModel.isProcessing)
    }

    func test_cycleStatus_updatesStatus_immediately() async {
        viewModel.cycleStatus()

        // Status should update immediately, not after delay
        let status = viewModel.currentStatus
        XCTAssertEqual(status, .free)
    }

    func test_cycleStatus_cycles_checkSchedule_to_free() async {
        viewModel.currentStatus = .checkSchedule
        viewModel.cycleStatus()

        XCTAssertEqual(viewModel.currentStatus, .free)
    }

    func test_cycleStatus_cycles_free_to_busy() async {
        viewModel.currentStatus = .free
        viewModel.cycleStatus()

        XCTAssertEqual(viewModel.currentStatus, .busy)
    }

    func test_cycleStatus_cycles_busy_to_free() async {
        viewModel.currentStatus = .busy
        viewModel.cycleStatus()

        XCTAssertEqual(viewModel.currentStatus, .free)
    }

    func test_rapidTaps_ignored_while_processing() async {
        // First tap
        viewModel.cycleStatus()
        XCTAssertTrue(viewModel.isProcessing)

        // Try to tap while processing (should be ignored)
        viewModel.cycleStatus()
        viewModel.cycleStatus()
        viewModel.cycleStatus()

        // Status should be free (only first tap counted)
        XCTAssertEqual(viewModel.currentStatus, .free)
        
        // Wait for processing to complete
        try? await Task.sleep(nanoseconds: 350_000_000)
        XCTAssertFalse(viewModel.isProcessing)
    }

    func test_processingState_betweenTaps() async {
        viewModel.cycleStatus()

        // Should be processing immediately after tap
        XCTAssertTrue(viewModel.isProcessing)

        // Wait for processing to complete (0.3s)
        try? await Task.sleep(nanoseconds: 350_000_000)

        XCTAssertFalse(viewModel.isProcessing)
    }

    func test_multipleSequentialTaps_after_processing() async {
        // First tap: checkSchedule → free (immediate)
        viewModel.cycleStatus()
        XCTAssertEqual(viewModel.currentStatus, .free)

        // Wait for processing to complete
        try? await Task.sleep(nanoseconds: 350_000_000)

        // Second tap: free → busy
        viewModel.cycleStatus()
        XCTAssertEqual(viewModel.currentStatus, .busy)
        
        // Wait for processing to complete
        try? await Task.sleep(nanoseconds: 350_000_000)

        // Third tap: busy → free (cycles between free and busy)
        viewModel.cycleStatus()
        XCTAssertEqual(viewModel.currentStatus, .free)
    }
}
