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

**Last Updated:** January 8, 2026 (Sprint 5 in progress) | **Status:** Production Ready

**Path Update:** January 8, 2026 - Migrated to `Khang_business_projects/UFree` (underscores instead of spaces)
