//
//  BVTDualSimConnectA.swift
//  UFreeUITests
//
//  Layer C session 1 — inviter (persona 1). Skips unless BVT_MAILBOX_URL is set.
//

import XCTest

final class BVTDualSimConnectA: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard ProcessInfo.processInfo.environment["BVT_MAILBOX_URL"] != nil else {
            throw XCTSkip("Layer C requires BVT_MAILBOX_URL from Scripts/run_dual_sim_bvt.sh")
        }
    }

    @MainActor
    func test_inviter_reachesTabs_andSignalsReady() async throws {
        let app = EmulatorUILaunch.makeApp(persona: 1)
        app.launch()

        let onTabs = app.tabBars.buttons["tab.schedule"].waitForExistence(timeout: 30)
            || app.buttons["login.persona.1"].waitForExistence(timeout: 8)
        XCTAssertTrue(onTabs, "Peer A should reach login or Schedule")

        if app.buttons["login.persona.1"].exists {
            app.buttons["login.persona.1"].tap()
            XCTAssertTrue(app.tabBars.buttons["tab.schedule"].waitForExistence(timeout: 25))
        }

        try await MailboxClient.post("readyA")
    }
}

enum MailboxClient {
    static var baseURL: URL {
        URL(string: ProcessInfo.processInfo.environment["BVT_MAILBOX_URL"] ?? "http://127.0.0.1:4739")!
    }

    static func post(_ key: String, value: Any = true) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent(key))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["value": value])
        let (_, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        XCTAssertEqual(status, 200, "Mailbox POST \(key)")
    }

    static func waitFor(_ key: String, timeout: TimeInterval = 30) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            var request = URLRequest(url: baseURL.appendingPathComponent(key))
            request.timeoutInterval = 2
            if let (data, _) = try? await URLSession.shared.data(for: request),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               json["value"] != nil {
                return
            }
            try await Task.sleep(nanoseconds: 400_000_000)
        }
        XCTFail("Timed out waiting for mailbox key \(key)")
    }
}
