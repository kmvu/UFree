//
//  TaskScheduler.swift
//  UFree
//
//  Created by Cline on 06/28/26.
//

import Foundation

protocol TaskScheduler: Sendable {
    @MainActor func schedule(delay: TimeInterval, action: @escaping @MainActor () -> Void)
}

struct MainTaskScheduler: TaskScheduler {
    @MainActor func schedule(delay: TimeInterval, action: @escaping @MainActor () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            Task { @MainActor in
                action()
            }
        }
    }
}

struct ImmediateTaskScheduler: TaskScheduler {
    @MainActor func schedule(delay: TimeInterval, action: @escaping @MainActor () -> Void) {
        action()
    }
}
