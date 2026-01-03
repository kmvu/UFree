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
    
    func test_init_setsAllDaysToBusyStatus() {
        let busyDays = viewModel.weeklySchedule.filter { $0.status == .busy }
        
        XCTAssertEqual(busyDays.count, 7)
    }
    
    func test_init_isLoadingIsFalse() {
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func test_init_errorMessageIsNil() {
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Load Schedule
    
    func test_loadSchedule_completesAndSetsIsLoadingFalse() async {
        XCTAssertFalse(viewModel.isLoading)
        
        await viewModel.loadSchedule()
        
        // After loadSchedule completes, isLoading should be false (set by defer)
        XCTAssertFalse(viewModel.isLoading)
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
    
    func test_toggleStatus_cyclesFromBusyToFree() {
        let originalDay = viewModel.weeklySchedule[0]
        
        viewModel.toggleStatus(for: originalDay)
        
        XCTAssertEqual(viewModel.weeklySchedule[0].status, .free)
    }
    
    func test_toggleStatus_cyclesFromFreeToMorningOnly() {
        let day = viewModel.weeklySchedule[0]
        viewModel.toggleStatus(for: day)
        
        // Now it's free, toggle again
        viewModel.toggleStatus(for: viewModel.weeklySchedule[0])
        
        XCTAssertEqual(viewModel.weeklySchedule[0].status, .morningOnly)
    }
    
    func test_toggleStatus_cyclesFromMorningOnlyToAfternoonOnly() {
        let day = viewModel.weeklySchedule[0]
        viewModel.toggleStatus(for: day)
        viewModel.toggleStatus(for: viewModel.weeklySchedule[0])
        
        // Now it's morningOnly, toggle again
        viewModel.toggleStatus(for: viewModel.weeklySchedule[0])
        
        XCTAssertEqual(viewModel.weeklySchedule[0].status, .afternoonOnly)
    }
    
    func test_toggleStatus_cyclesFromAfternoonOnlyToEveningOnly() {
        let day = viewModel.weeklySchedule[0]
        viewModel.toggleStatus(for: day)
        viewModel.toggleStatus(for: viewModel.weeklySchedule[0])
        viewModel.toggleStatus(for: viewModel.weeklySchedule[0])
        
        // Now it's afternoonOnly, toggle again
        viewModel.toggleStatus(for: viewModel.weeklySchedule[0])
        
        XCTAssertEqual(viewModel.weeklySchedule[0].status, .eveningOnly)
    }
}
