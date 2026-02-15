//
//  TestConfiguration.swift
//  UFree
//
//  Configuration helpers to detect and optimize for test environments
//

import Foundation

/// Detects if code is running in a test environment
struct TestConfiguration {
    /// Returns true if running under unit tests (XCTest)
    static var isRunningUnitTests: Bool {
        NSClassFromString("XCTest") != nil
    }
    
    /// Returns true if running under UI tests
    static var isRunningUITests: Bool {
        ProcessInfo.processInfo.arguments.contains("UI_TESTING_MODE")
    }
    
    /// Returns true if any test environment
    static var isTesting: Bool {
        isRunningUnitTests || isRunningUITests
    }
}
