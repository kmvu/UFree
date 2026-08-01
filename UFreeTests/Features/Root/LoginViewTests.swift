//
//  LoginViewTests.swift
//  UFreeTests
//

import SwiftUI
import XCTest
@testable import UFree

@MainActor
final class LoginViewTests: XCTestCase {

    private var authRepository: AuthRepositoryStub!
    private var friendRepository: FriendRepositorySpy!
    private var viewModel: LoginViewModel!

    override func setUp() {
        super.setUp()
        authRepository = AuthRepositoryStub()
        friendRepository = FriendRepositorySpy()
        viewModel = LoginViewModel(authRepository: authRepository, friendRepository: friendRepository)
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
    /// captured through an explicit `self` rather than passed inline at each call site.
    private func makeView() -> some View {
        LoginView(viewModel: self.viewModel)
    }

    func test_render_emptyForm_showsDisabledCallToAction() async {
        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withNameOnly_keepsCallToActionDisabled() async {
        viewModel.name = "Alice"

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withCompleteForm_enablesCallToAction() async {
        viewModel.name = "Alice"
        viewModel.phoneNumber = "555-1234"

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_whileLoading_showsProgressIndicator() async {
        viewModel.name = "Alice"
        viewModel.phoneNumber = "555-1234"
        viewModel.isLoading = true

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withError_showsFailureAlert() async {
        viewModel.errorMessage = "Please enter your name to start."
        viewModel.showError = true

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withErrorFlagButNoMessage_showsFallbackCopy() async {
        viewModel.showError = true

        await ViewHost.renderAwaitingUpdates(makeView())
    }
}

// MARK: - Splash

@MainActor
final class SplashViewTests: XCTestCase {

    func test_render_splashScreen() async {
        await ViewHost.renderAwaitingUpdates(SplashView())
    }
}
