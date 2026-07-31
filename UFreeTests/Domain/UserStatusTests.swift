//
//  UserStatusTests.swift
//  UFreeTests
//

import XCTest
@testable import UFree

@MainActor
final class UserStatusTests: XCTestCase {

    func test_allCases_coversEveryStatus() {
        XCTAssertEqual(UserStatus.allCases.count, 7)
    }

    func test_title_isUniquePerStatus() {
        let titles = UserStatus.allCases.map(\.title)

        XCTAssertEqual(Set(titles).count, titles.count)
        XCTAssertFalse(titles.contains(where: \.isEmpty))
    }

    func test_title_matchesExpectedCopy() {
        XCTAssertEqual(UserStatus.free.title, "I'm Free Now!")
        XCTAssertEqual(UserStatus.morning.title, "Free in Morning")
        XCTAssertEqual(UserStatus.afternoon.title, "Free in Afternoon")
        XCTAssertEqual(UserStatus.evening.title, "Free in Evening")
        XCTAssertEqual(UserStatus.busy.title, "Busy Right Now")
        XCTAssertEqual(UserStatus.checkSchedule.title, "Check My Schedule")
    }

    func test_mixedTitle_usesCustomTextWhenProvided() {
        XCTAssertEqual(UserStatus.mixed.title(customMixed: "Free 11 AM at 1 PM"), "Free 11 AM at 1 PM")
    }

    func test_mixedTitle_fallsBackToGenericCopy() {
        XCTAssertEqual(UserStatus.mixed.title(customMixed: nil), "Mixed Availability")
    }

    func test_customMixedText_isIgnoredByNonMixedStatuses() {
        for status in UserStatus.allCases where status != .mixed {
            XCTAssertEqual(status.title(customMixed: "ignored"), status.title)
        }
    }

    func test_subtitle_isSharedAcrossStatuses() {
        for status in UserStatus.allCases {
            XCTAssertEqual(status.subtitle, "Tap to change your status")
        }
    }

    func test_iconName_isUniqueAndNonEmpty() {
        let icons = UserStatus.allCases.map(\.iconName)

        XCTAssertEqual(Set(icons).count, icons.count)
        XCTAssertFalse(icons.contains(where: \.isEmpty))
    }

    func test_gradientColors_alwaysHasTwoStops() {
        for status in UserStatus.allCases {
            XCTAssertEqual(status.gradientColors.count, 2, "\(status) should define a two-stop gradient")
        }
    }

    func test_rawValues_areStableIdentifiers() {
        XCTAssertEqual(UserStatus.checkSchedule.rawValue, "checkSchedule")
        XCTAssertEqual(UserStatus(rawValue: "free"), .free)
        XCTAssertNil(UserStatus(rawValue: "not_a_status"))
    }
}
