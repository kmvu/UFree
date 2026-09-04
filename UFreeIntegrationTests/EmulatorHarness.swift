//
//  EmulatorHarness.swift
//  UFreeIntegrationTests
//
//  Shared setup for Auth + Firestore emulator integration tests.
//

import XCTest
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
@testable import UFree

@MainActor
enum EmulatorHarness {
    private static var didConfigure = false

    /// Short-timeout session so a wedged emulator clear fails fast and can retry.
    private static let clearSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 20
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    static func prepareSuite() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        FirebaseEmulatorBootstrap.connectIfRequested()
        didConfigure = true
    }

    /// Wipe Auth accounts + Firestore data so each test starts clean.
    static func resetEmulatorData() async throws {
        prepareSuite()
        if Auth.auth().currentUser != nil {
            try Auth.auth().signOut()
        }

        // Pause SDK traffic so the emulator clear endpoint is not blocked by open streams.
        let db = Firestore.firestore()
        try? await db.disableNetwork()

        let projectId = FirebaseApp.app()?.options.projectID ?? "ufree-313a2"
        let firestoreClear = URL(
            string: "http://127.0.0.1:8080/emulator/v1/projects/\(projectId)/databases/(default)/documents"
        )!
        let authClear = URL(
            string: "http://127.0.0.1:9099/emulator/v1/projects/\(projectId)/accounts"
        )!

        do {
            try await clearHTTPWithRetry(url: firestoreClear)
            try await clearHTTPWithRetry(url: authClear)
        } catch {
            try? await Firestore.firestore().enableNetwork()
            throw error
        }

        try await Firestore.firestore().enableNetwork()
    }

    /// Create (or sign in) an email/password user on the Auth emulator and set displayName.
    @discardableResult
    static func signInUser(email: String, password: String = "password123", displayName: String) async throws -> String {
        prepareSuite()
        if Auth.auth().currentUser != nil {
            try Auth.auth().signOut()
        }

        let auth = Auth.auth()
        let result: AuthDataResult
        do {
            result = try await auth.createUser(withEmail: email, password: password)
        } catch {
            result = try await auth.signIn(withEmail: email, password: password)
        }

        let change = result.user.createProfileChangeRequest()
        change.displayName = displayName
        try await change.commitChanges()
        // Ensure Auth.currentUser.displayName is visible to repositories (nudge, requests).
        try await auth.currentUser?.reload()
        return auth.currentUser?.uid ?? result.user.uid
    }

    static func signOut() throws {
        if Auth.auth().currentUser != nil {
            try Auth.auth().signOut()
        }
    }

    private static func clearHTTPWithRetry(url: URL, attempts: Int = 4) async throws {
        var lastError: Error?
        for attempt in 1...attempts {
            do {
                try await clearHTTP(url: url)
                return
            } catch {
                lastError = error
                // Back off briefly; emulator clear can stall under concurrent SDK traffic.
                try? await Task.sleep(nanoseconds: UInt64(attempt) * 250_000_000)
            }
        }
        throw lastError ?? NSError(
            domain: "EmulatorHarness",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to clear emulator at \(url)"]
        )
    }

    private static func clearHTTP(url: URL) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 12
        let (_, response) = try await clearSession.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        // 200 OK, 204 No Content — also tolerate 404 if emulator just started empty.
        guard (200..<300).contains(status) || status == 404 else {
            throw NSError(
                domain: "EmulatorHarness",
                code: status,
                userInfo: [NSLocalizedDescriptionKey: "Failed to clear emulator at \(url): HTTP \(status)"]
            )
        }
    }
}

extension XCTestCase {
    /// Fail fast with a clear message when the emulator suite was launched without emulators.
    func requireIntegrationEnvironment() throws {
        guard FirebaseEmulatorBootstrap.isRequested else {
            throw XCTSkip("Set UFREE_INTEGRATION_TESTS=1 and start Auth+Firestore emulators (see Docs/TESTING_GUIDE.md).")
        }
    }
}
