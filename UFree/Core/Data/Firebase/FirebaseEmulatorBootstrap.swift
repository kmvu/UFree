//
//  FirebaseEmulatorBootstrap.swift
//  UFree
//
//  Connects Auth + Firestore SDKs to the local Firebase emulators.
//  Must run immediately after FirebaseApp.configure() and before any Firestore use.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

enum FirebaseEmulatorBootstrap {
    static let host = "127.0.0.1"
    static let authPort = 9099
    static let firestorePort = 8080

    /// Set by the `UFreeIntegrationTests` scheme / Fastlane lane.
    static var isRequested: Bool {
        ProcessInfo.processInfo.environment["UFREE_INTEGRATION_TESTS"] == "1"
    }

    private static var didConnect = false

    /// Idempotent. Safe to call from AppDelegate and from test setUp.
    static func connectIfRequested() {
        guard isRequested else { return }
        guard !didConnect else { return }
        didConnect = true

        Auth.auth().useEmulator(withHost: host, port: authPort)

        let settings = Firestore.firestore().settings
        settings.host = "\(host):\(firestorePort)"
        settings.isSSLEnabled = false
        settings.cacheSettings = MemoryCacheSettings()
        Firestore.firestore().settings = settings
    }
}
