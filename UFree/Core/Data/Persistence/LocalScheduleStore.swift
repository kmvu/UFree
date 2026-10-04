//
//  LocalScheduleStore.swift
//  UFree
//

import Foundation
import SwiftData

enum LocalScheduleStore {
    /// Opens the schedule store. A disk store that cannot be migrated is deleted and created again.
    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        let resetDirectory: URL? = inMemory ? nil : applicationSupportDirectory()
        return try open(configuration: configuration, resetDirectory: resetDirectory)
    }

    /// Opens a store at `storeURL` (tests). On failure, deletes `default.store*` in that directory and retries once.
    static func makeContainer(storeURL: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(url: storeURL)
        return try open(
            configuration: configuration,
            resetDirectory: storeURL.deletingLastPathComponent()
        )
    }

    static func reset(in directory: URL) {
        let fileManager = FileManager.default
        let items = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        for url in items where url.lastPathComponent.hasPrefix("default.store") {
            try? fileManager.removeItem(at: url)
        }
    }

    private static func open(
        configuration: ModelConfiguration,
        resetDirectory: URL?
    ) throws -> ModelContainer {
        do {
            return try ModelContainer(
                for: PersistentDayAvailability.self,
                configurations: configuration
            )
        } catch {
            guard let resetDirectory else { throw error }
            reset(in: resetDirectory)
            return try ModelContainer(
                for: PersistentDayAvailability.self,
                configurations: configuration
            )
        }
    }

    private static func applicationSupportDirectory() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }
}
