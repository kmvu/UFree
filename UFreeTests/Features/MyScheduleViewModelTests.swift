//
//  MyScheduleViewModelTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 22/12/25.
//

import XCTest
import Foundation
@testable import UFree

@MainActor
final class MyScheduleViewModelTests: XCTestCase {
    
    private var updateUseCaseSpy: UpdateMyStatusUseCaseSpy!
    private var repositorySpy: AvailabilityRepositorySpy!
    private var sut: MyScheduleViewModel!
    
    override func setUp() async throws {
        try await super.setUp()
        updateUseCaseSpy = UpdateMyStatusUseCaseSpy()
        repositorySpy = AvailabilityRepositorySpy()
        sut = MyScheduleViewModel(updateUseCase: updateUseCaseSpy, repository: repositorySpy)
    }
    
    func test_setupInitialWeek_generatesSevenDays() {
        XCTAssertEqual(sut.weeklySchedule.count, 7)
        XCTAssertEqual(sut.weeklySchedule.first?.status, .busy)
    }
    
    func test_updateStatus_callsUseCase() async {
        let day = sut.weeklySchedule[0]
        var updatedDay = day
        updatedDay.status = .free
        
        sut.updateStatus(for: updatedDay)
        
        // Use Task to wait for the async operation in ViewModel
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        
        XCTAssertEqual(updateUseCaseSpy.executeCallCount, 1)
        XCTAssertEqual(updateUseCaseSpy.executedDay?.status, .free)
        XCTAssertEqual(sut.weeklySchedule[0].status, .free)
    }
    
    func test_toggleStatus_cyclesCorrectly() async {
        let day = sut.weeklySchedule[0]
        XCTAssertEqual(day.status, .busy)
        
        // Busy -> Free
        sut.toggleStatus(for: day)
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(sut.weeklySchedule[0].status, .free)
        
        // Free -> MorningOnly
        sut.toggleStatus(for: sut.weeklySchedule[0])
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(sut.weeklySchedule[0].status, .morningOnly)
        
        // MorningOnly -> AfternoonOnly
        sut.toggleStatus(for: sut.weeklySchedule[0])
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(sut.weeklySchedule[0].status, .afternoonOnly)
        
        // AfternoonOnly -> EveningOnly
        sut.toggleStatus(for: sut.weeklySchedule[0])
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(sut.weeklySchedule[0].status, .eveningOnly)
        
        // EveningOnly -> Busy
        sut.toggleStatus(for: sut.weeklySchedule[0])
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(sut.weeklySchedule[0].status, .busy)
    }
    
    func test_toggleStatus_fromMixed_cyclesToBusy() async {
        // Create a mixed day
        let date = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        // 11 AM - 1 PM is "Mixed" because it spans Morning (9-12) and Afternoon (12-17)
        let blocks = [
            TimeBlock(startTime: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: startOfDay)!,
                      endTime: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: startOfDay)!,
                      status: .free)
        ]
        let mixedDay = DayAvailability(date: date, timeBlocks: blocks)
        XCTAssertEqual(mixedDay.status, .mixed)
        
        sut.weeklySchedule[0] = mixedDay
        
        sut.toggleStatus(for: mixedDay)
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(sut.weeklySchedule[0].status, .busy)
    }
    
    // MARK: - Spies
    
    private final class UpdateMyStatusUseCaseSpy: UpdateMyStatusUseCaseProtocol {
        var executeCallCount = 0
        var executedDay: DayAvailability?
        
        func execute(day: DayAvailability) async throws {
            executeCallCount += 1
            executedDay = day
        }
    }
    
    private final class AvailabilityRepositorySpy: AvailabilityRepository {
        func getSchedules(for userIds: [String]) async throws -> [UserSchedule] { return [] }
        func updateMySchedule(for day: DayAvailability) async throws {}
        func getMySchedule() async throws -> UserSchedule {
            return UserSchedule(id: "test", name: "Test", weeklyStatus: [])
        }
    }
}
