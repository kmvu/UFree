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
    private var wipeCallCount = 0

    override func setUp() {
        super.setUp()
        authRepository = AuthRepositoryStub()
        friendRepository = FriendRepositorySpy()
        wipeCallCount = 0
        sut = SettingsViewModel(
            authRepository: authRepository,
            friendRepository: friendRepository,
            wipeLocalData: { [weak self] in
                self?.wipeCallCount += 1
            }
        )
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
        XCTAssertFalse(sut.isDeleteSuccessful)
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
        XCTAssertTrue(authRepository.updatedDisplayNames.isEmpty)
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

    func test_saveProfile_success_syncsAuthAndFirestoreDisplayName() async {
        sut.displayName = "Alice"

        await sut.saveProfile()

        XCTAssertEqual(authRepository.updatedDisplayNames, ["Alice"])
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

    // MARK: - Account deletion

    func test_deleteAccount_success_wipesCloudAuthAndLocal() async {
        authRepository.stubbedUser = User(id: "u1", isAnonymous: false, displayName: "Alice")

        await sut.deleteAccount()

        XCTAssertEqual(authRepository.reauthenticateCallCount, 1)
        XCTAssertEqual(friendRepository.deleteAccountDataCallCount, 1)
        XCTAssertEqual(authRepository.deleteAccountCallCount, 1)
        XCTAssertEqual(wipeCallCount, 1)
        XCTAssertTrue(sut.isDeleteSuccessful)
        XCTAssertFalse(sut.isProcessing)
    }

    func test_deleteAccount_anonymousDebugUser_skipsAppleReauth() async {
        authRepository.stubbedUser = User(id: "u1", isAnonymous: true, displayName: "Test User 1")

        await sut.deleteAccount()

        #if DEBUG
        XCTAssertEqual(authRepository.reauthenticateCallCount, 0)
        #else
        XCTAssertEqual(authRepository.reauthenticateCallCount, 1)
        #endif
        XCTAssertEqual(friendRepository.deleteAccountDataCallCount, 1)
        XCTAssertTrue(sut.isDeleteSuccessful)
    }

    func test_deleteAccount_firestoreFailure_surfacesError() async {
        authRepository.stubbedUser = User(id: "u1", isAnonymous: false, displayName: "Alice")
        friendRepository.deleteAccountDataError = NSError(
            domain: "firestore",
            code: 7,
            userInfo: [NSLocalizedDescriptionKey: "Delete denied"]
        )

        await sut.deleteAccount()

        XCTAssertEqual(sut.errorMessage, "Delete denied")
        XCTAssertEqual(authRepository.deleteAccountCallCount, 0)
        XCTAssertEqual(wipeCallCount, 0)
        XCTAssertFalse(sut.isDeleteSuccessful)
    }

    func test_deleteAccount_reauthenticateError_surfacesErrorWithoutDeleting() async {
        authRepository.stubbedUser = User(id: "u1", isAnonymous: false, displayName: "Alice")
        authRepository.reauthenticateError = NSError(
            domain: "auth",
            code: 17014,
            userInfo: [NSLocalizedDescriptionKey: "Re-auth failed"]
        )

        await sut.deleteAccount()

        XCTAssertEqual(authRepository.reauthenticateCallCount, 1)
        XCTAssertEqual(friendRepository.deleteAccountDataCallCount, 0)
        XCTAssertEqual(authRepository.deleteAccountCallCount, 0)
        XCTAssertEqual(wipeCallCount, 0)
        XCTAssertEqual(sut.errorMessage, "Re-auth failed")
        XCTAssertFalse(sut.isDeleteSuccessful)
        XCTAssertFalse(sut.isProcessing)
    }

    func test_deleteAccount_appleCancel_clearsProcessingWithoutError() async {
        authRepository.stubbedUser = User(id: "u1", isAnonymous: false, displayName: "Alice")
        authRepository.reauthenticateError = AppleSignInError.cancelled

        await sut.deleteAccount()

        XCTAssertEqual(authRepository.reauthenticateCallCount, 1)
        XCTAssertEqual(friendRepository.deleteAccountDataCallCount, 0)
        XCTAssertEqual(authRepository.deleteAccountCallCount, 0)
        XCTAssertEqual(wipeCallCount, 0)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isDeleteSuccessful)
        XCTAssertFalse(sut.isProcessing)
    }

    func test_deleteAccount_authDeleteFailure_surfacesErrorWithoutLocalWipe() async {
        authRepository.stubbedUser = User(id: "u1", isAnonymous: false, displayName: "Alice")
        authRepository.deleteAccountError = NSError(
            domain: "auth",
            code: 17000,
            userInfo: [NSLocalizedDescriptionKey: "Auth delete failed"]
        )

        await sut.deleteAccount()

        XCTAssertEqual(friendRepository.deleteAccountDataCallCount, 1)
        XCTAssertEqual(authRepository.deleteAccountCallCount, 1)
        XCTAssertEqual(wipeCallCount, 0)
        XCTAssertEqual(sut.errorMessage, "Auth delete failed")
        XCTAssertFalse(sut.isDeleteSuccessful)
        XCTAssertFalse(sut.isProcessing)
    }
}
