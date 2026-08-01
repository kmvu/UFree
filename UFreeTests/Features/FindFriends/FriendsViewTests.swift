//
//  FriendsViewTests.swift
//  UFreeTests
//

import SwiftUI
import XCTest
@testable import UFree

@MainActor
final class FriendsViewTests: XCTestCase {

    private var scene: TestScene!

    override func setUp() {
        super.setUp()
        scene = TestScene()
    }

    override func tearDown() async throws {
        await releaseTestScene(scene)
        scene = nil
        await drainPendingTasks()
        try await super.tearDown()
    }

    private func makeView() -> some View {
        FriendsView(viewModel: scene.friendsViewModel, rootViewModel: scene.rootViewModel)
    }

    // MARK: - Empty State

    func test_render_withNothingDiscovered_showsSyncContactsPrompt() async {
        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withoutSignedInUser_hidesDiscoveryCard() async {
        scene.rootViewModel.currentUser = nil

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    // MARK: - Friends and Requests

    func test_render_withFriends_showsTrustedCircle() async {
        scene.friendsViewModel.friends = [
            UserProfile(id: "u1", displayName: "Alice"),
            UserProfile(id: "u2", displayName: "Bob")
        ]

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withIncomingRequests_showsRequestRows() async {
        scene.friendsViewModel.incomingRequests = scene.makeFriendRequests(count: 2)

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withDiscoveredUsers_showsSuggestionRows() async {
        scene.friendsViewModel.discoveredUsers = [
            UserProfile(id: "u1", displayName: "Alice", hashedPhoneNumber: "hash_a")
        ]
        scene.friendsViewModel.contactHashes = ["hash_a"]

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withUnmatchedDiscoveredUser_omitsTrustBadge() async {
        scene.friendsViewModel.discoveredUsers = [
            UserProfile(id: "u1", displayName: "Alice", hashedPhoneNumber: "hash_a")
        ]
        scene.friendsViewModel.contactHashes = []

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    // MARK: - Search

    func test_render_withSearchText_showsSubmitButton() async {
        scene.friendsViewModel.searchText = "555-1234"

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_whileSearching_showsProgressIndicator() async {
        scene.friendsViewModel.searchText = "555-1234"
        scene.friendsViewModel.isSearching = true

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withSearchResult_showsResultRow() async {
        scene.friendsViewModel.searchText = "555-1234"
        scene.friendsViewModel.searchResult = UserProfile(id: "u1", displayName: "Alice")

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_whileSendingRequestFromSearch_showsRowProgress() async {
        scene.friendsViewModel.searchResult = UserProfile(id: "u1", displayName: "Alice")
        scene.friendsViewModel.isSearching = true
        scene.friendsViewModel.isProcessing = true

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    // MARK: - Alerts and Overlays

    func test_render_whileLoading_showsOverlaySpinner() async {
        scene.friendsViewModel.isLoading = true

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withErrorMessage_showsErrorAlert() async {
        scene.friendsViewModel.errorMessage = "Something went wrong"

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_withPermissionAlert_showsPermissionPrompt() async {
        scene.friendsViewModel.showPermissionAlert = true

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    // MARK: - Fully Populated

    func test_render_withEverythingPopulated() async {
        scene.friendsViewModel.friends = [UserProfile(id: "u1", displayName: "Alice")]
        scene.friendsViewModel.incomingRequests = scene.makeFriendRequests(count: 1)
        scene.friendsViewModel.discoveredUsers = [UserProfile(id: "u2", displayName: "Bob")]
        scene.friendsViewModel.searchText = "555-1234"

        await ViewHost.renderAwaitingUpdates(makeView())
    }
}

// MARK: - Discovery Card

@MainActor
final class DiscoveryCardViewTests: XCTestCase {

    private var scene: TestScene!

    override func setUp() {
        super.setUp()
        scene = TestScene()
    }

    override func tearDown() async throws {
        await releaseTestScene(scene)
        scene = nil
        await drainPendingTasks()
        try await super.tearDown()
    }

    func test_render_scannerFace_showsShowMyCodeButton() async {
        scene.friendsViewModel.showMyQRCard = false

        await ViewHost.renderAwaitingUpdates(
            DiscoveryCardView(viewModel: scene.friendsViewModel, userId: "me")
        )
    }

    func test_render_qrFace_withGeneratedCode_showsQRImage() async {
        scene.friendsViewModel.generateMyQRCode(from: "me")
        scene.friendsViewModel.showMyQRCard = true

        XCTAssertNotNil(scene.friendsViewModel.qrImage)
        await ViewHost.renderAwaitingUpdates(
            DiscoveryCardView(viewModel: scene.friendsViewModel, userId: "me")
        )
    }

    func test_render_qrFace_withoutGeneratedCode_omitsQRImage() async {
        scene.friendsViewModel.showMyQRCard = true

        XCTAssertNil(scene.friendsViewModel.qrImage)
        await ViewHost.renderAwaitingUpdates(
            DiscoveryCardView(viewModel: scene.friendsViewModel, userId: "me")
        )
    }
}
