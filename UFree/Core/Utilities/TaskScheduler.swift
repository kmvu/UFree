//
//  TaskScheduler.swift
//  UFree
//
//  Created by Cline on 06/28/26.
//

import Foundation

@MainActor
protocol TaskScheduler: Sendable {
    func schedule(delay: TimeInterval, action: @escaping @MainActor () -> Void)
}

struct MainTaskScheduler: TaskScheduler {
    func schedule(delay: TimeInterval, action: @escaping @MainActor () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            action()
        }
    }
}

struct ImmediateTaskScheduler: TaskScheduler {
    func schedule(delay: TimeInterval, action: @escaping @MainActor () -> Void) {
        action()
    }
}
