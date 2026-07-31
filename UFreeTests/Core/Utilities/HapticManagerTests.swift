//
//  HapticManagerTests.swift
//  UFreeTests
//

import XCTest
@testable import UFree

/// `HapticManager` is fire-and-forget: the feedback generators report nothing back and the
/// simulator has no haptic hardware. These tests only pin down that each entry point is
/// callable without trapping, which is what the call sites in the views rely on.
@MainActor
final class HapticManagerTests: XCTestCase {

    func test_impactFeedback_everyIntensityIsCallable() {
        HapticManager.light()
        HapticManager.medium()
        HapticManager.heavy()
    }

    func test_notificationFeedback_everyOutcomeIsCallable() {
        HapticManager.success()
        HapticManager.warning()
        HapticManager.error()
    }

    func test_selectionFeedback_isCallable() {
        HapticManager.selection()
    }
}
