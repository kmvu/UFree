//
//  UserScheduleTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 22/12/25.
//

import XCTest
import Foundation
@testable import UFree

final class UserScheduleTests: XCTestCase {
    
    private let calendar = Calendar.current
    
    // MARK: - Initialization Tests
    
    func test_init_withAllParameters_createsScheduleCorrectly() {
        let id = "user_123"
        let name = "John Doe"
        let avatarURL = URL(string: "https://example.com/avatar.jpg")
        let weeklyStatus = [
            DayAvailability(date: Date(), status: .free),
            DayAvailability(date: Date(), status: .busy)
        ]
        
        let schedule = UserSchedule(id: id, name: name, avatarURL: avatarURL, weeklyStatus: weeklyStatus)
        
        XCTAssertEqual(schedule.id, id)
        XCTAssertEqual(schedule.name, name)
        XCTAssertEqual(schedule.avatarURL, avatarURL)
        XCTAssertEqual(schedule.weeklyStatus.count, 2)
    }
    
    func test_init_withoutAvatarURL_defaultsToNil() {
        let schedule = UserSchedule(id: "user_123", name: "John Doe", weeklyStatus: [])
        XCTAssertNil(schedule.avatarURL)
    }
    
    // MARK: - Date Lookup Tests
    
    func test_status_forDate_returnsCorrectDayAvailability() {
        let today = Date()
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
            XCTFail("Could not create tomorrow's date")
            return
        }
        
        let todayStatus = DayAvailability(date: today, status: .free)
        let tomorrowStatus = DayAvailability(date: tomorrow, status: .busy)
        
        let schedule = UserSchedule(
            id: "user_123",
            name: "John Doe",
            weeklyStatus: [todayStatus, tomorrowStatus]
        )
        
        let foundToday = schedule.status(for: today)
        let foundTomorrow = schedule.status(for: tomorrow)
        
        XCTAssertNotNil(foundToday)
        XCTAssertEqual(foundToday?.status, .free)
        XCTAssertEqual(foundToday?.id, todayStatus.id)
        
        XCTAssertNotNil(foundTomorrow)
        XCTAssertEqual(foundTomorrow?.status, .busy)
        XCTAssertEqual(foundTomorrow?.id, tomorrowStatus.id)
    }
    
    func test_status_forDate_returnsNilWhenNotFound() {
        let today = Date()
        guard let futureDate = calendar.date(byAdding: .day, value: 10, to: today) else {
            XCTFail("Could not create future date")
            return
        }
        
        let schedule = UserSchedule(
            id: "user_123",
            name: "John Doe",
            weeklyStatus: [DayAvailability(date: today, status: .free)]
        )
        
        XCTAssertNil(schedule.status(for: futureDate))
    }
    
    func test_status_forDate_matchesSameDayRegardlessOfTime() {
        let today = calendar.startOfDay(for: Date())
        
        // Create morning and evening dates (same day, different times)
        guard let morning = calendar.date(byAdding: .hour, value: 9, to: today),
              let evening = calendar.date(byAdding: .hour, value: 18, to: today) else {
            XCTFail("Could not create test dates")
            return
        }
        
        let status = DayAvailability(date: morning, status: .free)
        let schedule = UserSchedule(
            id: "user_123",
            name: "John Doe",
            weeklyStatus: [status]
        )
        
        let result = schedule.status(for: evening)
        
        XCTAssertNotNil(result, "Should match same day regardless of time")
        XCTAssertEqual(result?.status, .free)
    }
    
    // MARK: - Identifiable Conformance Tests
    
    func test_conformsToIdentifiable() {
        let schedule = UserSchedule(id: "user_123", name: "John Doe", weeklyStatus: [])
        XCTAssertEqual(schedule.id, "user_123")
    }
    
    // MARK: - Mutability Tests
    
    func test_weeklyStatus_canBeMutated() {
        var schedule = UserSchedule(
            id: "user_123",
            name: "John Doe",
            weeklyStatus: [DayAvailability(date: Date(), status: .busy)]
        )
        
        let newStatus = DayAvailability(date: Date(), status: .free)
        schedule.weeklyStatus.append(newStatus)
        
        XCTAssertEqual(schedule.weeklyStatus.count, 2)
        XCTAssertEqual(schedule.weeklyStatus.last?.status, .free)
    }
}
