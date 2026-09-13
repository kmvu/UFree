//
//  PeerDriver.swift
//  UFreeUITests
//
//  Second/third user against Auth + Firestore emulators via REST.
//  Used by Layer B (one sim) and Layer C (mailbox) — no Firebase iOS SDK in this bundle.
//

import Foundation
import XCTest

struct PeerDriver {
    let projectId: String
    let authHost: String
    let firestoreHost: String

    init(
        projectId: String = "ufree-313a2",
        authHost: String = "http://127.0.0.1:9099",
        firestoreHost: String = "http://127.0.0.1:8080"
    ) {
        self.projectId = projectId
        self.authHost = authHost
        self.firestoreHost = firestoreHost
    }

    var isEmulatorReachable: Bool {
        var request = URLRequest(url: URL(string: "\(firestoreHost)")!)
        request.httpMethod = "GET"
        request.timeoutInterval = 1.5
        let semaphore = DispatchSemaphore(value: 0)
        var ok = false
        URLSession.shared.dataTask(with: request) { _, response, _ in
            ok = (response as? HTTPURLResponse) != nil
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + 2)
        return ok
    }

    func resetEmulatorData() async throws {
        try await delete(
            url: URL(string: "\(firestoreHost)/emulator/v1/projects/\(projectId)/databases/(default)/documents")!
        )
        try await delete(
            url: URL(string: "\(authHost)/emulator/v1/projects/\(projectId)/accounts")!
        )
    }

    @discardableResult
    func signUp(email: String, password: String = "password123") async throws -> (uid: String, idToken: String) {
        let url = URL(string: "\(authHost)/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key")!
        let body = ["email": email, "password": password, "returnSecureToken": true] as [String: Any]
        let json = try await postJSON(url: url, body: body)
        guard let uid = json["localId"] as? String, let token = json["idToken"] as? String else {
            throw PeerDriverError.unexpectedResponse("signUp missing localId/idToken")
        }
        return (uid, token)
    }

    func updateDisplayName(idToken: String, displayName: String) async throws {
        let url = URL(string: "\(authHost)/identitytoolkit.googleapis.com/v1/accounts:update?key=fake-api-key")!
        try await postJSON(url: url, body: [
            "idToken": idToken,
            "displayName": displayName,
            "returnSecureToken": true
        ])
    }

    enum PeerDriverError: Error {
        case unexpectedResponse(String)
        case http(Int)
    }

    private func delete(url: URL) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 12
        let (_, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(status) || status == 404 else {
            throw PeerDriverError.http(status)
        }
    }

    @discardableResult
    private func postJSON(url: URL, body: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(status) else {
            throw PeerDriverError.http(status)
        }
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return object ?? [:]
    }
}

enum EmulatorUILaunch {
    static func makeApp(persona: Int = 1) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TEST_PERSONA=\(persona)"]
        app.launchEnvironment = ["UFREE_INTEGRATION_TESTS": "1"]
        return app
    }

    static func requireEmulator(_ driver: PeerDriver = PeerDriver()) throws {
        guard driver.isEmulatorReachable else {
            throw XCTSkip("Layer B needs Auth/Firestore emulators on 127.0.0.1:9099 / :8080")
        }
    }
}
