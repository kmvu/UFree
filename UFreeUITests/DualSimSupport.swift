//
//  DualSimSupport.swift
//  UFreeUITests
//
//  Mailbox + handshake helpers for Layer C two-simulator sessions.
//

import XCTest

enum MailboxClient {
    static var baseURL: URL {
        URL(string: ProcessInfo.processInfo.environment["BVT_MAILBOX_URL"] ?? "http://127.0.0.1:4739")!
    }

    static func requireMailbox() throws {
        guard ProcessInfo.processInfo.environment["BVT_MAILBOX_URL"] != nil else {
            throw XCTSkip("Layer C requires BVT_MAILBOX_URL from Scripts/run_dual_sim_bvt.sh")
        }
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

    static func waitFor(_ key: String, timeout: TimeInterval = 90) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            var request = URLRequest(url: baseURL.appendingPathComponent(key))
            request.timeoutInterval = 2
            if let (data, _) = try? await URLSession.shared.data(for: request),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               isPosted(json["value"]) {
                return
            }
            try await Task.sleep(nanoseconds: 400_000_000)
        }
        throw MailboxTimeout(key: key)
    }

    struct MailboxTimeout: Error, LocalizedError {
        let key: String
        var errorDescription: String? { "Timed out waiting for mailbox key \(key)" }
    }

    private static func isPosted(_ value: Any?) -> Bool {
        guard let value, !(value is NSNull) else { return false }
        if let flag = value as? Bool { return flag }
        return true
    }
}

enum DualSimFlow {
    static let persona2Phone = PeerDriver.personaPhones[1]
    static let persona1Name = PeerDriver.personaNames[0]
    static let persona2Name = PeerDriver.personaNames[1]

    @MainActor
    static func launchPersona(_ persona: Int) -> XCUIApplication {
        let app = EmulatorUILaunch.makeApp(persona: persona)
        app.launch()
        EmulatorUILaunch.waitForPersonaReady(app, persona: persona)
        dismissSheetsUntilClear(app)
        app.openFriendsTab()
        dismissSheetsUntilClear(app)
        var search = app.textFields["friends.searchPhone"]
        if !search.waitForExistence(timeout: 3) {
            app.swipeUp()
            app.swipeUp()
            search = app.firstExisting(
                app.textFields["friends.searchPhone"],
                app.textFields["Find by Phone Number"]
            )
        }
        XCTAssertTrue(
            search.waitForExistence(timeout: 12),
            "Persona \(persona) Friends tab should be usable before handshake"
        )
        return app
    }

    @MainActor
    static func dismissSheetsUntilClear(_ app: XCUIApplication, attempts: Int = 5) {
        for _ in 0..<attempts {
            app.dismissBlockingSheets()
            let blocked = app.descendants(matching: .any)["weekend.cta"].exists
                || app.descendants(matching: .any)["hangout.checklist.sheet"].exists
            if !blocked { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
    }

    @MainActor
    static func invitePersona2(_ app: XCUIApplication) {
        app.dismissBlockingSheets()
        app.openFriendsTab()
        app.searchFriendsPhone(persona2Phone)
        let named = app.staticTexts[persona2Name]
        let request = app.buttons["friends.request"]
        if !request.waitForExistence(timeout: 8) && !named.waitForExistence(timeout: 4) {
            app.searchFriendsPhone(persona2Phone)
        }
        XCTAssertTrue(
            request.waitForExistence(timeout: 12) || named.waitForExistence(timeout: 4),
            "Peer A should see \(persona2Name) / Request"
        )
        if request.exists {
            request.tap()
            _ = request.waitForNonExistence(timeout: 8)
        }
    }

    @MainActor
    static func acceptIncoming(_ app: XCUIApplication) {
        app.dismissBlockingSheets()
        app.openFriendsTab()
        app.dismissBlockingSheets()
        var accept = app.firstExisting(app.buttons["friends.accept"], app.buttons["Accept"])
        if !accept.waitForExistence(timeout: 10) {
            if app.buttons["notifications.bell"].waitForExistence(timeout: 3) {
                app.buttons["notifications.bell"].tap()
                accept = app.firstExisting(
                    app.buttons["notifications.accept"],
                    app.buttons["friends.accept"],
                    app.buttons["Accept"]
                )
            }
        }
        if !accept.waitForExistence(timeout: 4) {
            app.openScheduleTab()
            app.openFriendsTab()
            app.dismissBlockingSheets()
            accept = app.firstExisting(app.buttons["friends.accept"], app.buttons["Accept"])
        }
        XCTAssertTrue(accept.waitForExistence(timeout: 16), "Peer B should see an incoming request")
        accept.tap()
        app.dismissConnectChrome()
    }

    @MainActor
    static func markTodayFree(_ app: XCUIApplication) {
        app.dismissBlockingSheets()
        app.dismissKeyboardIfPresent()
        app.openScheduleTab()
        app.dismissBlockingSheets()
        app.markDayViaSheet(
            dateString: UITestDates.todayDateString(),
            actionIdentifier: "schedule.sheet.freeAllDay"
        )
    }

    @MainActor
    static func assertFriendVisibleOnWhosFree(_ app: XCUIApplication, name: String) {
        // Save on A returns as soon as SwiftData writes; Firestore may still be
        // in flight. Who's Free is a one-shot load, so bounce the tab until the
        // peer appears. Do not tap a chip whose value is "0" — that is freeCount,
        // and toggleDate would deselect today.
        let deadline = Date().addingTimeInterval(35)
        while Date() < deadline {
            dismissSheetsUntilClear(app)
            app.openWhosFreeTab()
            focusTodayChipIfNeeded(app)
            let named = app.staticTexts[name]
            let fuzzy = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@", name)
            ).firstMatch
            if named.waitForExistence(timeout: 2) || fuzzy.waitForExistence(timeout: 1) {
                return
            }
            app.openScheduleTab()
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
        XCTFail("Who's Free should list \(name) after they mark today free")
    }

    @MainActor
    static func focusTodayChipIfNeeded(_ app: XCUIApplication) {
        let today = app.buttons["whosFree.day.\(UITestDates.todayDateString())"]
        guard today.waitForExistence(timeout: 3) else { return }
        if !today.isSelected {
            today.tap()
        }
    }

    @MainActor
    static func selectTodayChip(_ app: XCUIApplication) {
        app.openWhosFreeTab()
        let today = app.buttons["whosFree.day.\(UITestDates.todayDateString())"]
        XCTAssertTrue(today.waitForExistence(timeout: 10), "Today chip")
        focusTodayChipIfNeeded(app)
    }

    @MainActor
    static func nudgePeerOnToday(_ app: XCUIApplication, name: String) {
        selectTodayChip(app)
        XCTAssertTrue(
            app.staticTexts[name].waitForExistence(timeout: 12)
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch.waitForExistence(timeout: 4),
            "Who's Free should list \(name) before nudge"
        )
        let nudge = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "whosFree.nudge.")
        ).firstMatch
        XCTAssertTrue(nudge.waitForExistence(timeout: 8), "BVT-33: day-scoped wave nudge")
        nudge.tap()
    }

    @MainActor
    static func openInbox(_ app: XCUIApplication) {
        app.dismissBlockingSheets()
        let bell = app.buttons["notifications.bell"]
        XCTAssertTrue(bell.waitForExistence(timeout: 10), "BVT-40: notification bell")
        let badgeDeadline = Date().addingTimeInterval(10)
        var badge = (bell.value as? String) ?? ""
        while Date() < badgeDeadline {
            badge = (bell.value as? String) ?? ""
            if badge.localizedCaseInsensitiveContains("unread")
                || badge.contains("1")
                || badge.contains("2")
                || badge.contains("3") {
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        bell.tap()
        let inbox = app.descendants(matching: .any)["notifications.root"]
        XCTAssertTrue(
            inbox.waitForExistence(timeout: 8)
                || app.navigationBars["Notifications"].waitForExistence(timeout: 3),
            "BVT-41: notification center"
        )
    }

    @MainActor
    static func replyImInFromInbox(_ app: XCUIApplication) {
        openInbox(app)
        let imIn = app.buttons["notifications.reply.imIn"].firstMatch
        XCTAssertTrue(imIn.waitForExistence(timeout: 12), "BVT-33: I'm in on the live nudge")
        imIn.tap()
        let stamped = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "You replied: I'm in")
        ).firstMatch
        XCTAssertTrue(stamped.waitForExistence(timeout: 8), "BVT-36: inbox stamps I'm in")
    }

    @MainActor
    static func assertInReplyOnWhosFree(_ app: XCUIApplication, name: String) {
        app.dismissBlockingSheets()
        selectTodayChip(app)
        let caption = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "In for")
        ).firstMatch
        let pill = app.staticTexts["In"]
        if caption.waitForExistence(timeout: 8) || pill.waitForExistence(timeout: 4) {
            return
        }
        openInbox(app)
        let inboxCopy = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "is in")
        ).firstMatch
        XCTAssertTrue(
            inboxCopy.waitForExistence(timeout: 10)
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch.waitForExistence(timeout: 4),
            "BVT-36: \(name)'s I'm in should land on Who's Free or the inbox"
        )
    }

    @MainActor
    static func deleteAccountToLogin(_ app: XCUIApplication) {
        app.dismissBlockingSheets()
        app.dismissKeyboardIfPresent()
        app.openScheduleTab()
        XCTAssertTrue(app.buttons["settings.open"].waitForExistence(timeout: 10), "Settings gear")
        app.buttons["settings.open"].tap()
        let delete = app.buttons["settings.deleteAccount"]
        XCTAssertTrue(delete.waitForExistence(timeout: 8), "BVT-47: Delete Account")
        delete.tap()
        let confirm = app.alerts.buttons["Delete"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 6), "Delete confirmation")
        confirm.tap()
        XCTAssertTrue(
            app.textFields["login.name"].waitForExistence(timeout: 20)
                || app.buttons["login.persona.1"].waitForExistence(timeout: 6),
            "BVT-47: wipe returns to login"
        )
    }

    @MainActor
    static func assertPeerGone(_ app: XCUIApplication, name: String) {
        app.dismissBlockingSheets()
        app.openScheduleTab()
        app.openFriendsTab()
        let friend = app.staticTexts[name]
        XCTAssertTrue(
            friend.waitForNonExistence(timeout: 20)
                || !app.staticTexts.matching(NSPredicate(format: "label == %@", name)).firstMatch.exists,
            "BVT-48: \(name) should leave Friends after delete"
        )
        app.openWhosFreeTab()
        XCTAssertFalse(
            app.staticTexts[name].waitForExistence(timeout: 4),
            "BVT-49: \(name) should leave Who's Free after delete"
        )
    }

    @MainActor
    static func assertBothCue(_ app: XCUIApplication) {
        app.openWhosFreeTab()
        focusTodayChipIfNeeded(app)
        let today = app.buttons["whosFree.day.\(UITestDates.todayDateString())"]
        XCTAssertTrue(today.waitForExistence(timeout: 10), "Today chip")
        let value = (today.value as? String) ?? ""
        XCTAssertTrue(
            value == "Both" || today.label.localizedCaseInsensitiveContains("Both"),
            "BVT-28: mutual free day shows Both; label=\(today.label) value=\(value)"
        )
    }
}
