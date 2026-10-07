//
//  LocalScheduleStoreTests.swift
//  UFreeTests
//

import XCTest
import SwiftData
@testable import UFree

final class LocalScheduleStoreTests: XCTestCase {
    func test_open_currentSchema_keepsPendingSyncDefault() throws {
        let directory = try makeDirectory()
        let storeURL = directory.appendingPathComponent("default.store")
        let container = try LocalScheduleStore.makeContainer(storeURL: storeURL)
        let context = ModelContext(container)
        let day = PersistentDayAvailability(id: UUID(), date: Date())
        context.insert(day)
        try context.save()
        XCTAssertFalse(day.isPendingSync)

        let reopened = try LocalScheduleStore.makeContainer(storeURL: storeURL)
        let stored = try ModelContext(reopened).fetch(FetchDescriptor<PersistentDayAvailability>())
        XCTAssertEqual(stored.count, 1)
        XCTAssertFalse(stored[0].isPendingSync)
    }

    func test_open_prePendingSyncStore_migratesWithDefault() throws {
        let fixture = try XCTUnwrap(
            Bundle(for: LocalScheduleStoreTests.self).url(
                forResource: "default",
                withExtension: "store",
                subdirectory: "Fixtures/pre-pending-sync"
            ) ?? Bundle(for: LocalScheduleStoreTests.self).url(
                forResource: "default",
                withExtension: "store"
            )
        )
        let directory = try makeDirectory()
        let storeURL = directory.appendingPathComponent("default.store")
        try FileManager.default.copyItem(at: fixture, to: storeURL)

        let container = try LocalScheduleStore.makeContainer(storeURL: storeURL)
        let stored = try ModelContext(container).fetch(FetchDescriptor<PersistentDayAvailability>())
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored[0].note, "pre-pending-sync")
        XCTAssertEqual(stored[0].id, UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"))
        XCTAssertFalse(stored[0].isPendingSync)
        XCTAssertEqual(stored[0].ownerUserId, "")
    }

    func test_open_unreadableStore_resetsAndRecreates() throws {
        let directory = try makeDirectory()
        let storeURL = directory.appendingPathComponent("default.store")
        try Data("not a swift data store".utf8).write(to: storeURL)

        let container = try LocalScheduleStore.makeContainer(storeURL: storeURL)
        let context = ModelContext(container)
        context.insert(PersistentDayAvailability(id: UUID(), date: Date()))
        try context.save()

        let leftover = try Data(contentsOf: storeURL)
        XCTAssertFalse(leftover.starts(with: Data("not a swift data store".utf8)))
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ufree-store-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }
}
