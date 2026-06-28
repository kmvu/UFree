//
//  CryptoUtilsPhoneHashesTests.swift
//  UFreeTests
//
//  Created by Cline on 06/28/26.
//

import XCTest
@testable import UFree

final class CryptoUtilsPhoneHashesTests: XCTestCase {
    
    func test_phoneNumberHashes_withInternationalE164_returnsOneHash() {
        let input = "+61412345678"
        let hashes = CryptoUtils.phoneNumberHashes(for: input)
        
        XCTAssertEqual(hashes.count, 1)
        // Ensure it doesn't return empty
        XCTAssertFalse(hashes[0].isEmpty)
    }
    
    func test_phoneNumberHashes_withAustralianLocal_returnsTwoHashes() {
        let input = "0412345678"
        let hashes = CryptoUtils.phoneNumberHashes(for: input)
        
        // Should generate "0412345678" and "412345678" (stripped leading 0)
        XCTAssertEqual(hashes.count, 2)
        XCTAssertNotEqual(hashes[0], hashes[1])
    }
    
    func test_phoneNumberHashes_withUSLocal_returnsTwoHashes() {
        let input = "5551234567" // 10 digits
        let hashes = CryptoUtils.phoneNumberHashes(for: input)
        
        // Should generate "5551234567" and "15551234567" (prepended 1)
        XCTAssertEqual(hashes.count, 2)
        XCTAssertNotEqual(hashes[0], hashes[1])
    }
    
    func test_phoneNumberHashes_withFormattingCharacters_ignoresThem() {
        let input1 = "+1 (555) 123-4567"
        let input2 = "+15551234567"
        
        let hashes1 = CryptoUtils.phoneNumberHashes(for: input1)
        let hashes2 = CryptoUtils.phoneNumberHashes(for: input2)
        
        XCTAssertEqual(hashes1, hashes2)
    }
    
    func test_phoneNumberHashes_withNoDigits_returnsEmptyArray() {
        let input = "+abcd ()-"
        let hashes = CryptoUtils.phoneNumberHashes(for: input)
        
        XCTAssertTrue(hashes.isEmpty)
    }
}