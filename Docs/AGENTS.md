# UFree Agent Instructions

## Testing Protocol

**IMPORTANT: Only run tests when explicitly requested or when code logic changes. Do NOT run tests for documentation-only updates.**
- For Docs, README, or comments changes: Skip testing unless user asks
- For code/logic changes: Run tests only after checking with user first
- Always ask before test execution: "Should I run tests to validate?"

## Build & Test Commands

**Run all unit tests (fast feedback) — RECOMMENDED:**
```bash
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | \
  grep -E '(PASS|FAIL|Test Session|passed|failed|warning)'
# ~35 seconds total, includes full build + 106 tests
```

**Alternative (cleaner output):**
```bash
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
# Full output; scroll to end for test summary
```

**Run single test:**
```bash
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing UFreeTests/MockAuthRepositoryTests
```

**Run UI tests (comprehensive):**
```bash
./run_all_tests.sh           # ~10 seconds
```

## Build Troubleshooting

**Issue: `xcodebuild build -scheme UFree` fails with provisioning profile error**
- Do NOT use `-scheme UFree` for validation; use `-scheme UFreeUnitTests` instead
- Avoid `xcodebuild build` entirely; go straight to `xcodebuild test` with a simulator destination
- Always specify `-destination 'platform=iOS Simulator,name=iPhone 17 Pro'` to avoid device-selection errors

**Issue: Tests fail because no simulator specified**
- Error: "Tests must be run on a concrete device"
- Solution: Always include `-destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- Available simulators: iPhone 17, iPhone 17 Pro, iPhone 17 Pro Max, iPhone Air, iPad Pro (M4/M5), iPad Air (M3), iPad mini (A17 Pro)

**Fastest validation workflow:**
1. Make code changes
2. Run test command above with grep filter
3. Look for "passed" in output; if all tests passed, code is good
4. Scroll full output for details if needed

## Architecture & Structure

**Clean Architecture Layers:**
- **Domain:** User, AvailabilityStatus, DayAvailability, UserSchedule, AuthRepository (protocol), AvailabilityRepository (protocol), UpdateMyStatusUseCase
- **Data:** FirebaseAuthRepository, MockAuthRepository, SwiftDataAvailabilityRepository, MockAvailabilityRepository, PersistentDayAvailability, FirebaseAvailabilityRepository (skeleton)
- **Presentation:** RootViewModel (auth), MyScheduleViewModel (schedule)
- **UI:** RootView (auth routing), LoginView, MyScheduleView

**Key Subprojects:**
- UFree: Main app bundle
- UFreeTests: Unit tests (106 tests covering auth, domain, data, use cases, view models, UI components)
- UFreeUITests: UI integration tests

**Persistence:** SwiftData local-only (Sprint 2.5). Firebase auth ready. Firestore integration pending (Sprint 3).

## Code Style & Conventions

**Swift/iOS Standards:**
- SwiftUI for UI (avoid UIKit)
- Combine `@Published` for reactive state in ViewModels (required for `@StateObject` compatibility)
- Async/await for concurrency in data layer (not Combine Publishers)
- @MainActor on UI/presentation components (RootViewModel, MyScheduleViewModel, StatusBannerViewModel, DayFilterViewModel, auth repositories)
- Dependency injection via init parameters
- Protocol-based repositories for testability (AuthRepository, AvailabilityRepository)
- Actor for test doubles that need concurrent access (MockAuthRepository, MockAvailabilityRepository)

**Naming:** CamelCase types/classes, camelCase properties/functions. Use descriptive names reflecting domain (e.g., AuthRepository, User, not Auth, CurrentUser).

**Testing:** Arrange-Act-Assert pattern. Name tests as `test_[method]_[expectedBehavior]()`. Use MockAuthRepository (actor for thread safety), MockAvailabilityRepository (actor for thread safety), and in-memory SwiftData containers. For ViewModels, include rapid-tap protection tests (single tap, rapid taps, sequential taps).

**Auth State Streaming:** Use AsyncStream for reactive UI updates instead of Combine. Example:
```swift
var authState: AsyncStream<User?> { get }

// In ViewModel:
Task {
    for await user in authRepository.authState {
        self.currentUser = user
    }
}
```

**Actor Isolation Patterns:**
1. Make initializers `nonisolated` if they don't access actor state:
```swift
nonisolated public init(user: User? = nil) {
    self.user = user
}
```

2. Make properties `nonisolated` if they don't need isolation (e.g., AsyncStream):
```swift
nonisolated public var authState: AsyncStream<User?> {
    authStateStream
}
```

3. In tests, extract properties to local variables before assertions:
```swift
// ❌ Causes warnings
let user = await repository.currentUser
XCTAssertEqual(user?.id, "123")

// ✅ Correct pattern
let user = await repository.currentUser
let userId = user?.id
XCTAssertEqual(userId, "123")
```

**Error Handling:** Use typed errors (UpdateMyStatusUseCaseError.cannotUpdatePastDate). Propagate repository errors; catch and rollback in ViewModel. Auth errors propagate to RootViewModel as `errorMessage: String?` for display.

**Imports:** Group into Foundation, SwiftUI, SwiftData, FirebaseAuth, FirebaseFirestore (when needed), then local modules. Follow clean architecture boundaries.

## Tappable Component Pattern

**For ALL interactive/tappable UI components (buttons, cards, etc.):**
1. **Extract state management to a ViewModel** (one ViewModel per component type)
   - ViewModel handles all state: processing flags, data updates
   - Prevents rapid-tap issues and logic duplication
   - Marked with `@MainActor` for thread safety
   - Conforms to `ObservableObject` with `@Published` properties
   
2. **Implement rapid-tap protection** using guard clause:
   ```swift
   func handleTap() {
       guard !isProcessing else { return }  // Prevent concurrent taps
       isProcessing = true
       // ... async operation ...
   }
   ```

3. **Extract component views to separate files** for reusability:
   - Each component in its own file (e.g., `{Component}View.swift`)
   - Include preview for design iteration without app launch
   - Parent view stays lean, orchestrating component layout only

4. **Add unit tests** covering rapid-tap scenarios:
   - Test single tap → correct state update
   - Test rapid taps → ignored while processing, final state is correct
   - Test sequential taps → each processed correctly

**Pattern Examples:**
- `StatusBannerView.swift` + `StatusBannerViewModel` - Manages status cycling (3 states) with 0.3s processing phase and rapid-tap protection
- `DayFilterButtonView.swift` + `DayFilterViewModel` - Day selection with toggle behavior
- `DayStatusCardView.swift` - Reusable status card (stateless, receives color and onTap callback)
- Unit tests: `StatusBannerViewModelTests` (10 tests), `DayFilterViewModelTests` (6 tests)

**Files to create for a new component:**
- `{Component}ViewModel.swift` - Only if component has state/logic. Marked with `@MainActor`, conforms to `ObservableObject`, use `@Published` for state
- `{Component}View.swift` - Component UI, use `@StateObject` to instantiate ViewModel (if applicable)
- `{Component}ViewModelTests.swift` - Unit tests for ViewModel including rapid-tap scenarios (if applicable)
- Parent view - Use extracted components, reduce to layout orchestration only

**Shared Utilities:**
- `AvailabilityStatus+Colors.swift` - Domain-level color mapping extension (reusable across UI layer)
- `ButtonStyles.swift` - Centralized button styles like `NoInteractionButtonStyle`

---

## Navigation & UI Patterns

**Apple Guidelines First:**
- Always prefer native SwiftUI modifiers (`.navigationTitle()`, `.navigationSubtitle()`, `.navigationBarTitleDisplayMode()`, etc.)
- These modifiers couple UI elements automatically and handle platform-specific behavior
- Only customize or create workarounds if native implementation is impossible
- This convention ensures consistency, reduces maintenance, and respects Apple's design patterns

**Navigation Bar (Standard Apple-Compliant):**
- Use `.navigationTitle("Title")` for main title
- Use `.navigationSubtitle("Subtitle")` for subtitle (couples automatically with title)
- Use `.navigationBarTitleDisplayMode(.large)` for large title style
- Add buttons via `.toolbar(placement: .navigationBarTrailing)` for right-side buttons
- Do NOT use custom header sections or toolbar `.principal` placement for titles/subtitles
- Example:
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

**Dependency Passing:**
- Pass `rootViewModel` down through container views when auth actions (sign out) needed
- In `ScheduleContainer`, receive both container and rootViewModel, pass to MyScheduleView
- MyScheduleView takes `viewModel` (for schedule) and `rootViewModel` (for auth actions)

## Sprint 2.5+ Context (UI Enhancements & Refactoring)

**UI Enhancements:**
- `UserStatus` enum with three states: checkSchedule, busy, free
- `StatusBannerViewModel` for managing status cycling with rapid-tap protection
- `DayFilterViewModel` for managing day selection state
- Multi-stage animation: processing phase with border overlay → state transition with text slide + gradient color change
- Established tappable component pattern for all interactive UI elements
- 16 new tests (StatusBannerViewModelTests: 10, DayFilterViewModelTests: 6)
- Day status card colors updated: Afternoon Only (pink → orange), Evening Only (orange → purple)
- Day names and numbers now inherit status color instead of grey

**Code Architecture Refactoring:**
- Extracted `StatusBannerView.swift` - Standalone component with independent preview
- Extracted `DayStatusCardView.swift` - Reusable day status card component
- Extracted `DayFilterButtonView.swift` - New reusable day filter button component
- Extracted `ButtonStyles.swift` - Centralized button style utilities
- Created `AvailabilityStatus+Colors.swift` - Domain-level color extension (eliminates code duplication)
- Refactored `MyScheduleView.swift` - Reduced from 323 → 139 lines, now orchestrates layout only
- All components have previews for design iteration without launching app
- Single responsibility per file: easier to test, maintain, and extend

**For Next Sprint (3):**
- Implement FirebaseAvailabilityRepository methods (currently skeleton throwing "Not implemented yet")
- Build CompositeAvailabilityRepository pattern (local + remote fallback)
- Define Firestore document schema for UserSchedule
- Add network tests with Firebase emulator
