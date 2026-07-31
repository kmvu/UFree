//
//  ContactsRepositoryStub.swift
//  UFreeTests
//

import Foundation
@testable import UFree

/// Test double for `ContactsRepositoryProtocol` so contact-sync flows never touch
/// the real address book (which is unavailable and non-deterministic in tests).
final class ContactsRepositoryStub: ContactsRepositoryProtocol, @unchecked Sendable {

    var accessGranted: Bool = true
    var hashes: [String] = []
    var fetchError: Error?

    private(set) var requestAccessCallCount = 0
    private(set) var fetchCallCount = 0

    init(accessGranted: Bool = true, hashes: [String] = []) {
        self.accessGranted = accessGranted
        self.hashes = hashes
    }

    func requestAccess() async -> Bool {
        requestAccessCallCount += 1
        return accessGranted
    }

    func fetchHashedContacts() async throws -> [String] {
        fetchCallCount += 1
        if let fetchError { throw fetchError }
        return hashes
    }
}
