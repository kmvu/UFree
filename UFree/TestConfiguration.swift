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

    /// Returns true when the integration scheme sets `UFREE_INTEGRATION_TESTS=1`
    /// (Auth + Firestore pointed at local emulators).
    static var isRunningIntegrationTests: Bool {
        FirebaseEmulatorBootstrap.isRequested
    }

    /// Returns true if running under UI tests
    static var isRunningUITests: Bool {
        ProcessInfo.processInfo.arguments.contains("UI_TESTING_MODE")
    }

    /// Hermetic UI-test world. Default matches the historical Alex/Casey seed.
    static var uiTestingScenario: UITestingScenario {
        guard let raw = argumentValue(prefix: "UI_TESTING_SCENARIO="),
              let scenario = UITestingScenario(rawValue: raw) else {
            return .default
        }
        return scenario
    }

    /// DEBUG persona index from `UI_TEST_PERSONA=1|2|3` (1-based). Used without `UI_TESTING_MODE`.
    static var uiTestPersonaIndex: Int? {
        guard let raw = argumentValue(prefix: "UI_TEST_PERSONA="),
              let value = Int(raw),
              (1...3).contains(value) else {
            return nil
        }
        return value - 1
    }

    /// Injected QR / profile uid from `UI_TEST_SCANNED_PROFILE=`.
    static var uiTestScannedProfileId: String? {
        argumentValue(prefix: "UI_TEST_SCANNED_PROFILE=")
    }

    /// Layer B/C: drop a persisted Firebase Auth session so emulator wipes stay consistent.
    static var uiTestResetAuth: Bool {
        ProcessInfo.processInfo.arguments.contains("UI_TEST_RESET_AUTH")
    }

    /// Returns true if any test environment
    static var isTesting: Bool {
        isRunningUnitTests || isRunningUITests || isRunningIntegrationTests
    }

    private static func argumentValue(prefix: String) -> String? {
        ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix(prefix) })
            .map { String($0.dropFirst(prefix.count)) }
            .flatMap { $0.isEmpty ? nil : $0 }
    }
}

enum UITestingScenario: String {
    case `default`
    case login
    case empty
    case firstConnect
    case partialDay
    case batchNudge
    case busyUnknown
    case unreadInbox
    case offline
}
