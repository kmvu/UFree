//
//  Color+HexTests.swift
//  UFreeTests
//
//  Created by Khang Vu on 01/01/26.
//

import XCTest
import SwiftUI
@testable import UFree

final class ColorHexTests: XCTestCase {
    
    func test_init_withValidHexCode_createsColor() {
        let color = Color(hex: "#FF0000")
        XCTAssertNotNil(color)
    }
    
    func test_init_withHexCodeWithoutHash_createsColor() {
        let color = Color(hex: "FF0000")
        XCTAssertNotNil(color)
    }
    
    func test_init_withLowercaseHex_createsColor() {
        let color = Color(hex: "#ff0000")
        XCTAssertNotNil(color)
    }
    
    func test_init_withMixedCaseHex_createsColor() {
        let color = Color(hex: "#FfAaBb")
        XCTAssertNotNil(color)
    }
    
    func test_init_withMultipleHashPrefixes_createsColor() {
        let color = Color(hex: "##FF0000")
        XCTAssertNotNil(color)
    }
    
    func test_init_withEmptyString_createsColor() {
        let color = Color(hex: "")
        XCTAssertNotNil(color)
    }
    
    func test_init_withCommonWebColors() {
        let colors = [
            Color(hex: "#FF1493"),  // Deep Pink
            Color(hex: "#00BFFF"),  // Deep Sky Blue
            Color(hex: "#228B22"),  // Forest Green
            Color(hex: "#FFD700"),  // Gold
        ]
        
        XCTAssertEqual(colors.count, 4)
        colors.forEach { XCTAssertNotNil($0) }
    }
}
