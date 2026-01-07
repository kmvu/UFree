# UFree Agent Instructions

## CRITICAL: Path Format

**MUST USE UNESCAPED SPACES IN FILE PATHS**

❌ WRONG:
```
/Users/KhangVu/Documents/Development/git_project/Khang\ Business\ Projects/UFree
```

✅ CORRECT:
```
/Users/KhangVu/Documents/Development/git_project/Khang Business Projects/UFree
```

Always use the absolute path with literal spaces, not escaped backslashes. This applies to all `create_file`, `Read`, `edit_file`, `Bash`, and other file operations.

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

**Last Updated:** January 7, 2026 (Sprint 4 complete) | **Status:** Production Ready
