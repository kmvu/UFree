//
//  CompositeAvailabilityRepositoryTests.swift
//  UFreeTests
//
//  Created by Cline on 06/28/26.
//

import XCTest
@testable import UFree

@MainActor
final class CompositeAvailabilityRepositoryTests: XCTestCase {
    private var localSpy: AvailabilityRepositorySpy!
    private var remoteSpy: AvailabilityRepositorySpy!
    private var sut: CompositeAvailabilityRepository!
    
    override func setUp() {
        super.setUp()
        localSpy = AvailabilityRepositorySpy()
        remoteSpy = AvailabilityRepositorySpy()
        sut = CompositeAvailabilityRepository(
            local: localSpy,
            remote: remoteSpy,
            observesLifecycle: false
        )
    }
    
    func test_updateMySchedule_writesToLocalImmediately_andRemoteInBackground() async throws {
        let day = DayAvailability(date: Date(), status: .free)
        
        try await sut.updateMySchedule(for: day)
        
        // Local is written immediately
        XCTAssertEqual(localSpy.updateCallCount, 1)
        XCTAssertEqual(localSpy.lastUpdatedDay?.status, .free)
        
        await waitUntil("remote background sync") {
            remoteSpy.updateCallCount == 1
        }
        
        XCTAssertEqual(remoteSpy.lastUpdatedDay?.status, .free)
    }
    
    func test_getMySchedule_returnsLocalImmediately_andSyncsRemoteBackToLocal() async throws {
        let remoteDay = DayAvailability(date: Date(), status: .busy)
        let remoteSchedule = UserSchedule(id: "1", name: "R", weeklyStatus: [remoteDay])
        remoteSpy.scheduleToReturn = remoteSchedule
        
        let localSchedule = UserSchedule(id: "1", name: "L", weeklyStatus: [])
        localSpy.scheduleToReturn = localSchedule
        
        let returnedSchedule = try await sut.getMySchedule()
        
        // Local schedule should be returned immediately
        XCTAssertEqual(returnedSchedule.name, localSchedule.name)
        XCTAssertEqual(localSpy.getScheduleCallCount, 1)
        
        await waitUntil("remote fetch during background refresh") {
            remoteSpy.getScheduleCallCount == 1
        }
        
        await waitUntil("local write-back from remote refresh") {
            localSpy.updateCallCount == 1
        }
        
        XCTAssertEqual(localSpy.lastUpdatedDay?.status, .busy)
    }
    
    func test_getMySchedule_doesNotSyncUnknownRemoteDaysToLocal() async throws {
        let unknownDay = DayAvailability(date: Date(), status: .unknown)
        let remoteSchedule = UserSchedule(id: "1", name: "R", weeklyStatus: [unknownDay])
        remoteSpy.scheduleToReturn = remoteSchedule
        
        _ = try await sut.getMySchedule()
        
        await waitUntil("remote fetch during background refresh") {
            remoteSpy.getScheduleCallCount == 1
        }
        
        await drainPendingTasks()
        
        // Should not update local with unknown day
        XCTAssertEqual(localSpy.updateCallCount, 0)
    }

    func test_updateMySchedule_keepsPending_andSkipsStaleRemoteOverwrite() async throws {
        let day = DayAvailability(date: Date(), status: .free, updatedAt: Date())
        remoteSpy.shouldFailUpdate = true

        try await sut.updateMySchedule(for: day)

        await waitUntil("remote update attempted") {
            remoteSpy.updateCallCount == 1
        }
        await drainPendingTasks()

        // Pending local edit must not be bounced by older cloud data
        let staleRemote = DayAvailability(
            date: day.date,
            status: .busy,
            updatedAt: Date().addingTimeInterval(-3600)
        )
        remoteSpy.scheduleToReturn = UserSchedule(id: "1", name: "R", weeklyStatus: [staleRemote])
        remoteSpy.shouldFailUpdate = false
        localSpy.updateCallCount = 0

        _ = try await sut.getMySchedule()

        await waitUntil("remote fetch during background refresh") {
            remoteSpy.getScheduleCallCount >= 1
        }
        await drainPendingTasks()

        XCTAssertEqual(localSpy.updateCallCount, 0, "Pending/local-newer day must not be overwritten")
    }

    func test_getMySchedule_skipsRemoteWhenLocalUpdatedAtIsNewer() async throws {
        let now = Date()
        let localDay = DayAvailability(date: now, status: .free, updatedAt: now)
        localSpy.scheduleToReturn = UserSchedule(id: "1", name: "L", weeklyStatus: [localDay])

        let olderRemote = DayAvailability(
            date: now,
            status: .busy,
            updatedAt: now.addingTimeInterval(-120)
        )
        remoteSpy.scheduleToReturn = UserSchedule(id: "1", name: "R", weeklyStatus: [olderRemote])

        _ = try await sut.getMySchedule()

        await waitUntil("remote fetch during background refresh") {
            remoteSpy.getScheduleCallCount == 1
        }
        await drainPendingTasks()

        XCTAssertEqual(localSpy.updateCallCount, 0)
    }
    
    // MARK: - Spy
    
    private final class AvailabilityRepositorySpy: AvailabilityRepository {
        var updateCallCount = 0
        var getScheduleCallCount = 0
        var lastUpdatedDay: DayAvailability?
        var scheduleToReturn: UserSchedule = UserSchedule(id: "test", name: "Test", weeklyStatus: [])
        var shouldFailUpdate = false

        nonisolated deinit {}
        
        func updateMySchedule(for day: DayAvailability) async throws {
            updateCallCount += 1
            lastUpdatedDay = day
            if shouldFailUpdate {
                throw NSError(domain: "test", code: 1)
            }
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
