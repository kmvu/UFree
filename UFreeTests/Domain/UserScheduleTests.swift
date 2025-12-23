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
    
    func test_init_createsScheduleWithAllProperties() {
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
    
    func test_init_withoutAvatarURL_createsScheduleWithNilAvatar() {
        let schedule = UserSchedule(id: "user_123", name: "John Doe", weeklyStatus: [])
        
        XCTAssertNil(schedule.avatarURL)
    }
    
    func test_status_forDate_returnsMatchingDayAvailability() {
        let calendar = Calendar.current
        let today = Date()
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
            XCTFail("Failed to create tomorrow's date")
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
    
    func test_status_forDate_returnsNilWhenNoMatch() {
        let today = Date()
        guard let futureDate = Calendar.current.date(byAdding: .day, value: 10, to: today) else {
            XCTFail("Failed to create future date")
            return
        }
        
        let schedule = UserSchedule(
            id: "user_123",
            name: "John Doe",
            weeklyStatus: [DayAvailability(date: today, status: .free)]
        )
        
        let result = schedule.status(for: futureDate)
        
        XCTAssertNil(result)
    }
    
    func test_status_forDate_matchesSameDayIgnoringTime() {
        let calendar = Calendar.current
        let today = Date()
        // Set hour, minute, and second separately using the correct API
        guard var todayMorning = calendar.date(bySetting: .hour, value: 9, of: today),
              let morningWithMinute = calendar.date(bySetting: .minute, value: 0, of: todayMorning),
              let morningWithSecond = calendar.date(bySetting: .second, value: 0, of: morningWithMinute),
              var todayEvening = calendar.date(bySetting: .hour, value: 18, of: today),
              let eveningWithMinute = calendar.date(bySetting: .minute, value: 0, of: todayEvening),
              let eveningWithSecond = calendar.date(bySetting: .second, value: 0, of: eveningWithMinute) else {
            XCTFail("Failed to create test dates")
            return
        }
        
        todayMorning = morningWithSecond
        todayEvening = eveningWithSecond
        
        let status = DayAvailability(date: todayMorning, status: .free)
        let schedule = UserSchedule(
            id: "user_123",
            name: "John Doe",
            weeklyStatus: [status]
        )
        
        let result = schedule.status(for: todayEvening)
        
        XCTAssertNotNil(result, "Should match same day regardless of time")
        XCTAssertEqual(result?.status, .free)
    }
    
    func test_identifiable_conformsToIdentifiable() {
        let schedule = UserSchedule(id: "user_123", name: "John Doe", weeklyStatus: [])
        let id = schedule.id
        
        // Verify it conforms to Identifiable by checking id property exists
        XCTAssertEqual(id, "user_123")
    }
    
    func test_mutatingWeeklyStatus_updatesStatus() {
        var schedule = UserSchedule(
            id: "user_123",
            name: "John Doe",
            weeklyStatus: [DayAvailability(date: Date(), status: .unknown)]
        )
        
        let newStatus = DayAvailability(date: Date(), status: .free)
        schedule.weeklyStatus.append(newStatus)
        
        XCTAssertEqual(schedule.weeklyStatus.count, 2)
        XCTAssertEqual(schedule.weeklyStatus.last?.status, .free)
    }
}

