//
//  XCTestCase+WaitUntil.swift
//  UFreeTests
//

import XCTest

extension XCTestCase {
    /// Yields to the cooperative thread pool until `condition` holds, then asserts it.
    ///
    /// Used for ViewModel methods that kick off unstructured `Task`s without
    /// returning them, where there is nothing to `await` directly. Keeps the
    /// Zero-Sleep Protocol intact: no fixed delays, only `Task.yield()`.
    @MainActor
    func waitUntil(
        _ description: String,
        timeout: TimeInterval = 2.0,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            await Task.yield()
        }
        XCTAssertTrue(condition(), "Timed out waiting for: \(description)", file: file, line: line)
    }

    /// Lets already-scheduled `Task`s run to completion before assertions in `tearDown()`.
    ///
    /// ViewModels that fire unstructured `Task`s hold a strong reference to themselves
    /// until the task body returns, so leak checks need the cooperative pool to drain
    /// first. Yielding is enough because all such work is `@MainActor`-bound.
    @MainActor
    func drainPendingTasks(iterations: Int = 50) async {
        for _ in 0..<iterations {
            await Task.yield()
        }
    }
}
