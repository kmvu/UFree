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
    
    func test_initialExpansionState_isFalse() {
        XCTAssertFalse(viewModel.isExpanded)
    }

    func test_setStatus_updatesStatus_immediately() async {
        viewModel.toggleExpansion()
        viewModel.setStatus(.free)

        // Status should update immediately, not after delay
        XCTAssertEqual(viewModel.currentStatus, .free)
    }

    func test_setStatus_sets_any_status() async {
        viewModel.toggleExpansion()
        viewModel.setStatus(.morning)
        XCTAssertEqual(viewModel.currentStatus, .morning)
        
        // Wait for processing to complete
        try? await Task.sleep(nanoseconds: 350_000_000)
        
        viewModel.toggleExpansion() // Re-expand after previous selection closed it
        viewModel.setStatus(.afternoon)
        XCTAssertEqual(viewModel.currentStatus, .afternoon)
    }

    func test_toggleExpansion_updatesState() {
        XCTAssertFalse(viewModel.isExpanded)
        viewModel.toggleExpansion()
        XCTAssertTrue(viewModel.isExpanded)
        viewModel.toggleExpansion()
        XCTAssertFalse(viewModel.isExpanded)
    }

    func test_rapidTaps_ignored_while_processing() async {
        // First set
        viewModel.toggleExpansion()
        viewModel.setStatus(.free)
        XCTAssertTrue(viewModel.isProcessing)

        // Try to set while processing (should be ignored)
        viewModel.setStatus(.busy)
        viewModel.setStatus(.morning)

        // Status should be free (only first set counted)
        XCTAssertEqual(viewModel.currentStatus, .free)
        
        // Wait for processing to complete
        try? await Task.sleep(nanoseconds: 350_000_000)
        XCTAssertFalse(viewModel.isProcessing)
    }

    func test_processingState_betweenTaps() async {
        viewModel.toggleExpansion()
        viewModel.setStatus(.free)

        // Should be processing immediately after tap
        XCTAssertTrue(viewModel.isProcessing)

        // Wait for processing to complete (0.3s)
        try? await Task.sleep(nanoseconds: 350_000_000)

        XCTAssertFalse(viewModel.isProcessing)
    }
}
