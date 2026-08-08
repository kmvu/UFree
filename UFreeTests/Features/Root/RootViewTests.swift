//
//  RootViewTests.swift
//  UFreeTests
//

import SwiftUI
import XCTest
@testable import UFree

@MainActor
final class MainAppViewTests: XCTestCase {

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

    private func makeView(user: User = User(id: "me", isAnonymous: false, displayName: "Alice")) -> some View {
        MainAppView(
            authRepository: scene.authRepository,
            rootViewModel: scene.rootViewModel,
            user: user,
            friendRepository: scene.friendRepository,
            scheduleViewModel: scene.scheduleViewModel,
            friendsScheduleViewModel: scene.friendsScheduleViewModel,
            friendsViewModel: scene.friendsViewModel,
            notificationViewModel: scene.notificationViewModel
        )
    }

    // MARK: - Tabs

    func test_render_scheduleTab() async {
        scene.rootViewModel.activeTab = .schedule

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_feedTab() async {
        scene.rootViewModel.activeTab = .feed
        scene.addFriendSchedules(count: 2, status: .free)

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    func test_render_friendsTab() async {
        scene.rootViewModel.activeTab = .friends

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    // MARK: - Deep Link Sheet

    func test_render_withDeepLinkProfileId_presentsProfileSheet() async {
        scene.friendRepository.addUser(UserProfile(id: "u1", displayName: "Alice"))
        scene.rootViewModel.deepLinkProfileId = "u1"

        await ViewHost.renderAwaitingUpdates(makeView())
    }

    // MARK: - Regular-Width Sidebar Layout

    /// `MainAppView` switches to a `NavigationSplitView` at regular width. Overriding the
    /// size class in the environment is what selects that branch — the hosting window is
    /// always compact at iPhone dimensions.
    private func makeSidebarView() -> some View {
        makeView().environment(\.horizontalSizeClass, .regular)
    }

    func test_render_regularWidth_scheduleTab_usesSidebarLayout() async {
        scene.rootViewModel.activeTab = .schedule

        await ViewHost.renderAwaitingUpdates(makeSidebarView(), size: ViewHost.regularPadSize)
    }

    func test_render_regularWidth_feedTab_usesSidebarLayout() async {
        scene.rootViewModel.activeTab = .feed
        scene.addFriendSchedules(count: 2, status: .free)

        await ViewHost.renderAwaitingUpdates(makeSidebarView(), size: ViewHost.regularPadSize)
    }

    func test_render_regularWidth_friendsTab_usesSidebarLayout() async {
        scene.rootViewModel.activeTab = .friends

        await ViewHost.renderAwaitingUpdates(makeSidebarView(), size: ViewHost.regularPadSize)
    }
}

// MARK: - Profile Resolution

@MainActor
final class ProfileResolutionViewTests: XCTestCase {

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

    func test_render_withResolvableUser_showsProfileAndRequestButton() async {
        scene.friendRepository.addUser(UserProfile(id: "u1", displayName: "Alice"))

        await ViewHost.renderAwaitingUpdates(
            ProfileResolutionView(userId: "u1", friendsViewModel: scene.friendsViewModel)
        )
    }

    func test_render_withUnknownUser_showsNotFoundState() async {
        await ViewHost.renderAwaitingUpdates(
            ProfileResolutionView(userId: "missing", friendsViewModel: scene.friendsViewModel)
        )
    }

    func test_render_whileProcessing_disablesRequestButton() async {
        scene.friendRepository.addUser(UserProfile(id: "u1", displayName: "Alice"))
        scene.friendsViewModel.isProcessing = true

        await ViewHost.renderAwaitingUpdates(
            ProfileResolutionView(userId: "u1", friendsViewModel: scene.friendsViewModel)
        )
    }
}

// MARK: - Deep Link Parsing

@MainActor
final class DeepLinkTests: XCTestCase {

    func test_parse_notificationLink() {
        let link = DeepLink.parse(URL(string: "https://ufree.app/notification/user123")!)

        guard case .notification(let senderId) = link else {
            return XCTFail("Expected a notification deep link, got \(link)")
        }
        XCTAssertEqual(senderId, "user123")
    }

    func test_parse_profileLink() {
        let link = DeepLink.parse(URL(string: "https://ufree.app/profile/user123")!)

        guard case .profile(let userId) = link else {
            return XCTFail("Expected a profile deep link, got \(link)")
        }
        XCTAssertEqual(userId, "user123")
    }

    func test_parse_unknownPathType() {
        let link = DeepLink.parse(URL(string: "https://ufree.app/settings/theme")!)

        guard case .unknown = link else {
            return XCTFail("Expected an unknown deep link, got \(link)")
        }
    }

    func test_parse_tooFewPathComponents() {
        let link = DeepLink.parse(URL(string: "https://ufree.app/profile")!)

        guard case .unknown = link else {
            return XCTFail("Expected an unknown deep link, got \(link)")
        }
    }

    func test_parse_rootUrl() {
        let link = DeepLink.parse(URL(string: "https://ufree.app/")!)

        guard case .unknown = link else {
            return XCTFail("Expected an unknown deep link, got \(link)")
        }
    }
}

// MARK: - String Identifiable Conformance

@MainActor
final class StringIdentifiableTests: XCTestCase {

    func test_id_isTheStringItself() {
        XCTAssertEqual("user123".id, "user123")
    }
}
