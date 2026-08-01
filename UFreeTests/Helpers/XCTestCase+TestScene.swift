//
//  XCTestCase+TestScene.swift
//  UFreeTests
//

import XCTest

extension XCTestCase {
    /// Stops listeners and drains pending work for a `TestScene`, then returns so the
    /// caller can nil the property and drain again.
    ///
    /// Typical tearDown:
    /// ```
    /// await releaseTestScene(scene)
    /// scene = nil
    /// await drainPendingTasks()
    /// ```
    ///
    /// Releasing the scene's MainActor-isolated graph while a listener `Task` or SwiftUI
    /// hosting teardown is still in flight is what surfaces as
    /// `pointer being freed was not allocated` under iOS 26.2 XCTest.
    @MainActor
    func releaseTestScene(_ scene: TestScene?) async {
        scene?.tearDown()
        await drainPendingTasks()
    }
}
