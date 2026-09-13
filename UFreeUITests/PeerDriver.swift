//
//  PeerDriver.swift
//  UFreeUITests
//
//  Second/third user against Auth + Firestore emulators via REST.
//  Used by Layer B (one sim) and Layer C (mailbox) — no Firebase iOS SDK in this bundle.
//

import CryptoKit
import Foundation
import XCTest

struct PeerSession {
    let uid: String
    let idToken: String
    let displayName: String
    let phoneNumber: String
}

struct PeerDriver {
    let projectId: String
    let authHost: String
    let firestoreHost: String

    static let personaPhones = ["+15550000001", "+15550000002", "+15550000003"]
    static let personaNames = ["Test User 1", "Test User 2", "Test User 3"]

    init(
        projectId: String = "ufree-313a2",
        authHost: String = "http://127.0.0.1:9099",
        firestoreHost: String = "http://127.0.0.1:8080"
    ) {
        self.projectId = projectId
        self.authHost = authHost
        self.firestoreHost = firestoreHost
    }

    var documentsURL: String {
        "\(firestoreHost)/v1/projects/\(projectId)/databases/(default)/documents"
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

    // MARK: - Auth

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

    @discardableResult
    func signUpAnonymous() async throws -> (uid: String, idToken: String) {
        let url = URL(string: "\(authHost)/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key")!
        let json = try await postJSON(url: url, body: ["returnSecureToken": true])
        guard let uid = json["localId"] as? String, let token = json["idToken"] as? String else {
            throw PeerDriverError.unexpectedResponse("anonymous signUp missing localId/idToken")
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

    /// Seeds DEBUG persona 2 or 3 (0-based). Persona 1 is created by the app.
    func seedPersona(_ index: Int) async throws -> PeerSession {
        precondition((0...2).contains(index), "persona index must be 0...2")
        let phone = Self.personaPhones[index]
        let name = Self.personaNames[index]
        let (uid, token) = try await signUpAnonymous()
        try await updateDisplayName(idToken: token, displayName: name)
        try await saveUserProfile(uid: uid, idToken: token, displayName: name, phoneNumber: phone)
        return PeerSession(uid: uid, idToken: token, displayName: name, phoneNumber: phone)
    }

    // MARK: - Profile

    func saveUserProfile(
        uid: String,
        idToken: String,
        displayName: String,
        phoneNumber: String?
    ) async throws {
        var userFields: [String: Any] = [
            "displayName": stringValue(displayName)
        ]
        if let phoneNumber {
            let hashes = PeerPhoneHash.hashes(for: phoneNumber)
            if !hashes.isEmpty {
                userFields["hashedPhoneNumbers"] = [
                    "arrayValue": ["values": hashes.map { stringValue($0) }]
                ]
                userFields["hashedPhoneNumber"] = stringValue(hashes[0])
            }
        }

        try await patchDocument(path: "users/\(uid)", idToken: idToken, fields: userFields)
        try await patchDocument(
            path: "publicProfiles/\(uid)",
            idToken: idToken,
            fields: ["displayName": stringValue(displayName)]
        )

        if let phoneNumber {
            for hash in PeerPhoneHash.hashes(for: phoneNumber) {
                try await patchDocument(
                    path: "phoneDirectory/\(hash)",
                    idToken: idToken,
                    fields: ["uid": stringValue(uid)],
                    exists: false
                )
            }
        }
    }

    func waitForUid(phoneNumber: String, readerIdToken: String, timeout: TimeInterval = 20) async throws -> String {
        let hashes = PeerPhoneHash.hashes(for: phoneNumber)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for hash in hashes {
                if let uid = try? await stringField(
                    path: "phoneDirectory/\(hash)",
                    name: "uid",
                    idToken: readerIdToken
                ) {
                    return uid
                }
            }
            try await Task.sleep(nanoseconds: 400_000_000)
        }
        throw PeerDriverError.unexpectedResponse("timeout waiting for phoneDirectory \(phoneNumber)")
    }

    // MARK: - Handshake

    static func friendRequestId(fromId: String, toId: String) -> String {
        "\(fromId)_\(toId)"
    }

    func sendFriendRequest(
        fromId: String,
        fromName: String,
        toId: String,
        senderIdToken: String
    ) async throws {
        let requestId = Self.friendRequestId(fromId: fromId, toId: toId)
        let now = ISO8601DateFormatter().string(from: Date())
        try await patchDocument(
            path: "friendRequests/\(requestId)",
            idToken: senderIdToken,
            fields: [
                "fromId": stringValue(fromId),
                "fromName": stringValue(fromName),
                "toId": stringValue(toId),
                "status": stringValue("pending"),
                "timestamp": ["timestampValue": now]
            ]
        )
        try await createDocument(
            parentPath: "users/\(toId)/notifications",
            idToken: senderIdToken,
            fields: [
                "recipientId": stringValue(toId),
                "senderId": stringValue(fromId),
                "senderName": stringValue(fromName),
                "type": stringValue("friendRequest"),
                "date": ["timestampValue": now],
                "isRead": ["booleanValue": false],
                "relatedRequestId": stringValue(requestId)
            ]
        )
    }

    func acceptFriendRequest(fromId: String, toId: String, recipientIdToken: String) async throws {
        let requestId = Self.friendRequestId(fromId: fromId, toId: toId)
        let requestName = documentName("friendRequests/\(requestId)")
        try await commit(
            writes: [
                [
                    "update": [
                        "name": requestName,
                        "fields": ["status": stringValue("accepted")]
                    ],
                    "updateMask": ["fieldPaths": ["status"]],
                    "currentDocument": ["exists": true]
                ],
                [
                    "transform": [
                        "document": documentName("users/\(toId)"),
                        "fieldTransforms": [[
                            "fieldPath": "friendIds",
                            "appendMissingElements": ["values": [stringValue(fromId)]]
                        ]]
                    ]
                ],
                [
                    "transform": [
                        "document": documentName("users/\(fromId)"),
                        "fieldTransforms": [[
                            "fieldPath": "friendIds",
                            "appendMissingElements": ["values": [stringValue(toId)]]
                        ]]
                    ]
                ]
            ],
            idToken: recipientIdToken
        )
    }

    func declineFriendRequest(fromId: String, toId: String, recipientIdToken: String) async throws {
        let requestId = Self.friendRequestId(fromId: fromId, toId: toId)
        try await patchDocument(
            path: "friendRequests/\(requestId)",
            idToken: recipientIdToken,
            fields: ["status": stringValue("declined")],
            mask: ["status"]
        )
    }

    enum PeerDriverError: Error, CustomStringConvertible {
        case unexpectedResponse(String)
        case http(Int, String)

        var description: String {
            switch self {
            case .unexpectedResponse(let message): return message
            case .http(let status, let body): return "HTTP \(status): \(body)"
            }
        }
    }

    // MARK: - REST

    private func documentName(_ path: String) -> String {
        "projects/\(projectId)/databases/(default)/documents/\(path)"
    }

    private func stringValue(_ value: String) -> [String: String] {
        ["stringValue": value]
    }

    private func patchDocument(
        path: String,
        idToken: String,
        fields: [String: Any],
        mask: [String]? = nil,
        exists: Bool? = nil
    ) async throws {
        var items: [URLQueryItem] = []
        if let mask {
            items.append(contentsOf: mask.map { URLQueryItem(name: "updateMask.fieldPaths", value: $0) })
        }
        if let exists {
            items.append(URLQueryItem(name: "currentDocument.exists", value: exists ? "true" : "false"))
        }
        var components = URLComponents(string: "\(documentsURL)/\(path)")!
        if !items.isEmpty {
            components.queryItems = items
        }
        var request = URLRequest(url: components.url!)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["fields": fields])
        request.timeoutInterval = 12
        try await send(request)
    }

    private func createDocument(
        parentPath: String,
        idToken: String,
        fields: [String: Any]
    ) async throws {
        let url = URL(string: "\(documentsURL)/\(parentPath)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["fields": fields])
        request.timeoutInterval = 12
        try await send(request)
    }

    private func commit(writes: [[String: Any]], idToken: String) async throws {
        let url = URL(string: "\(documentsURL):commit")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["writes": writes])
        request.timeoutInterval = 12
        try await send(request)
    }

    private func stringField(path: String, name: String, idToken: String) async throws -> String {
        let url = URL(string: "\(documentsURL)/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 8
        let json = try await send(request)
        guard
            let fields = json["fields"] as? [String: Any],
            let field = fields[name] as? [String: Any],
            let value = field["stringValue"] as? String
        else {
            throw PeerDriverError.unexpectedResponse("missing \(name) on \(path)")
        }
        return value
    }

    private func delete(url: URL) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 12
        let (_, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(status) || status == 404 else {
            throw PeerDriverError.http(status, "DELETE \(url.lastPathComponent)")
        }
    }

    @discardableResult
    private func postJSON(url: URL, body: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 12
        return try await send(request)
    }

    @discardableResult
    private func send(_ request: URLRequest) async throws -> [String: Any] {
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let body = String(data: data, encoding: .utf8) ?? ""
        guard (200...299).contains(status) else {
            throw PeerDriverError.http(status, String(body.prefix(400)))
        }
        if data.isEmpty { return [:] }
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}

/// Same SHA-256 digit hashes as `CryptoUtils` (UI tests cannot import the app target).
enum PeerPhoneHash {
    static func hashes(for phoneNumber: String) -> [String] {
        let hasPlus = phoneNumber.contains("+")
        let digits = phoneNumber.filter(\.isNumber)
        guard !digits.isEmpty else { return [] }

        var candidates: [String] = []
        if hasPlus {
            candidates.append(digits)
        } else {
            candidates.append(digits)
            if digits.hasPrefix("0") {
                let stripped = String(digits.dropFirst())
                if !stripped.isEmpty { candidates.append(stripped) }
            } else if digits.count == 10 {
                candidates.append("1" + digits)
            }
        }

        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }.map(sha256Hex)
    }

    private static func sha256Hex(_ digits: String) -> String {
        SHA256.hash(data: Data(digits.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

enum EmulatorUILaunch {
    static func makeApp(persona: Int = 1) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "UI_TEST_PERSONA=\(persona)",
            "UI_TEST_RESET_AUTH"
        ]
        app.launchEnvironment = ["UFREE_INTEGRATION_TESTS": "1"]
        return app
    }

    static func requireEmulator(_ driver: PeerDriver = PeerDriver()) throws {
        guard driver.isEmulatorReachable else {
            throw XCTSkip("Layer B needs Auth/Firestore emulators on 127.0.0.1:9099 / :8080")
        }
    }

    @MainActor
    static func waitForPersonaReady(_ app: XCUIApplication, persona: Int = 1) {
        let tabs = app.tabBars.buttons["tab.schedule"]
        let personaButton = app.buttons["login.persona.\(persona)"]
        var tappedPersona = false

        let deadline = Date().addingTimeInterval(40)
        while Date() < deadline {
            // Do not treat a pre-sign-out tab flash as ready — login must be gone.
            if tabs.exists && !personaButton.exists {
                return
            }
            if !tappedPersona, personaButton.exists, personaButton.isHittable {
                personaButton.tap()
                tappedPersona = true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        XCTAssertTrue(tabs.waitForExistence(timeout: 8), "Persona \(persona) should reach Schedule")
        XCTAssertFalse(personaButton.exists, "Persona \(persona) login should be gone")
    }
}
