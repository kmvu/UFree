//
//  AuthRepositoryStub.swift
//  UFreeTests
//

import Foundation
@testable import UFree

/// Test double for `AuthRepository` that can fail on demand.
///
/// `MockAuthRepository` always succeeds, so it cannot exercise the error branches
/// in `LoginViewModel` / `SettingsViewModel`.
final class AuthRepositoryStub: AuthRepository, @unchecked Sendable {

    var stubbedUser: User?
    var signInError: Error?
    var updateDisplayNameError: Error?
    var signOutError: Error?

    private(set) var updatedDisplayNames: [String] = []
    private(set) var testUserPhoneNumbers: [String] = []

    private let stream: AsyncStream<User?>
    private let continuation: AsyncStream<User?>.Continuation

    init(user: User? = nil) {
        self.stubbedUser = user

        var continuation: AsyncStream<User?>.Continuation!
        self.stream = AsyncStream<User?> { continuation = $0 }
        self.continuation = continuation
    }

    var currentUser: User? {
        get async { stubbedUser }
    }

    nonisolated var authState: AsyncStream<User?> { stream }

    func signInAnonymously() async throws -> User {
        if let signInError { throw signInError }
        let user = User(id: "stub_user", isAnonymous: true, displayName: nil)
        stubbedUser = user
        continuation.yield(user)
        return user
    }

    func signOut() async throws {
        if let signOutError { throw signOutError }
        stubbedUser = nil
        continuation.yield(nil)
    }

    func updateDisplayName(_ name: String) async throws {
        updatedDisplayNames.append(name)
        if let updateDisplayNameError { throw updateDisplayNameError }
        if let user = stubbedUser {
            stubbedUser = User(id: user.id, isAnonymous: user.isAnonymous, displayName: name)
        }
    }

    #if DEBUG
    func signInAsTestUser(phoneNumber: String) async throws -> User {
        testUserPhoneNumbers.append(phoneNumber)
        if let signInError { throw signInError }
        let user = User(id: phoneNumber, isAnonymous: false, displayName: nil)
        stubbedUser = user
        continuation.yield(user)
        return user
    }
    #endif
}
