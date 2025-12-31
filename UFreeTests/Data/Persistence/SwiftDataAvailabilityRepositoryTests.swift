//
//  SwiftDataAvailabilityRepositoryTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 29/12/25.
//

import XCTest
import SwiftData
@testable import UFree

@MainActor
final class SwiftDataAvailabilityRepositoryTests: XCTestCase {
    
    // MARK: - Test Setup
    
    private var container: ModelContainer!
    private var sut: SwiftDataAvailabilityRepository!
    
    @MainActor
    override func setUp() {
        super.setUp()
        container = makeInMemoryContainer()
        sut = SwiftDataAvailabilityRepository(container: container)
    }
    
    override func tearDown() {
        sut = nil
        container = nil
        super.tearDown()
    }
    
    // MARK: - getMySchedule Tests
    
    @MainActor
    func test_getMySchedule_emptyDatabase_returnsGeneratedSevenDays() async throws {
        let schedule = try await sut.getMySchedule()
        assertScheduleDefaults(schedule)
        XCTAssertEqual(schedule.weeklyStatus.count, 7)
        schedule.weeklyStatus.forEach { XCTAssertEqual($0.status, .unknown) }
    }
    
    @MainActor
    func test_getMySchedule_withPersistedData_returnsCorrectStatuses() async throws {
        let testDay = makeDay(daysOffset: 0, status: .free)
        try await sut.updateMySchedule(for: testDay)
        
        let fetchedDay = try await sut.getMySchedule().status(for: testDay.date)
        assertDayMatches(fetchedDay, testDay)
    }
    
    @MainActor
    func test_getMySchedule_multipleRecords_returnsSortedByDate() async throws {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        try await sut.updateMySchedule(for: DayAvailability(date: tomorrow, status: .busy))
        try await sut.updateMySchedule(for: DayAvailability(date: today, status: .free))
        
        let schedule = try await sut.getMySchedule()
        XCTAssertGreaterThanOrEqual(schedule.weeklyStatus.count, 2)
        XCTAssertEqual(schedule.weeklyStatus[0].date, today)
        XCTAssertEqual(schedule.weeklyStatus[1].date, tomorrow)
    }
    
    // MARK: - updateMySchedule Tests
    
    @MainActor
    func test_updateMySchedule_newDay_insertsSuccessfully() async throws {
        let testDay = makeDay(daysOffset: 2, status: .free, note: "Dinner plans")
        try await sut.updateMySchedule(for: testDay)
        
        let fetchedDay = try await sut.getMySchedule().status(for: testDay.date)
        assertDayMatches(fetchedDay, testDay)
    }
    
    @MainActor
    func test_updateMySchedule_existingDay_updatesSuccessfully() async throws {
        var testDay = makeDay(daysOffset: 1, status: .free)
        try await sut.updateMySchedule(for: testDay)
        
        testDay.status = .busy
        testDay.note = "Meeting"
        try await sut.updateMySchedule(for: testDay)
        
        let fetchedDay = try await sut.getMySchedule().status(for: testDay.date)
        assertDayMatches(fetchedDay, testDay)
    }
    
    @MainActor
    func test_updateMySchedule_multipleUpdates_persistsLatestValue() async throws {
        let testDate = makeDate(daysOffset: 3)
        var testDay = DayAvailability(date: testDate, status: .unknown)
        
        for status in [AvailabilityStatus.free, .busy, .eveningOnly, .free] {
            testDay.status = status
            try await sut.updateMySchedule(for: testDay)
        }
        
        let fetchedDay = try await sut.getMySchedule().status(for: testDate)
        XCTAssertEqual(fetchedDay?.status, .free)
    }
    
    // MARK: - Persistence Tests
    
    @MainActor
    func test_persistence_survivesDatabaseReopen() async throws {
        let testDay = makeDay(daysOffset: 0, status: .eveningOnly, note: "Free after 6pm")
        try await sut.updateMySchedule(for: testDay)
        
        let newRepository = SwiftDataAvailabilityRepository(container: container)
        let fetchedDay = try await newRepository.getMySchedule().status(for: testDay.date)
        
        assertDayMatches(fetchedDay, testDay)
    }
    
    // MARK: - Date Normalization Tests
    
    @MainActor
    func test_dateNormalization_ignoresTimeComponent() async throws {
        let dateAtMidnight = Calendar.current.startOfDay(for: Date())
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 14
        components.minute = 30
        let dateWithTime = Calendar.current.date(from: components)!
        
        let testDay = DayAvailability(date: dateAtMidnight, status: .free)
        try await sut.updateMySchedule(for: testDay)
        
        let fetchedDay = try await sut.getMySchedule().status(for: dateWithTime)
        XCTAssertEqual(fetchedDay?.status, .free)
    }
    
    // MARK: - Note Handling Tests
    
    @MainActor
    func test_updateMySchedule_withNote_persistsNote() async throws {
        let testNote = "Coffee meeting at 10am"
        let testDay = makeDay(daysOffset: 1, status: .free, note: testNote)
        try await sut.updateMySchedule(for: testDay)
        
        let fetchedDay = try await sut.getMySchedule().status(for: testDay.date)
        XCTAssertEqual(fetchedDay?.note, testNote)
    }
    
    @MainActor
    func test_updateMySchedule_clearNote_removesNote() async throws {
        var testDay = makeDay(daysOffset: 2, status: .free, note: "Original note")
        try await sut.updateMySchedule(for: testDay)
        
        testDay.note = nil
        try await sut.updateMySchedule(for: testDay)
        
        let fetchedDay = try await sut.getMySchedule().status(for: testDay.date)
        XCTAssertNil(fetchedDay?.note)
    }
    
    // MARK: - getFriendsSchedules Tests
    
    @MainActor
    func test_getFriendsSchedules_returnsEmptyArray() async throws {
        let schedules = try await sut.getFriendsSchedules()
        XCTAssertEqual(schedules.count, 0)
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func makeInMemoryContainer() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: PersistentDayAvailability.self,
            configurations: config
        )
        return container
    }
    
    private func makeDate(daysOffset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: daysOffset, to: Date())!
    }
    
    private func makeDay(daysOffset: Int, status: AvailabilityStatus, note: String? = nil) -> DayAvailability {
        DayAvailability(date: makeDate(daysOffset: daysOffset), status: status, note: note)
    }
    
    private func assertScheduleDefaults(_ schedule: UserSchedule) {
        XCTAssertEqual(schedule.id, "local_user")
        XCTAssertEqual(schedule.name, "Me")
        XCTAssertNil(schedule.avatarURL)
    }
    
    private func assertDayMatches(_ fetchedDay: DayAvailability?, _ expectedDay: DayAvailability) {
        XCTAssertNotNil(fetchedDay)
        XCTAssertEqual(fetchedDay?.status, expectedDay.status)
        XCTAssertEqual(fetchedDay?.id, expectedDay.id)
        XCTAssertEqual(fetchedDay?.note, expectedDay.note)
    }
}
