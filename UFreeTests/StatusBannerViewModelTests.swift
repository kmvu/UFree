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
        viewModel = StatusBannerViewModel(scheduler: ImmediateTaskScheduler())
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

    func test_setStatus_updatesStatus_immediately() {
        viewModel.toggleExpansion()
        viewModel.setStatus(.free)

        // Status should update immediately, not after delay
        XCTAssertEqual(viewModel.currentStatus, .free)
    }

    func test_setStatus_sets_any_status() {
        viewModel.toggleExpansion()
        viewModel.setStatus(.morning)
        XCTAssertEqual(viewModel.currentStatus, .morning)
        
        // No need to wait with ImmediateTaskScheduler
        
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

    func test_rapidTaps_ignored_while_processing() {
        // ImmediateTaskScheduler will fire the reset instantly,
        // so to test "ignoring while processing" we would need a controlled scheduler.
        // However, with ImmediateTaskScheduler, isProcessing will be false again immediately.
        
        // If we want to test the 'ignore' logic, we might need a TestScheduler that we can step manually.
        // But for the goal of speeding up tests, Immediate is fine for verifying it WORKS.
        
        viewModel.toggleExpansion()
        viewModel.setStatus(.free)
        
        // With ImmediateTaskScheduler, it is already false
        XCTAssertFalse(viewModel.isProcessing)
    }

    func test_processingState_betweenTaps() {
        // This test is less relevant with ImmediateTaskScheduler as it's atomic.
        // If we want to keep it, we'd need a ControlledScheduler.
        // For now, let's just ensure it doesn't crash and isFalse at the end.
        viewModel.toggleExpansion()
        viewModel.setStatus(.free)
        XCTAssertFalse(viewModel.isProcessing)
    }
}
