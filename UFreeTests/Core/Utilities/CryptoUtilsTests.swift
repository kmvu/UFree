//
//  CryptoUtilsTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 05/01/26.
//

import XCTest
@testable import UFree

final class CryptoUtilsTests: XCTestCase {
    
    func test_hashPhoneNumber_sameInput_producesSameHash() {
        let phoneNumber = "5551234567"
        let hash1 = CryptoUtils.hashPhoneNumber(phoneNumber)
        let hash2 = CryptoUtils.hashPhoneNumber(phoneNumber)
        
        XCTAssertEqual(hash1, hash2)
    }
    
    func test_hashPhoneNumber_withDashes_normalizesToSameHash() {
        let hash1 = CryptoUtils.hashPhoneNumber("555-123-4567")
        let hash2 = CryptoUtils.hashPhoneNumber("5551234567")
        XCTAssertEqual(hash1, hash2)
    }
    
    func test_hashPhoneNumber_withParentheses_normalizesToSameHash() {
        let hash1 = CryptoUtils.hashPhoneNumber("(555) 123-4567")
        let hash2 = CryptoUtils.hashPhoneNumber("5551234567")
        XCTAssertEqual(hash1, hash2)
    }
    
    func test_hashPhoneNumber_returnsValidHexString() {
        let hash = CryptoUtils.hashPhoneNumber("5551234567")
        XCTAssertNotNil(hash)
        XCTAssertEqual(hash?.count, 64)
    }
    
    func test_hashPhoneNumber_emptyString_returnsNil() {
        XCTAssertNil(CryptoUtils.hashPhoneNumber(""))
    }
}
