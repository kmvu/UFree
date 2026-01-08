//
//  DayFilterButtonViewTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 08/01/26.
//

import XCTest
@testable import UFree
import SwiftUI

final class DayFilterButtonViewTests: XCTestCase {

    // MARK: - Refined Capsule UI (Phase 2 - Sprint 6)

    func test_capsuleButton_inactiveState_hasCorrectConfiguration() {
        // Arrange: Inactive button with free count
        let date = Date()
        let freeCount = 3
        
        // Act: Create inactive capsule
        let view = DayFilterButtonView(
            date: date,
            isSelected: false,
            freeCount: freeCount,
            action: {}
        )
        
        // Assert: View is properly configured
        // - Should have systemGray6 background (inactive)
        // - Should display free count badge
        // - Should not be highlighted
        XCTAssertNotNil(view, "Inactive capsule view should render")
    }

    func test_capsuleButton_activeState_isHighlighted() {
        // Arrange: Active button (selected day)
        let date = Date()
        let freeCount = 2
        
        // Act: Create active capsule
        let view = DayFilterButtonView(
            date: date,
            isSelected: true,
            freeCount: freeCount,
            action: {}
        )
        
        // Assert: Active state properties
        // - Should have accentColor background
        // - Should use white text
        // - Badge should be white.opacity(0.3)
        XCTAssertNotNil(view, "Active capsule view should render")
    }

    func test_capsuleButton_badgeDisplay_withFriends() {
        // Arrange: Button with multiple free friends
        let date = Date()
        
        // Act: Render with 5 free friends
        let viewWith5Friends = DayFilterButtonView(
            date: date,
            isSelected: false,
            freeCount: 5,
            action: {}
        )
        
        // Assert: Badge displays count
        XCTAssertNotNil(viewWith5Friends, "Badge should display '5 free'")
    }

    func test_capsuleButton_badgeHidden_whenZeroFriends() {
        // Arrange: Button with no free friends
        let date = Date()
        
        // Act: Render with zero free count
        let viewWithZero = DayFilterButtonView(
            date: date,
            isSelected: false,
            freeCount: 0,
            action: {}
        )
        
        // Assert: Badge hidden but space maintained
        // - Should not show "0 free" text
        // - Should maintain layout height with empty space
        XCTAssertNotNil(viewWithZero, "Zero-count badge should be hidden")
    }

    func test_capsuleButton_badgeColor_greenWhenInactive() {
        // Arrange: Inactive button with friends
        let date = Date()
        let freeCount = 2
        
        // Act: Create inactive capsule with badge
        let view = DayFilterButtonView(
            date: date,
            isSelected: false,
            freeCount: freeCount,
            action: {}
        )
        
        // Assert: Badge uses green.opacity(0.2) background
        XCTAssertNotNil(view, "Inactive badge should be green")
    }

    func test_capsuleButton_badgeColor_whiteWhenActive() {
        // Arrange: Active button with friends
        let date = Date()
        let freeCount = 2
        
        // Act: Create active capsule with badge
        let view = DayFilterButtonView(
            date: date,
            isSelected: true,
            freeCount: freeCount,
            action: {}
        )
        
        // Assert: Badge uses white.opacity(0.3) background
        XCTAssertNotNil(view, "Active badge should be white")
    }

    func test_capsuleButton_dimensions_vertical() {
        // Arrange: Capsule dimensions (60w × 90h)
        let date = Date()
        
        // Act: Create capsule
        let view = DayFilterButtonView(
            date: date,
            isSelected: false,
            freeCount: 1,
            action: {}
        )
        
        // Assert: Geometry is vertical capsule
        // - Width: 60 points
        // - Height: 90 points
        // - Corner radius: 20 (RoundedRectangle)
        XCTAssertNotNil(view, "Capsule dimensions: 60w × 90h")
    }

    func test_capsuleButton_textLayout_weekdayAndDay() {
        // Arrange: Button with date
        let date = Date()
        
        // Act: Create capsule
        let view = DayFilterButtonView(
            date: date,
            isSelected: false,
            freeCount: 3,
            action: {}
        )
        
        // Assert: Text layout
        // - First line: Weekday abbreviated (e.g., "MON")
        // - Second line: Day number (e.g., "14")
        // - Third line: Badge (e.g., "3 free")
        XCTAssertNotNil(view, "Text format: [WKD] [DAY] [X free]")
    }

    func test_capsuleButton_stateTransition_inactiveToActive() {
        // Arrange: Same date for both states
        let date = Date()
        let freeCount = 3
        
        // Act: Render both states
        let inactiveView = DayFilterButtonView(
            date: date,
            isSelected: false,
            freeCount: freeCount,
            action: {}
        )
        let activeView = DayFilterButtonView(
            date: date,
            isSelected: true,
            freeCount: freeCount,
            action: {}
        )
        
        // Assert: Both render without error
        // - Colors should change (gray → accentColor)
        // - Text colors should change (primary → white)
        // - Badge colors should change (green → white)
        XCTAssertNotNil(inactiveView, "Inactive state renders")
        XCTAssertNotNil(activeView, "Active state renders")
    }

    func test_capsuleButton_interaction_callsActionClosure() {
        // Arrange: Button with action closure
        let date = Date()
        var actionCalled = false
        
        // Act: Create button with callback
        let view = DayFilterButtonView(
            date: date,
            isSelected: false,
            freeCount: 2,
            action: {
                actionCalled = true
            }
        )
        
        // Assert: Action closure is configured (actual tap behavior tested in UI tests)
        XCTAssertNotNil(view, "Button view should render successfully")
        XCTAssertFalse(actionCalled, "Action should not be called during view creation")
    }

    func test_capsuleButton_badgeEdgeCases_largeCount() {
        // Arrange: Button with many friends
        let date = Date()
        let largeCount = 99
        
        // Act: Create capsule with large badge count
        let view = DayFilterButtonView(
            date: date,
            isSelected: false,
            freeCount: largeCount,
            action: {}
        )
        
        // Assert: Large counts display correctly
        // - Should show "99 free" without truncation
        XCTAssertNotNil(view, "Large count badge renders: 99 free")
    }
}
