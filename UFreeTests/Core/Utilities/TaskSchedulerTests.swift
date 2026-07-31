//
//  TaskSchedulerTests.swift
//  UFreeTests
//

import XCTest
@testable import UFree

@MainActor
final class TaskSchedulerTests: XCTestCase {

    // MARK: - Immediate

    func test_immediateScheduler_runsActionSynchronously() {
        var didRun = false

        ImmediateTaskScheduler().schedule(delay: 5.0) { didRun = true }

        XCTAssertTrue(didRun, "The immediate scheduler should ignore the delay entirely")
    }

    func test_immediateScheduler_runsEveryScheduledAction() {
        var runCount = 0
        let sut = ImmediateTaskScheduler()

        sut.schedule(delay: 0) { runCount += 1 }
        sut.schedule(delay: 0) { runCount += 1 }

        XCTAssertEqual(runCount, 2)
    }

    // MARK: - Main Queue

    func test_mainScheduler_doesNotRunActionSynchronously() {
        var didRun = false

        MainTaskScheduler().schedule(delay: 0) { didRun = true }

        XCTAssertFalse(didRun, "The main scheduler defers onto the main queue")
    }

    func test_mainScheduler_eventuallyRunsAction() async {
        let box = ActionBox()

        MainTaskScheduler().schedule(delay: 0) { box.didRun = true }

        await waitUntil("the deferred action runs on the main queue") { box.didRun }
    }
}

/// Holds the flag by reference so the escaping closure and the assertion observe the
/// same storage without capturing a `var` across the suspension point.
@MainActor
private final class ActionBox {
    var didRun = false
}
