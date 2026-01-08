# UFree Agent Instructions

## CRITICAL: Path Format

**ALWAYS USE UNDERSCORES (NO SPACES) - OR USE SPACES WITH QUOTES**

✅ CORRECT:
```
/Users/KhangVu/Documents/Development/git_project/Khang Business Projects/UFree
```

Use spaces naturally in this directory. All file operations will work with the space-based path.

---

## Project Structure

- **UFree/**: Main app source
- **UFreeTests/**: Unit tests
- **UFreeUITests/**: UI tests
- **Docs/**: Documentation
- **fastlane/**: Distribution automation

---

## Recent Work

- **Sprint 6.1 ✅ COMPLETE**: Distribution Automation with match
  - **Fastlane Integration**: Five lanes (tests, alpha, beta, test_report, sync_certs)
  - **Appfile**: Centralized app configuration (bundle ID, team IDs, Apple ID)
  - **match**: Private GitHub repo for encrypted certificate storage (MATCH_PASSWORD)
  - **Hands-Off Signing**: beta lane automatically syncs and uses certificates
  - **CI/CD Ready**: New machines only need MATCH_PASSWORD to build and distribute
  - **Files**: Fastfile (5 lanes), Appfile, .env.default, .gitignore, FASTLANE_SETUP.md, MATCH_GUIDE.md

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
| Certificate expired | Run `fastlane match appstore` to renew |
| match authentication fails | Check MATCH_PASSWORD in .env |

**Validation workflow:** 1) Make changes → 2) Run tests with grep → 3) Look for "passed" → 4) Done

---

## Architecture & Layers

| Layer | Key Components |
|-------|---|
| **Domain** | User, AvailabilityStatus, DayAvailability, UserSchedule, UserProfile, Protocols (AuthRepository, AvailabilityRepository, FriendRepositoryProtocol), UpdateMyStatusUseCase |
| **Data** | FirebaseAuthRepository, MockAuthRepository, SwiftDataAvailabilityRepository, FirebaseAvailabilityRepository, CompositeAvailabilityRepository, FirebaseFriendRepository, AppleContactsRepository, CryptoUtils |
| **Presentation** | RootViewModel (auth), MyScheduleViewModel, FriendsScheduleViewModel, FriendsViewModel, StatusBannerViewModel, DayFilterViewModel |
| **UI** | RootView (auth + tabs), LoginView, MyScheduleView, FriendsView, FriendsScheduleView, Components |

**Projects:** UFree (app), UFreeTests (206+ unit tests), UFreeUITests (integration tests)

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

## Sprint 6.1 Additions (Distribution Automation) ✅

**Theme:** Fastlane Automation - Every build validated before reaching testers

**Fastlane Three-Tier Pipeline:**
- **tests lane** - Pre-flight validation: runs all 206+ unit tests, fails build if any test fails
- **alpha lane** - Internal Firebase distribution: tests → build → Firebase App Distribution (no Apple review)
- **beta lane** - External TestFlight: tests → build → auto-increment build number → TestFlight (Apple review required)

**Enhanced with match Certificate Management:**
- **match integration** - Stores certificates in private GitHub repo (encrypted with MATCH_PASSWORD)
- **Appfile** - Centralized app ID, team ID, Apple ID configuration
- **Hands-off signing** - beta lane automatically syncs and uses certificates from match
- **CI/CD ready** - New machines only need MATCH_PASSWORD to build and distribute

**Architecture:**
- `fastlane/Fastfile` - Five lanes: tests, alpha, beta, test_report, sync_certs
- `fastlane/Appfile` - App configuration (bundle ID, team IDs, Apple ID)
- `fastlane/.env.default` - Template for credentials (Firebase, Apple ID, MATCH_PASSWORD)
- `fastlane/.gitignore` - Secrets protection (AuthKey_*.p8, .env, builds/, match credentials)

**Command Reference:**
```bash
fastlane tests          # Pre-flight validation (206+ tests)
fastlane alpha          # Build → Firebase (internal testers, instant)
fastlane beta           # Build → TestFlight (external testers, 1-2 days)
fastlane sync_certs     # Manual certificate sync (usually not needed)
fastlane test_report    # Generate detailed test report
```

**Pair Testing Strategy ("The Trusted Circle"):**
- User A searches User B by phone number (blind index privacy-safe)
- User A sends friend request, User B accepts (handshake)
- Both see "Who's free on..." heatmap with live friend counts
- User A taps "Nudge all" → User B receives real-time notification
- Validates: phone search, handshake, heatmap filtering, nudge delivery, haptics, notification persistence

**Files Created:**
- `fastlane/Fastfile` - Five lanes with match integration
- `fastlane/Appfile` - Centralized app configuration
- `fastlane/.env.default` - Template (Firebase, Apple ID, MATCH_PASSWORD)
- `fastlane/.gitignore` - Enhanced secrets protection
- `FASTLANE_SETUP.md` - Setup guide with match initialization (20 minutes one-time)
- `MATCH_GUIDE.md` - Deep dive on match certificate management
- `SPRINT_6_1_MATCH_INTEGRATION.md` - Summary of enhancements

**Build Automation Metrics:**
- Test suite: < 90 sec
- Alpha build: < 3 min (Firebase instant delivery)
- Beta build: < 8 min (match cert sync + TestFlight)
- Certificate sync: < 30 sec (automatic via match)

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

**Last Updated:** January 8, 2026 (Sprint 6.1 - Distribution Automation with match) | **Status:** Production Ready ✅

**Sprint 7 Planning:** (Upcoming) - Feature TBD

**Path:** `/Users/KhangVu/Documents/Development/git_project/Khang Business Projects/UFree`
