//
//  XCTestCase+MemoryLeakTracking.swift
//  Core Tests
//

import XCTest

extension XCTestCase {
    /// Call in `setUp()` to assert the object is released when `tearDown()`
    /// nils out the caller's strong reference.  In Swift 6 with
    /// `@MainActor` isolation, `addTeardownBlock` defers `deinit` past
    /// the teardown-block phase, so we check eagerly inside `tearDown()`
    /// via a stored weak reference instead.
    @MainActor
    func trackForMemoryLeaks(
        _ instance: AnyObject,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        _leakTrackedInstances.append(TrackedInstance(instance: instance, file: file, line: line))
    }

    /// Call in `tearDown()` **after** setting the SUT to `nil`.
    /// Asserts every previously-tracked instance has been deallocated.
    @MainActor
    func verifyNoMemoryLeaks(file: StaticString = #filePath, line: UInt = #line) {
        for tracked in _leakTrackedInstances {
            XCTAssertNil(
                tracked.weakInstance,
                "Instance should have been deallocated. Potential memory leak.",
                file: tracked.file,
                line: tracked.line
            )
        }
        _leakTrackedInstances.removeAll()
    }

    // MARK: - Private storage

    private struct TrackedInstance {
        weak var weakInstance: AnyObject?
        let file: StaticString
        let line: UInt

        init(instance: AnyObject, file: StaticString, line: UInt) {
            self.weakInstance = instance
            self.file = file
            self.line = line
        }
    }

    private static var _leakKey: UInt8 = 0

    private var _leakTrackedInstances: [TrackedInstance] {
        get {
            objc_getAssociatedObject(self, &Self._leakKey) as? [TrackedInstance] ?? []
        }
        set {
            objc_setAssociatedObject(self, &Self._leakKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}