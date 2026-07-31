//
//  SettingsViewModelTests.swift
//  UFreeTests
//

import XCTest
@testable import UFree

@MainActor
final class SettingsViewModelTests: XCTestCase {

    private var authRepository: AuthRepositoryStub!
    private var friendRepository: FriendRepositorySpy!
    private var sut: SettingsViewModel!

    override func setUp() {
        super.setUp()
        authRepository = AuthRepositoryStub()
        friendRepository = FriendRepositorySpy()
        sut = SettingsViewModel(authRepository: authRepository, friendRepository: friendRepository)
        trackForMemoryLeaks(sut)
    }

    override func tearDown() {
        sut = nil
        authRepository = nil
        friendRepository = nil
        verifyNoMemoryLeaks()
        super.tearDown()
    }

    // MARK: - Initial Load

    func test_init_stateIsEmpty() {
        XCTAssertTrue(sut.displayName.isEmpty)
        XCTAssertFalse(sut.isProcessing)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isSaveSuccessful)
    }

    func test_loadInitialData_populatesDisplayNameFromCurrentUser() async {
        authRepository.stubbedUser = User(id: "u1", isAnonymous: false, displayName: "Alice")

        await sut.loadInitialData()

        XCTAssertEqual(sut.displayName, "Alice")
    }

    func test_loadInitialData_noSignedInUser_leavesDisplayNameEmpty() async {
        authRepository.stubbedUser = nil

        await sut.loadInitialData()

        XCTAssertTrue(sut.displayName.isEmpty)
    }

    func test_loadInitialData_userWithoutDisplayName_leavesDisplayNameEmpty() async {
        authRepository.stubbedUser = User(id: "u1", isAnonymous: true, displayName: nil)

        await sut.loadInitialData()

        XCTAssertTrue(sut.displayName.isEmpty)
    }

    // MARK: - Validation

    func test_saveProfile_emptyDisplayName_setsErrorWithoutSaving() async {
        await sut.saveProfile()

        XCTAssertEqual(sut.errorMessage, "Please enter a display name")
        XCTAssertFalse(sut.isSaveSuccessful)
        XCTAssertTrue(friendRepository.savedProfiles.isEmpty)
    }

    func test_saveProfile_whitespaceOnlyDisplayName_setsError() async {
        sut.displayName = "  \n "

        await sut.saveProfile()

        XCTAssertEqual(sut.errorMessage, "Please enter a display name")
        XCTAssertTrue(friendRepository.savedProfiles.isEmpty)
    }

    func test_saveProfile_whileAlreadyProcessing_isIgnored() async {
        sut.displayName = "Alice"
        sut.isProcessing = true

        await sut.saveProfile()

        XCTAssertTrue(friendRepository.savedProfiles.isEmpty)
        XCTAssertFalse(sut.isSaveSuccessful)
    }

    // MARK: - Save

    func test_saveProfile_success_marksSaveSuccessful() async {
        sut.displayName = "Alice"

        await sut.saveProfile()

        XCTAssertTrue(sut.isSaveSuccessful)
        XCTAssertFalse(sut.isProcessing)
        XCTAssertNil(sut.errorMessage)
    }

    func test_saveProfile_success_preservesExistingHashesBySendingEmptyArray() async {
        sut.displayName = "Alice"

        await sut.saveProfile()

        XCTAssertEqual(
            friendRepository.savedProfiles,
            [FriendRepositorySpy.SavedProfile(displayName: "Alice", hashedPhoneNumbers: [])]
        )
    }

    func test_saveProfile_failure_setsErrorAndClearsProcessing() async {
        sut.displayName = "Alice"
        friendRepository.saveProfileError = NSError(
            domain: "firestore",
            code: 7,
            userInfo: [NSLocalizedDescriptionKey: "Permission denied"]
        )

        await sut.saveProfile()

        XCTAssertEqual(sut.errorMessage, "Permission denied")
        XCTAssertFalse(sut.isSaveSuccessful)
        XCTAssertFalse(sut.isProcessing)
    }

    func test_saveProfile_clearsPreviousErrorOnRetry() async {
        sut.displayName = "Alice"
        friendRepository.saveProfileError = NSError(domain: "firestore", code: 7)
        await sut.saveProfile()
        XCTAssertNotNil(sut.errorMessage)

        friendRepository.saveProfileError = nil
        await sut.saveProfile()

        XCTAssertNil(sut.errorMessage)
        XCTAssertTrue(sut.isSaveSuccessful)
    }
}
