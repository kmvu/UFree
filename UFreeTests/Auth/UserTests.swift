//
//  UserTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 31/12/25.
//

import XCTest
@testable import UFree

final class UserTests: XCTestCase {
    
    // MARK: - Initialization
    
    func test_init_createsUserWithValidProperties() {
        let id = "test-user-123"
        let isAnonymous = true
        
        let user = User(id: id, isAnonymous: isAnonymous)
        
        XCTAssertEqual(user.id, id)
        XCTAssertEqual(user.isAnonymous, isAnonymous)
    }
    
    // MARK: - Identifiable
    
    func test_user_conformsToIdentifiable() {
        let user = User(id: "123", isAnonymous: true)
        
        XCTAssertEqual(user.id, "123")
    }
    
    // MARK: - Equatable
    
    func test_twoUsersWithSamePropertiesAreEqual() {
        let user1 = User(id: "123", isAnonymous: true)
        let user2 = User(id: "123", isAnonymous: true)
        
        XCTAssertEqual(user1, user2)
    }
    
    func test_twoUsersWithDifferentIDsAreNotEqual() {
        let user1 = User(id: "123", isAnonymous: true)
        let user2 = User(id: "456", isAnonymous: true)
        
        XCTAssertNotEqual(user1, user2)
    }
    
    // MARK: - Codable
    
    func test_user_canBeEncodedToJSON() throws {
        let user = User(id: "test-123", isAnonymous: true)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(user)
        
        XCTAssertNotNil(data)
    }
    
    func test_user_canBeDecodedFromJSON() throws {
        let json = """
        {
            "id": "test-123",
            "isAnonymous": true
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let user = try decoder.decode(User.self, from: json)
        
        XCTAssertEqual(user.id, "test-123")
        XCTAssertEqual(user.isAnonymous, true)
    }
    
    func test_user_roundTripCoding() throws {
        let originalUser = User(id: "round-trip-123", isAnonymous: false)
        
        let encoder = JSONEncoder()
        let encoded = try encoder.encode(originalUser)
        
        let decoder = JSONDecoder()
        let decodedUser = try decoder.decode(User.self, from: encoded)
        
        XCTAssertEqual(originalUser, decodedUser)
    }
}
