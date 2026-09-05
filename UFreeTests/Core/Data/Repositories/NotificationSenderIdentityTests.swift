//
//  NotificationSenderIdentityTests.swift
//  UFreeTests
//

import XCTest
@testable import UFree

final class NotificationSenderIdentityTests: XCTestCase {
    func test_requireDisplayName_rejectsNilAndEmpty() {
        XCTAssertThrowsError(try NotificationSenderIdentity.requireDisplayName(nil)) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, NotificationSenderIdentity.errorDomain)
            XCTAssertEqual(nsError.code, 400)
        }
        XCTAssertThrowsError(try NotificationSenderIdentity.requireDisplayName("")) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.code, 400)
            XCTAssertEqual(nsError.localizedDescription, "Display name required to send a nudge")
        }
    }

    func test_requireDisplayName_returnsNonEmptyName() throws {
        XCTAssertEqual(try NotificationSenderIdentity.requireDisplayName("Alice"), "Alice")
    }

    func test_requireSignedInUserId_rejectsNil() {
        XCTAssertThrowsError(try NotificationSenderIdentity.requireSignedInUserId(nil)) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, NotificationSenderIdentity.errorDomain)
            XCTAssertEqual(nsError.code, 401)
        }
    }

    func test_requireSignedInUserId_returnsUid() throws {
        XCTAssertEqual(try NotificationSenderIdentity.requireSignedInUserId("uid-1"), "uid-1")
    }
}
