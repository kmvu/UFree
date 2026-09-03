//
//  AnalyticsManagerTests.swift
//  UFreeTests
//

import XCTest
@testable import UFree

/// `AnalyticsManager` is a thin Firebase wrapper, so these tests verify the event
/// mapping executes end-to-end without throwing. Firebase Analytics is a no-op in
/// tests (no `GoogleService-Info.plist` configuration), which keeps this hermetic.
@MainActor
final class AnalyticsManagerTests: XCTestCase {

    func test_log_handlesEveryEventCase() {
        let events: [AnalyticsEvent] = [
            .nudgeSent(type: "single"),
            .nudgeSent(type: "batch"),
            .friendRequestSent(source: "qr_code"),
            .searchPerformed(success: true),
            .searchPerformed(success: false),
            .availabilityUpdated(status: "free"),
            .heatmapViewed(friendCount: 3),
            .handshakeCompleted(duration: 12),
            .appLaunched,
            .linkOpened(route: "profile")
        ]

        for event in events {
            AnalyticsManager.log(event)
        }
    }

    func test_convenienceHelpers_mapToUnderlyingEvents() {
        AnalyticsManager.logNudgeSent(isBatch: false)
        AnalyticsManager.logNudgeSent(isBatch: true)
        AnalyticsManager.logFriendRequestSent(source: "contact_sync")
        AnalyticsManager.logBatchNudge(recipientCount: 4)
        AnalyticsManager.logPhoneSearchSuccess()
        AnalyticsManager.logPhoneSearchSuccess(friendName: "Alice")
        AnalyticsManager.logLinkOpened(route: "notification")
    }

    func test_setCollectionEnabled_togglesWithoutThrowing() {
        AnalyticsManager.setCollectionEnabled(false)
        AnalyticsManager.setCollectionEnabled(true)
    }
}
