# UFree Agent Instructions

## CRITICAL: Path Format

**ALWAYS USE UNDERSCORES (NO SPACES)**

✅ CORRECT:
```
/Users/KhangVu/Documents/Development/git_project/Khang_business_projects/UFree
```

Use underscores instead of spaces to avoid escaping issues. This applies to all `create_file`, `Read`, `edit_file`, `Bash`, and other file operations.

---

## Project Structure

- **UFree/**: Main app source
- **UFreeTests/**: Unit tests
- **UFreeUITests/**: UI tests
- **Docs/**: Documentation

---

## Recent Work

- **Sprint 4 ✅ COMPLETE**: Two-Way Handshake & Phone Search
  - **Phone Search** (Privacy-Safe): findUserByPhoneNumber() with blind index pattern (clean → hash → Firestore). TextField with phonePad keyboard, clears after add, prevents self-add via Auth user ID check.
  - **Friend Requests** (Handshake): sendFriendRequest() creates pending. observeIncomingRequests() AsyncStream for real-time. acceptFriendRequest() with atomic batch write. declineFriendRequest() marks declined. View lifecycle: .task { listenToRequests() } on appear, .onDisappear { stopListening() } to save battery/data.
  - **Real-Time Listeners**: AsyncStream pattern instead of Combine. Proper cleanup on task cancellation.
  - **Privacy-First**: Schedule visibility only after both parties consent.
  - **Haptics**: medium() on search/send, success() on accept, warning() on decline.
  - **Tests Optimized**: 15+ focused unit tests (phone search workflows, handshake scenarios, observation, lifecycle).
  - **Files**: FriendRequest.swift, FriendRepository.swift (protocol + Firebase), FriendsViewModel.swift, FriendsView.swift, MockFriendRepository.swift, FriendsViewModelTests.swift, FriendsHandshakeTests.swift

---

## Testing Protocol

**Skip tests for docs/comments changes. Run tests ONLY if code logic changes.**
- Docs/README/comments updates: No tests needed
- Code/logic changes: Ask user first: "Should I run tests to validate?"

**Test-Driven Development (TDD):** Write tests FIRST, then implement code.

## Test Commands

```bash
# Quick validation (recommended)
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | \
  grep -E '(PASS|FAIL|passed|failed|warning)'

# Full output
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Single suite
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing UFreeTests/MockAuthRepositoryTests
```

## Build Troubleshooting

| Issue | Solution |
|-------|----------|
| Provisioning profile error | Use `-scheme UFreeUnitTests`, not `-scheme UFree` |
| No simulator specified error | Always include `-destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |
| Device selection fails | Use `-destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |

**Validation workflow:** 1) Make changes → 2) Run tests with grep → 3) Look for "passed" → 4) Done

---

## Architecture & Layers

| Layer | Key Components |
|-------|---|
| **Domain** | User, AvailabilityStatus, DayAvailability, UserSchedule, UserProfile, Protocols (AuthRepository, AvailabilityRepository, FriendRepositoryProtocol), UpdateMyStatusUseCase |
| **Data** | FirebaseAuthRepository, MockAuthRepository, SwiftDataAvailabilityRepository, FirebaseAvailabilityRepository, CompositeAvailabilityRepository, FirebaseFriendRepository, AppleContactsRepository, CryptoUtils |
| **Presentation** | RootViewModel (auth), MyScheduleViewModel, FriendsScheduleViewModel, FriendsViewModel, StatusBannerViewModel, DayFilterViewModel |
| **UI** | RootView (auth + tabs), LoginView, MyScheduleView, FriendsView, FriendsScheduleView, Components |

**Projects:** UFree (app), UFreeTests (154+ unit tests), UFreeUITests (integration tests)

---

## Code Style & Conventions

**Swift Standards:**
- SwiftUI only (no UIKit)
- `@Published` for ViewModel state (required for `@StateObject`)
- Async/await for concurrency (not Combine Publishers)
- `@MainActor` on UI/Presentation components and auth repos
- Dependency injection via init parameters
- Protocol-based repos for testability
- Actor for mocks requiring concurrent access (MockAuthRepository, MockAvailabilityRepository)

**Naming:** CamelCase types, camelCase properties/functions. Descriptive names (e.g., `AuthRepository`, not `Auth`)

**Architecture Principles:**
- **Abstractions**: Protocol-based repos + Factory patterns (TestNotificationBuilder) reduce coupling
- **Maintainability**: Single Responsibility - each class/struct does one thing well
- **Reusability**: Shared utilities (HapticManager, AvailabilityStatus+Colors) avoid duplication
- **Extensibility**: Enum-based types (NotificationType) allow easy additions without breaking changes

**Testing:** Arrange-Act-Assert pattern. Test names: `test_[method]_[expectedBehavior]()`. Include rapid-tap protection tests (single tap, rapid taps, sequential taps).

**AsyncStream Pattern (Auth State):**
```swift
var authState: AsyncStream<User?> { get }

// In ViewModel:
Task {
    for await user in authRepository.authState {
        self.currentUser = user
    }
}
```

**Actor Isolation:**
1. `nonisolated` initializers if they don't access actor state
2. `nonisolated` properties if they don't need isolation (e.g., AsyncStream)
3. Extract properties to local variables before assertions in tests

**Error Handling:** Typed errors (e.g., `UpdateMyStatusUseCaseError.cannotUpdatePastDate`). Propagate repo errors; catch and rollback in ViewModel.

**Imports:** Foundation, SwiftUI, SwiftData, FirebaseAuth, FirebaseFirestore (if needed), then local modules.

---

## Tappable Component Pattern

**All interactive UI components follow this pattern:**

1. **ViewModel** (@MainActor, @Published state, rapid-tap protection via `guard !isProcessing`)
2. **View** (separate file with @StateObject for ViewModel)
3. **Tests** (single tap, rapid taps, sequential taps)

**Example:** `StatusBannerView` + `StatusBannerViewModel` (status cycling, 0.3s processing, rapid-tap protection)

**Files to create:**
- `{Component}ViewModel.swift` - State management (@MainActor, @Published)
- `{Component}View.swift` - UI with @StateObject or stateless
- `{Component}ViewModelTests.swift` - Rapid-tap scenarios (if stateful)
- Parent view - Layout orchestration only

**Shared Utilities:**
- `AvailabilityStatus+Colors.swift` - Domain-level color extension (`.displayColor`)
- `ButtonStyles.swift` - NoInteractionButtonStyle (removes default highlight)
- `HapticManager.swift` - Unified feedback API

---

## Navigation & UI

**Apple-Compliant:**
- Use `.navigationTitle()`, `.navigationSubtitle()`, `.navigationBarTitleDisplayMode()`
- Add buttons via `.toolbar(placement: .navigationBarTrailing)`
- Do NOT use custom header sections or `.principal` placement for titles
- Single NavigationStack at MainAppView level (no nesting)

**Example:**
```swift
NavigationStack {
    VStack { /* content */ }
        .navigationTitle("UFree")
        .navigationSubtitle("See when friends are available")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Sign Out") { /* action */ }
            }
        }
}
```

---

## Sprint 4 Additions

**Phone Search Pattern:** findUserByPhoneNumber() in repository protocol. Clean input → Hash via CryptoUtils → Firestore query on hashedPhoneNumber. FriendsViewModel state: searchText, searchResult, isSearching. Rapid-tap protection via isSearching guard. Clears search after adding. Prevents self-add via Auth user ID check.

**Blind Index Pattern:** Privacy-safe search using hashed phone numbers. Raw numbers never exposed to Firestore.

**Two-Way Handshake:** FriendRequest domain model (id, fromId/Name, toId, RequestStatus enum, timestamp). sendFriendRequest() creates pending request. acceptFriendRequest() atomic batch write (mark accepted + bidirectional friendIds add). declineFriendRequest() marks declined. observeIncomingRequests() AsyncStream for real-time listener. Privacy-first: schedule visibility only after both parties consent.

**View Lifecycle Management:** FriendsViewModel.listenToRequests() starts real-time listener. .task { listenToRequests() } begins on view appear. .onDisappear { stopListening() } stops listener (saves battery/data). Real-time animation with .spring() when requests arrive. Listener cleanup on task cancellation.

---

## Sprint 3.2 Additions

**NavigationStack:** Single parent at MainAppView level (TabView parent), no nesting
**HapticManager:** Unified feedback API - light(), medium(), heavy(), success(), warning(), selection()
**Firebase:** Disabled swizzling (`Info.plist`), manual config in AppDelegate with safety checks
**ViewModel Lifecycle:** Created at RootView level, persist across tab switches

---

---

## Sprint 5 Additions (In Progress)

**Notification Center:** Real-time notification system with AsyncStream. Domain model (AppNotification with friendRequest/nudge types), repository protocol, Firestore-backed implementation. ViewModel manages unread count badge. Bell button in toolbar next to Sign Out menu.

**Architecture & Abstractions:**
- **Domain Layer**: `AppNotification` struct with `NotificationType` enum (extensible for future types like scheduleChange, eventInvite)
- **Data Layer**: `NotificationRepository` protocol (Firestore + Mock implementations for testing)
- **Presentation Layer**: `NotificationViewModel` (@MainActor, @Published state), `NotificationCenterView` (inbox UI), `NotificationBellButton` (reusable component)
- **Environment Injection**: NotificationViewModel passed via SwiftUI environment for clean prop drilling

**Testing Patterns:**
- **TestNotificationBuilder** (Factory pattern): Single source of truth for test data creation. Eliminates duplication across tests.
- **NotificationTestAssertions** (Helper functions): Reusable assertions for message formatting. Central point to update message assertions.
- **Focused test classes**: One responsibility per test file (ViewModel logic, Repository behavior, View rendering)
- **DRY tests**: TestNotificationBuilder.friendRequest() replaces 5-line manual setup in every test

**Firestore Security Rules Update Required:**
```
match /users/{userId}/notifications/{document=**} {
  allow read: if request.auth.uid == userId;
  allow create: if request.auth.uid == resource.data.senderId;
  allow write: if request.auth.uid == userId;
}
```

**Files:**
- **Domain**: `AppNotification.swift`, `NotificationRepository.swift`
- **Data**: `FirebaseNotificationRepository.swift`, `MockNotificationRepository.swift`
- **Presentation**: `NotificationViewModel.swift`, `NotificationCenterView.swift`, `NotificationBellButton.swift`
- **Tests**: `NotificationViewModelTests.swift`, `MockNotificationRepositoryTests.swift`, `NotificationCenterViewTests.swift`, `TestNotificationBuilder.swift`, `NotificationTestAssertions.swift`

---

## Sprint 5.1 Additions (Nudge Feature)

**Nudge Interaction:** Real-time nudging on FriendsScheduleView. Tap wave button on any friend's row to send a nudge notification.

**Implementation Details:**
- **FriendsScheduleViewModel Enhancement**: Added `isNudging` property + `sendNudge(to:)` async method with rapid-tap protection
- **Rapid-Tap Protection**: Guard clause `guard !isNudging else { return }` prevents concurrent nudges
- **Haptic Feedback**: `.medium()` on tap, `.success()` on completion, `.warning()` on error (via HapticManager)
- **Error Handling**: User-facing error messages via @Published errorMessage (reuses existing alert UI)
- **Button State**: Disabled + opacity reduced while nudging (visual feedback)
- **Dependency Injection**: NotificationRepository passed to FriendsScheduleViewModel via init

**Testing Patterns (4 New Tests):**
- `test_sendNudge_setsProcessingFlag()` - Validates rapid-tap protection flag lifecycle
- `test_sendNudge_completesSuccessfully()` - Success path (no errors)
- `test_rapidNudgeTaps_ignoresSecondTap()` - Concurrent tap rejection
- `test_sendNudge_clearsErrorOnSuccess()` - Error state cleanup

**Files Modified:**
- `FriendsScheduleViewModel.swift` - Added nudge logic with rapid-tap protection
- `FriendsScheduleView.swift` - Added wave button to friend rows
- `FriendsScheduleViewModelTests.swift` - Added 4 nudge-specific tests
- `RootView.swift` - DI: Pass FirebaseNotificationRepository to FriendsScheduleViewModel

---

## Sprint 6 Additions (Complete) ✅

**Theme:** Discovery & Intentions - Availability Heatmap + Group Nudging

**Phase 1: Availability Heatmap ✅**
- Added `freeFriendCount(for:friendsSchedules:)` to FriendsScheduleViewModel
- Counts only .free status (excludes afternoonOnly, eveningOnly, busy, unknown)
- Powers "Who's free on..." day selector with live friend availability counts
- Tests: 6 heatmap logic tests (edge cases, date normalization, multi-friend scenarios)

**Phase 2: Capsule UI Refactor ✅**
- Redesigned DayFilterButtonView from square to vertical capsule (60w × 90h)
- Active state: accentColor background with white text
- Inactive state: systemGray6 background
- Badge display: "X free" in green (inactive) or white (active), hidden when 0
- Tests: 10 UI tests (state rendering, badge display, dimensions, transitions)

**Phase 3: Contextual Group Nudge ✅**
- Implemented `nudgeAllFree(for:)` in FriendsScheduleViewModel using `withThrowingTaskGroup`
- Parallel processing: true concurrent execution (speed = slowest single write, not O(N) sequential)
- Added "Nudge All" button to FriendsScheduleView (appears only when day selected + friends free)
- @Published successMessage property for partial success counts
- Three-tier messaging: "All 3 friends nudged! 👋" | "Nudged 2 of 3" | error message
- Haptic strategy: medium() on tap, success() on all-success, warning() on partial/complete failure
- Tests: 8 group nudge tests (parallel execution, failure tracking, message formatting, singular/plural)

**Critical Bug Fixes During Verification:**
1. **TaskGroup Result Tracking**: Changed `withThrowingTaskGroup(of: Void.self)` → `of: Bool.self` to properly track failures (was counting all completions as successes)
2. **Ternary Operator**: Fixed `"nudged" : "nudged"` (both branches identical!) to proper singular/plural handling
3. **Test Infrastructure**: Added `MockNotificationRepository.userIdsToFailFor` test hook to simulate failures in 3 new failure scenario tests

**Test Coverage:**
- Total: 206 tests (including 4 new tests + 4 updated tests = +4 net new assertions)
- DayFilterButtonViewTests: 11 tests (capsule UI edge cases, badge logic)
- DayFilterViewModelTests: 6 tests (heatmap counting, date normalization)
- FriendsScheduleViewModelTests: 12 tests (group nudge + success/failure messaging)
- All tests passing ✅

**Files Modified:**
- `FriendsScheduleViewModel.swift` - Added freeFriendCount(), nudgeAllFree(), successMessage property
- `FriendsScheduleView.swift` - Added day selector with heatmap, "Nudge All" button
- `DayFilterButtonView.swift` - Refactored to vertical capsule with badge
- `MockNotificationRepository.swift` - Added userIdsToFailFor test hook
- `FriendsScheduleViewModelTests.swift` - Added 4 new tests for partial/complete failures
- `DayFilterButtonViewTests.swift` - Fixed flawed test, added 10 UI tests
- `MyScheduleView.swift` - Fixed parameter passing to DayFilterButtonView

**Design Decisions (IMPLEMENTED):**
- Count only .free status (not partial availability) for clear signal
- Use TaskGroup for true parallel execution (performance vs sequential)
- Single haptic per action (no per-friend spam)
- Partial success counts always shown (never binary success/fail)

---

**Last Updated:** January 8, 2026 (Sprint 6 Complete - Discovery & Intentions) | **Status:** Production Ready ✅

**Sprint 7 Planning:** (Upcoming) - Feature TBD

**Path:** `/Users/KhangVu/Documents/Development/git_project/Khang_business_projects/UFree` (underscores, no spaces)
