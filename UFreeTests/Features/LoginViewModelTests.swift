//
//  LoginViewModelTests.swift
//  UFreeTests
//

import XCTest
@testable import UFree

@MainActor
final class LoginViewModelTests: XCTestCase {

    private var authRepository: AuthRepositoryStub!
    private var friendRepository: FriendRepositorySpy!
    private var sut: LoginViewModel!

    override func setUp() {
        super.setUp()
        authRepository = AuthRepositoryStub()
        friendRepository = FriendRepositorySpy()
        sut = LoginViewModel(authRepository: authRepository, friendRepository: friendRepository)
        trackForMemoryLeaks(sut)
    }

    override func tearDown() async throws {
        sut = nil
        authRepository = nil
        friendRepository = nil
        // `loginTapped` runs inside an unstructured Task that retains the ViewModel
        // until it returns, so let that work finish before checking for leaks.
        await drainPendingTasks()
        verifyNoMemoryLeaks()
        try await super.tearDown()
    }

    // MARK: - Initial State

    func test_init_stateIsEmpty() {
        XCTAssertTrue(sut.name.isEmpty)
        XCTAssertTrue(sut.phoneNumber.isEmpty)
        XCTAssertFalse(sut.isLoading)
        XCTAssertFalse(sut.showError)
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - Validation

    func test_loginTapped_emptyName_showsErrorWithoutSigningIn() {
        sut.phoneNumber = "555-1234"

        sut.loginTapped()

        XCTAssertTrue(sut.showError)
        XCTAssertEqual(sut.errorMessage, "Please enter your name to start.")
        XCTAssertTrue(friendRepository.savedProfiles.isEmpty)
        XCTAssertEqual(authRepository.signInWithAppleCallCount, 0)
    }

    func test_loginTapped_whitespaceOnlyName_showsError() {
        sut.name = "   "
        sut.phoneNumber = "555-1234"

        sut.loginTapped()

        XCTAssertTrue(sut.showError)
        XCTAssertEqual(sut.errorMessage, "Please enter your name to start.")
    }

    func test_loginTapped_emptyPhone_stillAllowsSignIn() async {
        sut.name = "Alice"
        sut.phoneNumber = ""

        sut.loginTapped()
        await waitUntil("profile saved") { !self.friendRepository.savedProfiles.isEmpty }

        XCTAssertEqual(authRepository.signInWithAppleCallCount, 1)
        XCTAssertEqual(
            friendRepository.savedProfiles,
            [FriendRepositorySpy.SavedProfile(displayName: "Alice", hashedPhoneNumbers: [])]
        )
    }

    // MARK: - Successful Login

    func test_loginTapped_success_savesProfileWithAllPhoneHashes() async {
        sut.name = "Alice"
        sut.phoneNumber = "555-1234"

        sut.loginTapped()
        await waitUntil("profile saved") { !self.friendRepository.savedProfiles.isEmpty }

        let expectedHashes = CryptoUtils.phoneNumberHashes(for: "555-1234")
        XCTAssertEqual(authRepository.signInWithAppleCallCount, 1)
        XCTAssertEqual(
            friendRepository.savedProfiles,
            [FriendRepositorySpy.SavedProfile(displayName: "Alice", hashedPhoneNumbers: expectedHashes)]
        )
    }

    func test_loginTapped_success_updatesAuthDisplayName() async {
        sut.name = "Alice"
        sut.phoneNumber = "555-1234"

        sut.loginTapped()
        await waitUntil("display name updated") { !self.authRepository.updatedDisplayNames.isEmpty }

        XCTAssertEqual(authRepository.updatedDisplayNames, ["Alice"])
    }

    func test_loginTapped_success_clearsLoadingAndShowsNoError() async {
        sut.name = "Alice"
        sut.phoneNumber = "555-1234"

        sut.loginTapped()
        await waitUntil("loading finished") { !self.sut.isLoading && !self.friendRepository.savedProfiles.isEmpty }

        XCTAssertFalse(sut.showError)
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - Failure Paths

    func test_loginTapped_signInFailure_showsErrorAndSkipsProfileSave() async {
        authRepository.signInError = NSError(
            domain: "auth",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Network unavailable"]
        )
        sut.name = "Alice"
        sut.phoneNumber = "555-1234"

        sut.loginTapped()
        await waitUntil("error surfaced") { self.sut.showError }

        XCTAssertEqual(sut.errorMessage, "Network unavailable")
        XCTAssertTrue(friendRepository.savedProfiles.isEmpty)
        XCTAssertFalse(sut.isLoading)
    }

    func test_loginTapped_saveProfileFailure_showsError() async {
        friendRepository.saveProfileError = NSError(
            domain: "firestore",
            code: 7,
            userInfo: [NSLocalizedDescriptionKey: "Permission denied"]
        )
        sut.name = "Alice"
        sut.phoneNumber = "555-1234"

        sut.loginTapped()
        await waitUntil("error surfaced") { self.sut.showError }

        XCTAssertEqual(sut.errorMessage, "Permission denied")
        XCTAssertFalse(sut.isLoading)
    }

    func test_loginTapped_updateDisplayNameFailure_showsError() async {
        authRepository.updateDisplayNameError = NSError(
            domain: "auth",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Rename failed"]
        )
        sut.name = "Alice"
        sut.phoneNumber = "555-1234"

        sut.loginTapped()
        await waitUntil("error surfaced") { self.sut.showError }

        XCTAssertEqual(sut.errorMessage, "Rename failed")
        XCTAssertTrue(friendRepository.savedProfiles.isEmpty)
    }

    // MARK: - Debug Test Users

    func test_loginAsTestUser_signsInWithWhitelistedNumber() async {
        sut.loginAsTestUser(index: 0)
        await waitUntil("test user signed in") { !self.friendRepository.savedProfiles.isEmpty }

        XCTAssertEqual(authRepository.testUserPhoneNumbers, ["+15550000001"])
        XCTAssertEqual(friendRepository.savedProfiles.first?.displayName, "Test User 1")
        XCTAssertFalse(sut.isLoading)
    }

    func test_loginAsTestUser_usesIndexedNameAndNumber() async {
        sut.loginAsTestUser(index: 2)
        await waitUntil("test user signed in") { !self.friendRepository.savedProfiles.isEmpty }

        XCTAssertEqual(authRepository.testUserPhoneNumbers, ["+15550000003"])
        XCTAssertEqual(friendRepository.savedProfiles.first?.displayName, "Test User 3")
    }

    func test_loginAsTestUser_outOfRangeIndex_doesNothing() async {
        sut.loginAsTestUser(index: 99)

        XCTAssertTrue(authRepository.testUserPhoneNumbers.isEmpty)
        XCTAssertTrue(friendRepository.savedProfiles.isEmpty)
        XCTAssertFalse(sut.isLoading)
    }

    func test_loginAsTestUser_failure_showsError() async {
        authRepository.signInError = NSError(
            domain: "auth",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Test sign-in blocked"]
        )

        sut.loginAsTestUser(index: 1)
        await waitUntil("error surfaced") { self.sut.showError }

        XCTAssertEqual(sut.errorMessage, "Test sign-in blocked")
        XCTAssertFalse(sut.isLoading)
    }
}
