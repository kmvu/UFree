//
//  TestContainerFactory.swift
//  UFreeTests
//
//  Helper to create in-memory SwiftData containers for testing
//

import SwiftData
@testable import UFree

/// Factory for creating in-memory SwiftData containers in tests
///
/// All unit tests should use in-memory containers to:
/// - Avoid disk I/O (faster, more reliable on CI)
/// - Prevent conflicts with the app's on-disk database
/// - Ensure tests are isolated and can run in parallel
enum TestContainerFactory {
    
    /// Creates an in-memory ModelContainer for testing
    /// - Returns: A ModelContainer configured to store data in RAM only
    static func makeInMemoryContainer() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(
                for: PersistentDayAvailability.self,
                configurations: config
            )
            return container
        } catch {
            fatalError("Failed to create in-memory test container: \(error)")
        }
    }
}
