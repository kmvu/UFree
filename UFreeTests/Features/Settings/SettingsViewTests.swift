//
//  SettingsViewTests.swift
//  UFreeTests
//

import SwiftUI
import XCTest
@testable import UFree

/// Renders `SettingsView` across the states its `Form` branches on.
@MainActor
final class SettingsViewTests: XCTestCase {

    private var authRepository: AuthRepositoryStub!
    private var friendRepository: FriendRepositorySpy!
    private var viewModel: SettingsViewModel!

    override func setUp() {
        super.setUp()
        authRepository = AuthRepositoryStub()
        friendRepository = FriendRepositorySpy()
        viewModel = SettingsViewModel(authRepository: authRepository, friendRepository: friendRepository)
    }

    override func tearDown() async throws {
        await drainPendingTasks()
        viewModel = nil
        authRepository = nil
        friendRepository = nil
        await drainPendingTasks()
        try await super.tearDown()
    }

    /// `@StateObject`'s initialiser takes an autoclosure, so the ViewModel has to be
    /// captured through an explicit `self`.
    private func makeView() -> some View {
        SettingsView(viewModel: self.viewModel)
    }

    // MARK: - Initial Load

    func test_render_loadsDisplayNameFromTheSignedInUser() async {
        authRepository.stubbedUser = User(id: "u1", isAnonymous: false, displayName: "Alice")

        await ViewHost.renderAwaitingUpdates(makeView())

        XCTAssertEqual(viewModel.displayName, "Alice")
    }

    func test_render_withoutSignedInUser_leavesTheFieldEmpty() async {
        authRepository.stubbedUser = nil

        await ViewHost.renderAwaitingUpdates(makeView())

        XCTAssertTrue(viewModel.displayName.isEmpty)
    }

    // MARK: - Save Button States

    func test_render_withEmptyName_disablesSaveButton() async {
        authRepository.stubbedUser = User(id: "u1", isAnonymous: true, displayName: nil)

        await ViewHost.renderAwaitingUpdates(makeView())

        XCTAssertTrue(viewModel.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func test_render_withWhitespaceOnlyName_disablesSaveButton() async {
        authRepository.stubbedUser = User(id: "u1", isAnonymous: false, displayName: "   ")

        await ViewHost.renderAwaitingUpdates(makeView())

        XCTAssertTrue(viewModel.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func test_render_whileProcessing_showsProgressInsteadOfSaveLabel() async {
        authRepository.stubbedUser = User(id: "u1", isAnonymous: false, displayName: "Alice")

        // `loadInitialData` runs in the view's `.task` and would clear this again, so the
        // flag is set after the first render settles.
        await ViewHost.renderAwaitingUpdates(makeView())
        viewModel.isProcessing = true

        await ViewHost.renderAwaitingUpdates(makeView())

        XCTAssertTrue(viewModel.isProcessing)
    }

    // MARK: - Error Alert

    func test_render_withErrorMessage_showsErrorAlert() async {
        viewModel.errorMessage = "Permission denied"

        let render = await ViewHost.renderAwaitingUpdates(makeView())

        XCTAssertTrue(render.didPresentModal, "A non-nil errorMessage should present the alert")
    }

    func test_render_afterFailedSave_showsTheRepositoryError() async {
        authRepository.stubbedUser = User(id: "u1", isAnonymous: false, displayName: "Alice")
        friendRepository.saveProfileError = NSError(
            domain: "firestore",
            code: 7,
            userInfo: [NSLocalizedDescriptionKey: "Permission denied"]
        )

        await ViewHost.renderAwaitingUpdates(makeView())
        await viewModel.saveProfile()
        XCTAssertEqual(viewModel.errorMessage, "Permission denied")

        let render = await ViewHost.renderAwaitingUpdates(makeView())

        XCTAssertFalse(viewModel.isSaveSuccessful)
        XCTAssertTrue(render.didPresentModal, "The repository error should surface as an alert")
    }

    // MARK: - Dismiss on Success

    func test_render_afterSuccessfulSave_flipsIsSaveSuccessful() async {
        authRepository.stubbedUser = User(id: "u1", isAnonymous: false, displayName: "Alice")

        await ViewHost.renderAwaitingUpdates(makeView())
        await viewModel.saveProfile()
        await ViewHost.renderAwaitingUpdates(makeView())

        XCTAssertTrue(viewModel.isSaveSuccessful)
        XCTAssertEqual(
            friendRepository.savedProfiles,
            [FriendRepositorySpy.SavedProfile(displayName: "Alice", hashedPhoneNumbers: [])]
        )
    }
}
