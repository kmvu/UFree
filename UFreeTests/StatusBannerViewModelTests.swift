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
        trackForMemoryLeaks(viewModel)
    }

    override func tearDown() {
        viewModel = nil
        verifyNoMemoryLeaks()
        super.tearDown()
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

        XCTAssertEqual(viewModel.currentStatus, .free)
    }

    func test_setStatus_sets_any_status() {
        viewModel.toggleExpansion()
        viewModel.setStatus(.morning)
        XCTAssertEqual(viewModel.currentStatus, .morning)
        
        viewModel.toggleExpansion()
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
        viewModel.toggleExpansion()
        viewModel.setStatus(.free)
        
        XCTAssertFalse(viewModel.isProcessing)
    }

    func test_processingState_betweenTaps() {
        viewModel.toggleExpansion()
        viewModel.setStatus(.free)
        XCTAssertFalse(viewModel.isProcessing)
    }
}