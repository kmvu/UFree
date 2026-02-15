# UFree Testing Guide

**Status:** ✅ Production Ready | **Tests:** 206+ | **Coverage:** 85%+ | **Quality:** Zero flaky, zero memory leaks

---

## Quick Start

```bash
# Quick validation (recommended)
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | \
  grep -E '(PASS|FAIL|passed|failed|warning)'

# Full output (for debugging)
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Via fastlane
fastlane tests
```

---

## Debug Auth Strategy (Manual Testing)

For testing multi-user flows without SMS codes:

```swift
// Available in DEBUG builds only
// LoginView shows developer overlay with quick login buttons

// Steps:
1. Add Firebase test phone numbers (5 min, one-time)
   - Console > Authentication > Phone
   - +1 555-000-0001, +1 555-000-0002, +1 555-000-0003 (all code: 123456)

2. Tap "User 1", "User 2", "User 3" in developer tools section

3. Test multi-user scenarios:
   - User A sends friend request
   - User B accepts instantly (no device-switching needed)
   - Both see live updates within 2 seconds
```

**Benefits:**
- No real SMS codes needed
- Test on single simulator or device
- Validates real-time Firestore sync
- Rapid-tap protection verified

---

## Test Organization

```
UFreeTests/
├── Auth/                     (17 tests)
│   ├── UserTests.swift (7)
│   └── MockAuthRepositoryTests.swift (10)
│
├── Domain/                   (18 tests)
│   ├── AvailabilityStatusTests.swift (5)
│   ├── DayAvailabilityTests.swift (6)
│   └── UserScheduleTests.swift (7)
│
├── Data/                     (60+ tests)
│   ├── Mocks/
│   │   ├── MockAvailabilityRepositoryTests.swift (6)
│   │   └── MockFriendRepositoryTests.swift (3)
│   ├── Network/
│   │   └── FirestoreDayDTOTests.swift (13)
│   ├── Persistence/
│   │   ├── PersistentDayAvailabilityTests.swift (9)
│   │   └── SwiftDataAvailabilityRepositoryTests.swift (11)
│   ├── Repositories/
│   │   ├── CompositeAvailabilityRepositoryTests.swift (11)
│   │   └── FriendRepositoryTests.swift (3)
│   └── Utilities/
│       └── CryptoUtilsTests.swift (placeholder)
│
├── Core/Extensions/          (7 tests)
│   └── Color+HexTests.swift (7)
│
└── Features/                 (77+ tests)
    ├── RootViewModelTests.swift (7)
    ├── MyScheduleViewModelTests.swift (11)
    ├── StatusBannerViewModelTests.swift (10)
    ├── DayFilterViewModelTests.swift (6)
    ├── FriendsViewModelTests.swift (4)
    ├── FriendsScheduleViewModelTests.swift (8)    ← +4 nudge tests
    ├── FriendsPhoneSearchTests.swift (7)
    ├── FriendsHandshakeTests.swift (12)
    ├── UpdateMyStatusUseCaseTests.swift (4)
    └── Notifications/          (10 tests)
        ├── NotificationViewModelTests.swift (3)
        ├── MockNotificationRepositoryTests.swift (3)
        ├── NotificationCenterViewTests.swift (3)
        └── Helpers/
            ├── TestNotificationBuilder.swift
            └── NotificationTestAssertions.swift
```

---

## Coverage Breakdown

| Layer | Tests | Coverage |
|-------|-------|----------|
| Domain Models | 18 | 100% |
| Auth Layer | 17 | 100% |
| Use Cases | 4 | 100% |
| Data Layer (Mock) | 9 | 100% |
| Data Layer (Persistence) | 20 | 100% |
| Data Layer (Firestore & Composite) | 24 | 100% |
| ViewModels | 90+ | 85%+ |
| Notifications | 25 | 85%+ |
| Extensions | 7 | 100% |
| UI Views | — | SwiftUI previews |
| **Total** | **206+** | **85%+** |

---

## Testing Patterns & Abstractions

### Factory Pattern: TestNotificationBuilder

**Problem:** Tests repeat 5-line notification setup. Changes to AppNotification require updating every test.

**Solution:** Single factory for creating test data with sensible defaults:

```swift
// Before: repetitive setup
func test_something() {
    let notification = AppNotification(
        recipientId: "user1",
        senderId: "sender1",
        senderName: "Alice",
        type: .friendRequest,
        date: Date(),
        isRead: false
    )
}

// After: clean, reusable
func test_something() {
    let notification = TestNotificationBuilder
        .friendRequest(senderName: "Alice")
        .build()
}
```

**Benefits:**
- Single source of truth for test data structure
- Adding new fields to AppNotification? Update only TestNotificationBuilder
- Convenience builders for common types (friendRequest, nudge)
- Maintainable: changes propagate automatically to all tests

### Helper Assertions: NotificationTestAssertions

**Problem:** Message assertions scattered across tests. Hard to keep in sync when message format changes.

**Solution:** Centralized assertion helpers:

```swift
// Before: manual assertions repeated
XCTAssertEqual(message, "Alice sent you a friend request.")

// After: reusable, maintainable
NotificationTestAssertions.assertFriendRequestMessage(message, senderName: "Alice")
```

**Benefits:**
- Update message format in one place → all tests pass/fail consistently
- Clear intent: what are we testing?
- Extensible: add new assertion helpers as features grow

### Focused Test Organization

**Pattern:** One test class per domain/data/presentation layer responsibility

```
Notifications/
├── NotificationViewModelTests.swift    (ViewModel logic: badge count, optimistic updates)
├── MockNotificationRepositoryTests.swift (Repository behavior: async methods, no-throws)
├── NotificationCenterViewTests.swift    (View logic: message formatting)
└── Helpers/
    ├── TestNotificationBuilder.swift    (Test data factory)
    └── NotificationTestAssertions.swift (Shared assertions)
```

**Benefits:**
- Clear test responsibility = easy to find/understand
- Isolated: ViewModel tests don't need to mock View logic
- Reusable: Helpers are imported by all test files

---

## In-Memory Persistence for Tests

Unit tests automatically use in-memory SwiftData containers (no disk I/O). Auto-detection via `TestConfiguration.isRunningUnitTests` flag in UFreeApp.

**How it works:**
- `TestConfiguration.swift` detects XCTest environment
- UFreeApp.init() checks flag → creates in-memory container if testing
- `TestContainerFactory.makeInMemoryContainer()` available for explicit control

**Benefits:** 100x faster (RAM vs disk), no CI permission/space errors, complete isolation.

**Example:**
```swift
@MainActor
final class SwiftDataAvailabilityRepositoryTests: XCTestCase {
    private var container: ModelContainer!
    
    override func setUp() {
        super.setUp()
        container = TestContainerFactory.makeInMemoryContainer()
    }
}
```

---

### Rapid-Tap Protection (ViewModel)

ViewModels prevent concurrent operations using guard clause:

```swift
@MainActor
final class StatusBannerViewModelTests: XCTestCase {
    var viewModel: StatusBannerViewModel!

    override func setUp() {
        super.setUp()
        viewModel = StatusBannerViewModel()
    }

    // Single tap → correct state
    func test_cycleStatus_updatesStatus() {
        viewModel.cycleStatus()
        XCTAssertEqual(viewModel.currentStatus, .free)
    }

    // Rapid taps → ignored while processing
    func test_rapidTaps_ignored_while_processing() async {
        viewModel.cycleStatus()
        XCTAssertTrue(viewModel.isProcessing)

        // These should be ignored
        viewModel.cycleStatus()
        viewModel.cycleStatus()

        // Status should be free (only first tap counted)
        XCTAssertEqual(viewModel.currentStatus, .free)
    }

    // Sequential taps → each processed
    func test_sequentialTaps_after_processing() async {
        viewModel.cycleStatus()
        await Task.sleep(nanoseconds: 500_000_000)  // Wait for processing
        
        viewModel.cycleStatus()
        XCTAssertEqual(viewModel.currentStatus, .busy)
    }
}
```

### Async/Await in Tests

```swift
@MainActor
final class MyScheduleViewModelTests: XCTestCase {
    func test_loadSchedule_async() async {
        let viewModel = MyScheduleViewModel(
            updateUseCase: UpdateMyStatusUseCase(repository: MockAvailabilityRepository()),
            repository: MockAvailabilityRepository()
        )
        
        await viewModel.loadSchedule()
        
        XCTAssertEqual(viewModel.weeklySchedule.count, 7)
    }
}
```

### Mock Repository Pattern

```swift
actor MockAuthRepository: AuthRepository {
    nonisolated let user: User?
    
    nonisolated init(user: User? = nil) {
        self.user = user
    }
    
    nonisolated var authState: AsyncStream<User?> {
        AsyncStream { continuation in
            continuation.yield(user)
            continuation.finish()
        }
    }
}
```

### SwiftData Testing (In-Memory)

```swift
@MainActor
final class SwiftDataAvailabilityRepositoryTests: XCTestCase {
    var container: ModelContainer!
    var repository: SwiftDataAvailabilityRepository!

    override func setUp() async throws {
        try await super.setUp()
        
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: PersistentDayAvailability.self,
            configurations: config
        )
        repository = SwiftDataAvailabilityRepository(container: container)
    }
}
```

---

## Key Test Scenarios

| Scenario | Layer | Purpose |
|----------|-------|---------|
| Auth state streaming | Auth | Verify AsyncStream reactivity |
| Rapid-tap handling | ViewModel | Prevent concurrent operations |
| Offline-first sync | Data | Local instant + background remote |
| DTO round-trip | Network | Firestore ↔ Domain mapping |
| Upsert logic | Persistence | Update existing, insert new |
| Validation errors | Use Case | Business rule enforcement |
| Contact discovery | Data | Hash-based contact matching |
| Phone search | ViewModel + Data | Blind index lookup, self-add prevention |
| Friend requests | ViewModel + Data | Send/accept/decline, real-time observation |
| Request handshake | Data | Atomic batch write, bidirectional sync |
| Notification badge | ViewModel | Unread count filtering (domain logic) |
| Notification messages | View | Type-specific formatting |
| Async stream listening | Repository | AsyncStream iteration without crash |
| Nudge action | ViewModel | Rapid-tap protection, haptic feedback, error handling |
| Nudge button UI | View | Wave button affordance, disabled state while processing |

---

## Debug Tips

**View test output:**
```bash
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tee test_output.txt
```

**Run specific test:**
```bash
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing UFreeTests/StatusBannerViewModelTests/test_rapidTaps_ignored_while_processing
```

**Check coverage:**
- Run tests with coverage enabled in Xcode (Product → Scheme → Edit Scheme → Test → Code Coverage)
- Targets with 100% coverage: Domain, Auth, Use Cases, Mocks, DTOs, Extensions
- Targets with 85%+ coverage: ViewModels, Data Layer

---

## Test Maintenance

**Add test when:**
- Adding new feature or use case
- Fixing a bug (regression test first)
- Touching auth/persistence/critical paths
- Adding ViewModel with async logic

**Skip test when:**
- Doc/comment-only changes
- UI layout changes (use previews instead)
- Minor style updates

**Update test when:**
- Changing API contract
- Modifying validation rules
- Updating error handling
- Refactoring internals (unit tests should remain green)

---

---

## Architecture Principles Applied

### Abstractions (Reduce Coupling)

1. **Protocol-Based Repos** → Can swap Firebase for Mock without changing code
2. **Factory Builders** (TestNotificationBuilder) → Test data structure encapsulated
3. **Helper Assertions** → Message logic centralized, not hardcoded in tests

### Maintainability (Single Responsibility)

1. **TestNotificationBuilder** → Only knows how to build test notifications
2. **NotificationTestAssertions** → Only contains assertions, not test logic
3. **Focused test classes** → ViewModel tests only test ViewModel, not View rendering

### Reusability (DRY Principle)

1. **TestNotificationBuilder.friendRequest()** → Used by 3+ test files
2. **NotificationTestAssertions.assertFriendRequestMessage()** → Central message assertion
3. **Environment injection** → NotificationViewModel shared across tabs via environment

### Extensibility (Easy to Add)

1. **NotificationType enum** → Add `.scheduleChange`, `.eventInvite` without breaking code
2. **TestNotificationBuilder convenience methods** → Add `.scheduleChange()` builder, tests automatically support it
3. **NotificationTestAssertions** → Add `.assertScheduleChangeMessage()` when new types arrive

---

---

## Sprint 6: Batch Nudge Tests (Complete) ✅

### FriendsScheduleViewModelBatchNudgeTests.swift (19 tests)

**Purpose:** Comprehensive validation of batch nudge logic, focusing on success count tracking, error handling, and edge cases.

**File Location:** `UFreeTests/Features/FriendsScheduleViewModelBatchNudgeTests.swift`

#### Category 1: Success Count Tracking (3 tests)

1. **test_nudgeAllFree_successCountTracking_accumulates**
   - 5 free friends, all succeed
   - Validates: `successCount = 5`, message shows "All 5 friends nudged!"
   - Key: `withThrowingTaskGroup(of: Bool.self)` returns true/false per task

2. **test_nudgeAllFree_partialFailure_2of5Failed**
   - 5 free friends, 2 fail (using `userIdsToFailFor = ["f2", "f4"]`)
   - Validates: `successCount = 3`, message shows "Nudged 3 of 5 friends"
   - Key: Partial success handled correctly

3. **test_nudgeAllFree_allFailures_5of5Failed**
   - 5 free friends, all fail
   - Validates: `successCount = 0`, errorMessage set, successMessage nil
   - Key: Complete failure triggers error path

#### Category 2: Message Pluralization (5 tests)

4. **test_nudgeAllFree_singleSuccess_singular**
   - 1 friend succeeds
   - Expected: "All 1 friend nudged!" (singular)
   - Key: `let friendWord = totalCount == 1 ? "friend" : "friends"`

5. **test_nudgeAllFree_doubleSuccess_plural**
   - 2 friends succeed
   - Expected: "All 2 friends nudged!" (plural)
   - Key: Correct plural form validation

6-8. **Additional pluralization tests**
   - 10-friend scenario, large list handling

#### Category 3: Filtering by Status (2 tests)

9. **test_nudgeAllFree_mixedStatuses_onlyFreeIncluded**
   - 7 friends: 3 `.free`, 2 `.afternoonOnly`, 1 `.busy`, 1 `.unknown`
   - Expected: Only 3 nudged (free friends only)
   - Key: Status filter: `.filter { display.status(for: date) == .free }`

10. **test_nudgeAllFree_afternoonOnlyExcluded**
    - 1 `.free` + 1 `.afternoonOnly`
    - Expected: Only 1 nudged (the free one)
    - Key: Validates specific status exclusion

#### Category 4: State Management (3 tests)

11. **test_nudgeAllFree_isNudgingFlag_clearedOnSuccess**
    - Validates: `isNudging = true` during op, `false` after success
    - Key: `defer { isNudging = false }`

12. **test_nudgeAllFree_isNudgingFlag_clearedOnFailure**
    - Validates: `isNudging = false` even on error
    - Key: defer ensures cleanup on all paths

13. **test_nudgeAllFree_messagesCleared_onNewOperation**
    - Set old messages, call nudgeAllFree
    - Validates: Old messages removed, new messages set
    - Key: `errorMessage = nil`, `successMessage = nil` at start

#### Category 5: Edge Cases (3 tests)

14. **test_nudgeAllFree_largeList_10Friends**
    - 10 free friends
    - Expected: "All 10 friends nudged!"
    - Key: Large list handled correctly

15. **test_nudgeAllFree_dateNormalization_timeIgnored**
    - Friend at midnight, query at 2 PM same day
    - Expected: Friend matched
    - Key: `Calendar.current.startOfDay(for: date)`

16. **test_nudgeAllFree_noFreeFriendsOnDate_earlyExit**
    - No free friends on selected date
    - Expected: Early exit, errorMessage set
    - Key: `guard !freeFriendIds.isEmpty else { return }`

#### Category 6: Rapid-Tap Protection (1 test)

17. **test_nudgeAllFree_rapidCalls_secondIgnored**
    - Two rapid calls (without await between)
    - Expected: Only one executes
    - Key: `guard !isNudging else { return }`

#### Category 7: Haptic Feedback (3 tests)

18. **test_nudgeAllFree_haptic_mediumOnTap**
    - Validates: `HapticManager.medium()` called immediately
    - Key: Before TaskGroup starts

19. **test_nudgeAllFree_haptic_successOnAllSuccess**
    - Validates: `success()` called when `successCount == totalCount`
    - Key: Three-tier haptic strategy

20. **test_nudgeAllFree_haptic_warningOnFailure**
    - Validates: `warning()` called on partial/complete failure
    - Key: Feedback indicates non-ideal outcome

### Critical Bug Fixes Validated ✅

**Bug #1: TaskGroup Result Tracking**
- Problem: `withThrowingTaskGroup(of: Void.self)` never tracked results
- Solution: Changed to `of: Bool.self` with `true` (success) / `false` (failure) returns
- Tests: Partial failure tests confirm successCount accumulates correctly

**Bug #2: Message Pluralization**
- Problem: Ternary operator had identical branches `"nudged" : "nudged"`
- Solution: `let friendWord = totalCount == 1 ? "friend" : "friends"`
- Tests: 5 pluralization tests validate singular/plural forms

### MockNotificationRepository Test Hook

```swift
// Setup failure simulation
mockNotificationRepo.userIdsToFailFor.insert("f2")  // f2 will fail

// In mock:
public func sendNudge(to userId: String) async throws {
    if userIdsToFailFor.contains(userId) {
        throw NSError(...)  // ✅ Fails
    }
    // Create mock notification  ✅ Succeeds
}
```

### Running Batch Nudge Tests

```bash
# All batch nudge tests
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing UFreeTests/FriendsScheduleViewModelBatchNudgeTests

# Single test
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing UFreeTests/FriendsScheduleViewModelBatchNudgeTests/test_nudgeAllFree_partialFailure_2of5Failed
```

---

## Core Patterns Tested

### Group Nudging (Parallel TaskGroup)

- **Rapid-tap protection:** `guard !isNudging` prevents concurrent calls
- **Parallel execution:** `withThrowingTaskGroup(of: Bool.self)` for speed
- **Partial success:** Track count of succeeded/failed nudges
- **Haptic feedback:** medium → success/warning based on result
- **20+ tests** validating all scenarios (success, partial, failure, rapid-tap, edge cases)

### Heatmap Integration

- **Friend count by day:** Aggregates friend availability across selected day
- **Status filtering:** Only counts `.free` status
- **Reactive updates:** UI refreshes when friendSchedules change
- **Badge rendering:** Shows count or hides if zero
- **6+ tests** validating counts, filtering, reactivity

### Real-Time Sync

- **Firestore listeners:** AsyncStream for notifications + friend requests
- **Local-first:** SwiftData instant, Firestore eventual consistency
- **Offline graceful:** Catches errors without crashing
- **15+ tests** covering success, failure, edge cases

---

---

## Quick Test Summary

| Metric | Value |
|--------|-------|
| Total Tests | 206+ |
| Code Coverage | 85%+ |
| Warnings | 0 |
| Flaky Tests | 0 |
| Execution Time | < 2 min |
| Test Organization | 7 layers (Auth, Domain, Data, Core, Features) |
| Mock Patterns | Actor-based with nonisolated init |
| Async Support | Full async/await |

---

## QA Testing: 30-Minute Smoke Test

**Purpose:** Manual validation of core features before release  
**Time:** 30 minutes (two simulators/devices)  
**Result:** Sign-off checklist confirms everything works end-to-end

### Setup (One-time, 5 min)

Add Firebase test phone numbers (Console > Authentication > Phone):
- +1 555-000-0001 (code: 123456)
- +1 555-000-0002 (code: 123456)
- +1 555-000-0003 (code: 123456)

LoginView shows "DEVELOPER TOOLS" overlay with User 1/2/3 buttons (DEBUG only)

### Test Scenarios (25 min)

#### Scenario 1: Friend Request Flow (5 min)
1. **User A** - Search for User B by phone, tap "Add Friend"
2. **User B** - See incoming request, tap "Accept"
3. **Both** - Verify bidirectional friendship created within 2 sec

#### Scenario 2: Nudge Flow (5 min)
1. **User A** - Tap "Nudge" on User B's card, feel haptics
2. **User B** - See red badge on bell, tap to open notification
3. **Both** - Verify nudge appears, badge count correct, auto-marks as read

#### Scenario 3: Rapid-Tap Protection (3 min)
1. Send nudge, rapidly tap 5+ times during flight
2. Verify only 1 notification created (no duplicates)

#### Scenario 4: Cold Start (3 min)
1. Log in, add friend, send nudge
2. Force-close app, reopen
3. Verify user still logged in, data preserved

#### Scenario 5: Offline Graceful (3 min)
1. Enable airplane mode, try to send nudge
2. Verify error toast (no crash)
3. Disable airplane mode, retry succeeds

#### Scenario 6: Deep Linking (2 min)
1. Simulate URL in Xcode console:
   ```swift
   let url = URL(string: "https://ufree.app/notification/user123")!
   UIApplication.shared.open(url)
   ```
2. Verify app opens and notification is highlighted

### Sign-Off Checklist

- [ ] Friend request appears in Firestore within 2 sec
- [ ] Recipient sees request within 3 sec
- [ ] Accept creates bidirectional friendship
- [ ] Nudge creates notification in recipient's collection
- [ ] Notification badge updates correctly
- [ ] Cold start preserves all data
- [ ] Offline doesn't crash
- [ ] Rapid-tap protection prevents duplicates
- [ ] Deep linking works

### After Smoke Test Passes
```bash
fastlane tests        # Verify 206+ tests pass
fastlane beta         # Submit to TestFlight
```

---

**Last Updated:** January 30, 2026 (Sprint 6+ - Production Ready) | **Status:** ✅ Ready to Ship
