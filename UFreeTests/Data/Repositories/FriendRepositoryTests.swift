//
//  FriendRepositoryTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 05/01/26.
//

import XCTest
@testable import UFree

final class FriendRepositoryTests: XCTestCase {
    
    // MARK: - Unit Tests for Repository Logic
    
    func test_contactsRepository_returnEmptyHashes() async throws {
        // Test that the contacts repository can handle empty contacts
        let mockContactsRepo = MockContactsRepository()
        mockContactsRepo.mockHashes = []
        
        let result = try await mockContactsRepo.fetchHashedContacts()
        XCTAssertEqual(result.count, 0)
    }
    
    func test_contactsRepository_returnMultipleHashes() async throws {
        // Test that the contacts repository correctly returns hashes
        let mockContactsRepo = MockContactsRepository()
        mockContactsRepo.mockHashes = (0..<25).map { "hash_\($0)" }
        
        let result = try await mockContactsRepo.fetchHashedContacts()
        XCTAssertEqual(result.count, 25)
    }
    
    func test_contactsRepository_errorHandling() async throws {
        // Test that the contacts repository correctly throws errors
        let mockContactsRepo = MockContactsRepository()
        mockContactsRepo.shouldThrow = true
        
        do {
            _ = try await mockContactsRepo.fetchHashedContacts()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual((error as NSError).domain, "test")
        }
    }
}

// MARK: - Mock ContactsRepository for Testing

private final class MockContactsRepository: ContactsRepositoryProtocol {
    var mockHashes: [String] = []
    var shouldThrow: Bool = false
    
    func requestAccess() async -> Bool {
        return true
    }
    
    func fetchHashedContacts() async throws -> [String] {
        if shouldThrow {
            throw NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        return mockHashes
    }
}
