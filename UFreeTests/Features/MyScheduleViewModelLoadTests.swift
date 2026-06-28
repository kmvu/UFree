//
//  MyScheduleViewModelLoadTests.swift
//  UFreeTests
//
//  Created by Cline on 06/28/26.
//

import XCTest
@testable import UFree

@MainActor
final class MyScheduleViewModelLoadTests: XCTestCase {
    
    private var sut: MyScheduleViewModel!
    private var mockUseCase: UpdateMyStatusUseCaseSpy!
    private var mockRepo: AvailabilityRepositorySpy!
    
    override func setUp() async throws {
        try await super.setUp()
        mockUseCase = UpdateMyStatusUseCaseSpy()
        mockRepo = AvailabilityRepositorySpy()
        sut = MyScheduleViewModel(updateUseCase: mockUseCase, repository: mockRepo)
    }
    
    func test_loadSchedule_success_mergesWithGeneratedWeek() async {
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let remoteDay = DayAvailability(date: tomorrow, status: .free)
        let remoteSchedule = UserSchedule(id: "1", name: "Me", weeklyStatus: [remoteDay])
        
        mockRepo.scheduleToReturn = remoteSchedule
        
        await sut.loadSchedule()
        
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        
        let mergedTomorrow = sut.weeklySchedule.first(where: { Calendar.current.isDate($0.date, inSameDayAs: tomorrow) })
        XCTAssertEqual(mergedTomorrow?.status, .free)
    }
    
    func test_loadSchedule_handlesStandardError() async {
        let expectedError = NSError(domain: "TestDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network failed"])
        mockRepo.errorToThrow = expectedError
        
        await sut.loadSchedule()
        
        XCTAssertFalse(sut.isLoading)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.errorMessage!.contains("Network failed"))
    }
    
    func test_loadSchedule_handlesFirestoreQuotaError() async {
        let expectedError = NSError(domain: "FirestoreErrorDomain", code: 8, userInfo: [NSLocalizedDescriptionKey: "Quota exceeded"])
        mockRepo.errorToThrow = expectedError
        
        await sut.loadSchedule()
        
        XCTAssertFalse(sut.isLoading)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.errorMessage!.contains("Quota exhausted"))
    }
    
    // MARK: - Spies
    
    private final class UpdateMyStatusUseCaseSpy: UpdateMyStatusUseCaseProtocol {
        func execute(day: DayAvailability) async throws {}
    }
    
    private final class AvailabilityRepositorySpy: AvailabilityRepository {
        var scheduleToReturn: UserSchedule = UserSchedule(id: "test", name: "Test", weeklyStatus: [])
        var errorToThrow: Error?
        
        func updateMySchedule(for day: DayAvailability) async throws {}
        
        func getMySchedule() async throws -> UserSchedule {
            if let error = errorToThrow {
                throw error
            }
            return scheduleToReturn
        }
        
        func getSchedules(for userIds: [String]) async throws -> [UserSchedule] { return [] }
    }
}