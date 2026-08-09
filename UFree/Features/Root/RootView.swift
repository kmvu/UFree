//
//  RootView.swift
//  UFree
//
//  Created by Khang Vu on 31/12/25.
//

import SwiftUI
import SwiftData

struct RootView: View {
    let container: ModelContainer
    let authRepository: AuthRepository

    @StateObject private var rootViewModel: RootViewModel
    @StateObject private var scheduleViewModel: MyScheduleViewModel
    @StateObject private var friendsScheduleViewModel: FriendsScheduleViewModel
    @StateObject private var friendsViewModel: FriendsViewModel
    @StateObject private var notificationViewModel: NotificationViewModel
    let friendRepository: FriendRepositoryProtocol

    init(container: ModelContainer, authRepository: AuthRepository) {
        self.container = container
        self.authRepository = authRepository

        // 1. Setup Repositories
        let availabilityRepo = CompositeAvailabilityRepository(
            local: SwiftDataAvailabilityRepository(container: container),
            remote: FirebaseAvailabilityRepository()
        )
        let friendRepo = FirebaseFriendRepository()
        self.friendRepository = friendRepo
        let notificationRepo = FirebaseNotificationRepository()

        // 2. Instantiate ViewModels (Non-StateObject versions for injection)
        let scheduleVM = MyScheduleViewModel(
            updateUseCase: UpdateMyStatusUseCase(repository: availabilityRepo),
            repository: availabilityRepo
        )
        let friendsScheduleVM = FriendsScheduleViewModel(
            friendRepository: friendRepo,
            availabilityRepository: availabilityRepo,
            notificationRepository: notificationRepo
        )
        let friendsVM = FriendsViewModel(friendRepository: friendRepo)
        let notificationVM = NotificationViewModel(repository: notificationRepo)
        let rootVM = RootViewModel(authRepository: authRepository)

        // 3. Inject dependencies into Root
        rootVM.friendsScheduleViewModel = friendsScheduleVM
        rootVM.friendsViewModel = friendsVM
        notificationVM.bind(
            friendsViewModel: friendsVM,
            scheduleViewModel: scheduleVM,
            rootViewModel: rootVM
        )

        // 4. Wrap in StateObjects for SwiftUI lifecycle
        _rootViewModel = StateObject(wrappedValue: rootVM)
        _scheduleViewModel = StateObject(wrappedValue: scheduleVM)
        _friendsScheduleViewModel = StateObject(wrappedValue: friendsScheduleVM)
        _friendsViewModel = StateObject(wrappedValue: friendsVM)
        _notificationViewModel = StateObject(wrappedValue: notificationVM)
    }

    var body: some View {
        Group {
            switch rootViewModel.authPhase {
            case .loading:
                SplashView()
                    .transition(.opacity)

            case .unauthenticated:
                LoginView(viewModel: LoginViewModel(
                    authRepository: authRepository,
                    friendRepository: friendRepository
                ))
                    .transition(.opacity)

            case .authenticated:
                // Wait for displayName to be available before showing main app
                if let user = rootViewModel.currentUser,
                   let displayName = user.displayName, !displayName.isEmpty {
                    MainAppView(
                        authRepository: authRepository,
                        rootViewModel: rootViewModel,
                        user: user,
                        friendRepository: friendRepository,
                        scheduleViewModel: scheduleViewModel,
                        friendsScheduleViewModel: friendsScheduleViewModel,
                        friendsViewModel: friendsViewModel,
                        notificationViewModel: notificationViewModel
                    )
                    .transition(.opacity)
                } else {
                    // Still waiting for displayName to load
                    SplashView()
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeOut(duration: 0.3), value: rootViewModel.authPhase)
        .animation(.easeOut(duration: 0.3), value: rootViewModel.currentUser?.displayName)
        .onChange(of: rootViewModel.authPhase) { oldPhase, newPhase in
            if newPhase == .authenticated {
                Task {
                    await friendsScheduleViewModel.loadFriendsSchedules()
                    await friendsViewModel.loadFriends()
                }
            }
        }
    }
}

// MARK: - Main App View (after login)

struct MainAppView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    let authRepository: AuthRepository
    @ObservedObject var rootViewModel: RootViewModel
    let user: User
    let friendRepository: FriendRepositoryProtocol
    let scheduleViewModel: MyScheduleViewModel
    let friendsScheduleViewModel: FriendsScheduleViewModel
    let friendsViewModel: FriendsViewModel
    @ObservedObject var notificationViewModel: NotificationViewModel
    @ObservedObject private var onboardingStore = OnboardingProgressStore.shared

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                adaptiveSidebarLayout
            } else {
                tabBarLayout
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if verticalSizeClass != .compact {
                if rootViewModel.showPairOnboardingBanner
                    && rootViewModel.activeTab == .feed
                    && onboardingStore.shouldShowPairOnboardingBanner(friendCount: friendsViewModel.friends.count) {
                    PairOnboardingBannerView(
                        title: onboardingStore.pairOnboardingBannerTitle,
                        subtitle: onboardingStore.pairOnboardingBannerSubtitle,
                        onTap: {
                            rootViewModel.showPairOnboardingSheet = true
                        }
                    )
                } else if onboardingStore.shouldShowPostConnectCoach
                    && (rootViewModel.activeTab == .feed || rootViewModel.activeTab == .schedule) {
                    PostConnectMissionChipView(
                        title: OnboardingProgressStore.postConnectMissionTitle,
                        subtitle: postConnectMissionSubtitle,
                        onPrimary: { handlePostConnectMissionTap() },
                        onDismiss: {
                            rootViewModel.dismissPostConnectCoach(store: onboardingStore)
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $rootViewModel.showPairOnboardingSheet) {
            PairOnboardingChecklistView(
                hasInvited: onboardingStore.hasInvitedFriend,
                hasMarkedFree: onboardingStore.hasMarkedFreeDay,
                hasHandshake: onboardingStore.hasCompletedFirstHandshake,
                onInvite: {
                    rootViewModel.showPairOnboardingSheet = false
                    rootViewModel.activeTab = .friends
                },
                onMarkFree: {
                    rootViewModel.showPairOnboardingSheet = false
                    rootViewModel.activeTab = .schedule
                    rootViewModel.showWeekendCTA = true
                },
                onNotNow: {
                    rootViewModel.showPairOnboardingSheet = false
                },
                onDontShowAgain: {
                    onboardingStore.dismissPairChecklistPermanently()
                    rootViewModel.showPairOnboardingSheet = false
                    rootViewModel.showPairOnboardingBanner = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.regularMaterial)
        }
        .sheet(item: $rootViewModel.deepLinkProfileId) { userId in
            // Profile Card View for Deep Links
            VStack(spacing: 20) {
                ProfileResolutionView(userId: userId, friendsViewModel: friendsViewModel)
                
                Button("Cancel") { rootViewModel.deepLinkProfileId = nil }.foregroundStyle(.secondary)
            }
            .padding()
            .adaptiveContentWidth(AdaptiveLayout.formContentMaxWidth)
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $rootViewModel.showWeekendCTA) {
            WeekendFreePromptView(
                onMarkWeekendFree: {
                    Task {
                        await scheduleViewModel.markWeekendFree()
                        OnboardingProgressStore.shared.consumeWeekendCTA()
                        rootViewModel.showWeekendCTA = false
                        rootViewModel.activeTab = .feed
                        onboardingStore.activatePostConnectCoach()
                    }
                },
                onDismiss: {
                    OnboardingProgressStore.shared.consumeWeekendCTA()
                    rootViewModel.showWeekendCTA = false
                    // Stay on Schedule with a soft next-mission chip.
                    rootViewModel.activeTab = .schedule
                    onboardingStore.activatePostConnectCoach()
                }
            )
            .adaptiveContentWidth(AdaptiveLayout.formContentMaxWidth)
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $notificationViewModel.showNotificationCenter) {
            NotificationCenterView(viewModel: notificationViewModel)
                .adaptiveNotificationCenterPresentation()
        }
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                if let banner = notificationViewModel.incomingBanner {
                    NotificationBannerView(notification: banner) {
                        notificationViewModel.handleIncomingBannerTap()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let toast = rootViewModel.celebrationToast {
                    Text(toast)
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
        .animation(
            .spring(response: 0.35, dampingFraction: 0.86),
            value: notificationViewModel.incomingBanner.map {
                "\($0.senderId)-\($0.type.rawValue)-\($0.date.timeIntervalSince1970)"
            }
        )
        .animation(.easeInOut(duration: 0.25), value: rootViewModel.celebrationToast)
        .environment(\.notificationViewModel, notificationViewModel)
        .onOpenURL { url in
            handleUniversalLink(url)
        }
        .onAppear {
            wireHandshakeCallback()
            friendsViewModel.listenToRequests()
            friendsViewModel.listenToFriends()
            onboardingStore.trackReopenIfNeeded()
            Task {
                if friendsViewModel.friends.isEmpty {
                    await friendsViewModel.loadFriends()
                }
                syncPairChecklistVisibility()
            }
            // Present pending weekend CTA only when no celebration toast is active
            // (avoids stacking with first-connection toast).
            if onboardingStore.shouldPresentWeekendCTAAfterConnection,
               rootViewModel.celebrationToast == nil {
                rootViewModel.showWeekendCTA = true
            }
        }
        .onChange(of: friendsViewModel.friends.count) { oldCount, newCount in
            handleFriendsCountChange(from: oldCount, to: newCount)
        }
        .onChange(of: onboardingStore.hasInvitedFriend) { wasInvited, isInvited in
            if !wasInvited && isInvited {
                rootViewModel.presentOnboardingStepFeedback(
                    OnboardingProgressStore.inviteStepToastMessage
                )
            }
        }
        .onChange(of: onboardingStore.hasMarkedFreeDay) { wasMarked, isMarked in
            if !wasMarked && isMarked {
                rootViewModel.presentOnboardingStepFeedback(
                    OnboardingProgressStore.freeDayStepToastMessage
                )
            }
        }
    }

    private func handleFriendsCountChange(from oldCount: Int, to newCount: Int) {
        if onboardingStore.shouldCelebrateFirstConnection(
            previousFriendCount: oldCount,
            newFriendCount: newCount
        ) {
            onboardingStore.markFirstHandshake()
            let friendName = friendsViewModel.friends.first?.displayName
            rootViewModel.celebrateFirstConnection(friendName: friendName, store: onboardingStore)
            Task {
                await friendsScheduleViewModel.loadFriendsSchedules()
            }
            return
        }
        syncPairChecklistVisibility()
    }

    private func syncPairChecklistVisibility() {
        let friendCount = friendsViewModel.friends.count
        if friendCount > 0 {
            // Returning users / already-connected: sync progress without celebration.
            onboardingStore.acknowledgeExistingFriends()
            rootViewModel.showPairOnboardingBanner = false
            rootViewModel.showPairOnboardingSheet = false
            return
        }
        let show = onboardingStore.shouldShowPairOnboardingBanner(friendCount: friendCount)
        rootViewModel.showPairOnboardingBanner = show
        if !show {
            rootViewModel.showPairOnboardingSheet = false
        }
    }

    private func wireHandshakeCallback() {
        friendsViewModel.onAcceptCompleted = { friendName, wasFirstFriend in
            rootViewModel.handlePostAccept(
                friendName: friendName,
                wasFirstFriend: wasFirstFriend,
                store: onboardingStore
            )
            Task {
                await friendsScheduleViewModel.loadFriendsSchedules()
            }
        }
    }

    private var postConnectMissionSubtitle: String {
        if rootViewModel.activeTab == .schedule && !onboardingStore.hasMarkedFreeDay {
            return OnboardingProgressStore.postConnectMissionMarkFree
        }
        if let name = rootViewModel.postConnectFriendName,
           let friendId = friendsScheduleViewModel.friendId(named: name),
           let date = friendsScheduleViewModel.nextFreeDate(forFriendId: friendId) {
            let weekday = date.formatted(.dateTime.weekday(.abbreviated))
            return OnboardingProgressStore.postConnectNudgeMission(friendName: name, weekday: weekday)
        }
        if let name = rootViewModel.postConnectFriendName, !name.isEmpty {
            return "See when you and \(name) are free — then nudge a day."
        }
        return OnboardingProgressStore.postConnectMissionSeeBothFree
    }

    private func handlePostConnectMissionTap() {
        if rootViewModel.activeTab == .schedule && !onboardingStore.hasMarkedFreeDay {
            rootViewModel.showWeekendCTA = true
            return
        }

        rootViewModel.activeTab = .feed
        if let name = rootViewModel.postConnectFriendName,
           let friendId = friendsScheduleViewModel.friendId(named: name),
           let date = friendsScheduleViewModel.nextFreeDate(forFriendId: friendId) {
            friendsScheduleViewModel.focusDate(date)
            rootViewModel.missionFocusDate = date
        }
    }

    // MARK: - Layouts

    @ViewBuilder
    private var tabBarLayout: some View {
        TabView(selection: $rootViewModel.activeTab) {
            // MARK: - Schedule Tab
            NavigationStack {
                MyScheduleView(viewModel: scheduleViewModel, rootViewModel: rootViewModel)
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Schedule", systemImage: "calendar")
            }
            .tag(RootViewModel.Tab.schedule)

            // MARK: - Friends Feed Tab
            NavigationStack {
                FriendsScheduleView(
                    viewModel: friendsScheduleViewModel,
                    rootViewModel: rootViewModel
                )
                .navigationTitle("Who's Free?")
                .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Who's Free?", systemImage: "person.2.fill")
            }
            .tag(RootViewModel.Tab.feed)

            // MARK: - Add Friends Tab
            NavigationStack {
                FriendsView(
                    viewModel: friendsViewModel,
                    rootViewModel: rootViewModel
                )
                .navigationTitle("Friends")
                .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Add Friends", systemImage: "person.badge.plus")
            }
            .tag(RootViewModel.Tab.friends)
        }
    }

    @ViewBuilder
    private var adaptiveSidebarLayout: some View {
        NavigationSplitView {
            List(selection: Binding(
                get: { rootViewModel.activeTab },
                set: { if let newValue = $0 { rootViewModel.activeTab = newValue } }
            )) {
                NavigationLink(value: RootViewModel.Tab.schedule) {
                    Label("Schedule", systemImage: "calendar")
                }
                NavigationLink(value: RootViewModel.Tab.feed) {
                    Label("Who's Free?", systemImage: "person.2.fill")
                }
                NavigationLink(value: RootViewModel.Tab.friends) {
                    Label("Add Friends", systemImage: "person.badge.plus")
                }
            }
            .navigationTitle("UFree")
        } detail: {
            switch rootViewModel.activeTab {
            case .schedule:
                NavigationStack {
                    MyScheduleView(viewModel: scheduleViewModel, rootViewModel: rootViewModel)
                }
            case .feed:
                NavigationStack {
                    FriendsScheduleView(
                        viewModel: friendsScheduleViewModel,
                        rootViewModel: rootViewModel
                    )
                    .navigationTitle("Who's Free?")
                }
            case .friends:
                NavigationStack {
                    FriendsView(
                        viewModel: friendsViewModel,
                        rootViewModel: rootViewModel
                    )
                    .navigationTitle("Friends")
                }
            }
        }
    }
    
    // MARK: - Universal Links Handler
    
    /// Handles incoming Universal Links (App Site Association)
    /// Example: https://ufree.app/notification/user123
    private func handleUniversalLink(_ url: URL) {
        AnalyticsManager.logLinkOpened(url: url.absoluteString)
        let deepLink = DeepLink.parse(url)
        
        switch deepLink {
        case .notification(let userId):
            notificationViewModel.highlightedSenderId = userId
            notificationViewModel.openNotificationCenter()
            
        case .profile(let userId):
            // Trigger profile sheet via RootViewModel
            rootViewModel.deepLinkProfileId = userId
            
        case .unknown:
            print("Unknown deep link: \(url)")
        }
    }
}

// MARK: - Deep Link Parser

enum DeepLink {
    case notification(senderId: String)
    case profile(userId: String)
    case unknown
    
    /// Parses Universal Link URLs into navigation actions
    /// - Parameter url: Universal Link URL (e.g., https://ufree.app/notification/user123)
    static func parse(_ url: URL) -> DeepLink {
        let components = url.pathComponents.filter { $0 != "/" }
        
        guard components.count >= 2 else {
            return .unknown
        }
        
        let pathType = components[0]
        let parameter = components[1]
        
        switch pathType {
        case "notification":
            return .notification(senderId: parameter)
        case "profile":
            return .profile(userId: parameter)
        default:
            return .unknown
        }
    }
}

// MARK: - Profile Resolution for Deep Links

struct ProfileResolutionView: View {
    let userId: String
    @ObservedObject var friendsViewModel: FriendsViewModel
    @State private var resolvedUser: UserProfile?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView("Finding user...")
            } else if let user = resolvedUser {
                Circle().fill(Color.blue.opacity(0.1)).frame(width: 80, height: 80)
                    .overlay {
                        Text(String(user.displayName.prefix(1)))
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.blue)
                    }
                
                Text(user.displayName).font(.headline)
                Text("Connect on UFree").font(.subheadline).foregroundStyle(.secondary)
                
                Button("Send Friend Request") {
                    Task {
                        await friendsViewModel.sendFriendRequest(to: user, source: "deep_link")
                    }
                }
                .ufreePrimaryButton(isEnabled: !friendsViewModel.isProcessing)
                .disabled(friendsViewModel.isProcessing)
            } else {
                Image(systemName: "person.fill.questionmark")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                
                Text(errorMessage ?? "User not found").font(.headline)
                Text("The link might be invalid or the user may have deleted their account.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            await resolveUser()
        }
    }
    
    private func resolveUser() async {
        do {
            resolvedUser = try await friendsViewModel.friendRepository.findUserById(userId)
            isLoading = false
        } catch {
            errorMessage = "Failed to load profile"
            isLoading = false
        }
    }
}

#Preview {
    RootView(
        container: {
            do {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                return try ModelContainer(for: PersistentDayAvailability.self, configurations: config)
            } catch {
                fatalError("Failed to create preview container")
            }
        }(),
        authRepository: MockAuthRepository()
    )
}
