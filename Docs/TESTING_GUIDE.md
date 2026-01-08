# UFree Testing Guide

**Status:** ✅ Production Ready | **Tests:** 160+ (Sprint 5) | **Coverage:** 85%+ | **Quality:** Zero flaky, zero memory leaks

---

## Quick Start

```bash
# Quick validation (recommended)
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | \
  grep -E '(PASS|FAIL|passed|failed|warning)'

# Full output
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# UI tests
./run_all_tests.sh
```

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
└── Features/                 (73+ tests)
    ├── RootViewModelTests.swift (7)
    ├── MyScheduleViewModelTests.swift (11)
    ├── StatusBannerViewModelTests.swift (10)
    ├── DayFilterViewModelTests.swift (6)
    ├── FriendsViewModelTests.swift (4)
    ├── FriendsPhoneSearchTests.swift (7)
    ├── FriendsHandshakeTests.swift (12)
    ├── UpdateMyStatusUseCaseTests.swift (4)
    └── Notifications/          (6 tests)
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
| ViewModels | 67+ | 85%+ |
| Extensions | 7 | 100% |
| UI Views | — | SwiftUI previews |
| **Total** | **154+** | **85%+** |

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

**Last Updated:** January 8, 2026 (Sprint 5 in progress) | **Status:** Production Ready

**Path Update:** January 8, 2026 - Migrated to `Khang_business_projects/UFree` (underscores instead of spaces)
