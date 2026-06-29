//
//  CompositeAvailabilityRepositoryTests.swift
//  UFreeTests
//
//  Created by Cline on 06/28/26.
//

import XCTest
@testable import UFree

final class CompositeAvailabilityRepositoryTests: XCTestCase {
    private var localSpy: AvailabilityRepositorySpy!
    private var remoteSpy: AvailabilityRepositorySpy!
    private var sut: CompositeAvailabilityRepository!
    
    override func setUp() {
        super.setUp()
        localSpy = AvailabilityRepositorySpy()
        remoteSpy = AvailabilityRepositorySpy()
        sut = CompositeAvailabilityRepository(local: localSpy, remote: remoteSpy)
    }
    
    func test_updateMySchedule_writesToLocalImmediately_andRemoteInBackground() async throws {
        let day = DayAvailability(date: Date(), status: .free)
        
        try await sut.updateMySchedule(for: day)
        
        // Local is written immediately
        XCTAssertEqual(localSpy.updateCallCount, 1)
        XCTAssertEqual(localSpy.lastUpdatedDay?.status, .free)
        
        // Remote write is fire-and-forget; yield to allow task to start
        await Task.yield()
        
        // Ensure remote spy eventually gets the update
        let startDate = Date()
        while remoteSpy.updateCallCount == 0 && Date().timeIntervalSince(startDate) < 1.0 {
            await Task.yield()
        }
        
        XCTAssertEqual(remoteSpy.updateCallCount, 1)
        XCTAssertEqual(remoteSpy.lastUpdatedDay?.status, .free)
    }
    
    func test_getMySchedule_returnsLocalImmediately_andSyncsRemoteBackToLocal() async throws {
        let remoteDay = DayAvailability(date: Date(), status: .busy)
        let remoteSchedule = UserSchedule(id: "1", name: "R", weeklyStatus: [remoteDay])
        remoteSpy.scheduleToReturn = remoteSchedule
        
        let localSchedule = UserSchedule(id: "1", name: "L", weeklyStatus: [])
        localSpy.scheduleToReturn = localSchedule
        
        // Act
        let returnedSchedule = try await sut.getMySchedule()
        
        // Local schedule should be returned immediately
        XCTAssertEqual(returnedSchedule.name, localSchedule.name)
        XCTAssertEqual(localSpy.getScheduleCallCount, 1)
        // Note: We don't assert remoteSpy.getScheduleCallCount == 0 here because
        // the background Task may have already started — this is non-deterministic
        // in Swift's concurrency model.
        
        // Wait for background task to fetch remote and update local
        let startDate = Date()
        while remoteSpy.getScheduleCallCount == 0 && Date().timeIntervalSince(startDate) < 5.0 {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        XCTAssertEqual(remoteSpy.getScheduleCallCount, 1)
        XCTAssertEqual(localSpy.updateCallCount, 1) // Background sync updated local with remote day
        XCTAssertEqual(localSpy.lastUpdatedDay?.status, .busy)
    }
    
    func test_getMySchedule_doesNotSyncUnknownRemoteDaysToLocal() async throws {
        let unknownDay = DayAvailability(date: Date(), status: .unknown)
        let remoteSchedule = UserSchedule(id: "1", name: "R", weeklyStatus: [unknownDay])
        remoteSpy.scheduleToReturn = remoteSchedule
        
        _ = try await sut.getMySchedule()
        
        let startDate = Date()
        while remoteSpy.getScheduleCallCount == 0 && Date().timeIntervalSince(startDate) < 1.0 {
            await Task.yield()
        }
        
        // Wait a bit to ensure no local update happens
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        // Should not update local with unknown day
        XCTAssertEqual(localSpy.updateCallCount, 0)
    }
    
    // MARK: - Spy
    
    private final class AvailabilityRepositorySpy: AvailabilityRepository {
        var updateCallCount = 0
        var getScheduleCallCount = 0
        var lastUpdatedDay: DayAvailability?
        var scheduleToReturn: UserSchedule = UserSchedule(id: "test", name: "Test", weeklyStatus: [])
        
        func updateMySchedule(for day: DayAvailability) async throws {
            updateCallCount += 1
            lastUpdatedDay = day
        }
        
        func getMySchedule() async throws -> UserSchedule {
            getScheduleCallCount += 1
            return scheduleToReturn
        }
        
        func getSchedules(for userIds: [String]) async throws -> [UserSchedule] {
            return []
        }
    }
}