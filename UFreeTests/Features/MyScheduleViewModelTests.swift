//
//  MyScheduleViewModelTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 31/12/25.
//

import XCTest
import Combine
@testable import UFree

@MainActor
final class MyScheduleViewModelTests: XCTestCase {
    
    private var viewModel: MyScheduleViewModel!
    private var repository: MockAvailabilityRepository!
    
    override func setUp() async throws {
        try await super.setUp()
        repository = MockAvailabilityRepository()
        let useCase = UpdateMyStatusUseCase(repository: repository)
        viewModel = MyScheduleViewModel(updateUseCase: useCase, repository: repository)
    }
    
    // MARK: - Initialization
    
    func test_init_createsWeeklyScheduleWith7Days() {
        XCTAssertEqual(viewModel.weeklySchedule.count, 7)
    }
    
    func test_init_setsAllDaysToUnknownStatus() {
        let unknownDays = viewModel.weeklySchedule.filter { $0.status == .unknown }
        
        XCTAssertEqual(unknownDays.count, 7)
    }
    
    func test_init_isLoadingIsFalse() {
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func test_init_errorMessageIsNil() {
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Load Schedule
    
    func test_loadSchedule_setsIsLoadingTrue() async {
        let loadingExpectation = expectation(description: "isLoading should be true")
        let task = Task {
            for await _ in viewModel.$isLoading.values {
                if viewModel.isLoading {
                    loadingExpectation.fulfill()
                    break
                }
            }
        }
        
        await viewModel.loadSchedule()
        
        await fulfillment(of: [loadingExpectation], timeout: 1.0)
        task.cancel()
    }
    
    func test_loadSchedule_clearsErrorMessage() async {
        viewModel.errorMessage = "Previous error"
        
        await viewModel.loadSchedule()
        
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func test_loadSchedule_mergesRepositorySchedule() async throws {
        await viewModel.loadSchedule()
        
        let schedule = try await repository.getMySchedule()
        
        XCTAssertEqual(viewModel.weeklySchedule.count, schedule.weeklyStatus.count)
    }
    
    // MARK: - Toggle Status
    
    func test_toggleStatus_cyclesFromUnknownToFree() {
        let originalDay = viewModel.weeklySchedule[0]
        
        viewModel.toggleStatus(for: originalDay)
        
        XCTAssertEqual(viewModel.weeklySchedule[0].status, .free)
    }
    
    func test_toggleStatus_cyclesFromFreeTobusy() {
        let day = viewModel.weeklySchedule[0]
        viewModel.toggleStatus(for: day)
        
        // Now it's free, toggle again
        viewModel.toggleStatus(for: viewModel.weeklySchedule[0])
        
        XCTAssertEqual(viewModel.weeklySchedule[0].status, .busy)
    }
    
    func test_toggleStatus_cyclesFromBusyToEveningOnly() {
        let day = viewModel.weeklySchedule[0]
        viewModel.toggleStatus(for: day)
        viewModel.toggleStatus(for: viewModel.weeklySchedule[0])
        
        // Now it's busy, toggle again
        viewModel.toggleStatus(for: viewModel.weeklySchedule[0])
        
        XCTAssertEqual(viewModel.weeklySchedule[0].status, .eveningOnly)
    }
    
    func test_toggleStatus_cyclesFromEveningOnlyBackToFree() {
        let day = viewModel.weeklySchedule[0]
        viewModel.toggleStatus(for: day)
        viewModel.toggleStatus(for: viewModel.weeklySchedule[0])
        viewModel.toggleStatus(for: viewModel.weeklySchedule[0])
        
        // Now it's eveningOnly, toggle again
        viewModel.toggleStatus(for: viewModel.weeklySchedule[0])
        
        XCTAssertEqual(viewModel.weeklySchedule[0].status, .free)
    }
}
