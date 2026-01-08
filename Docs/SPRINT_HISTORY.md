# Sprint History - UFree Project Evolution

**Complete chronological record of UFree development from Sprint 1 through Sprint 5.1**

---

## Sprint 1: Core ✅

**Foundation:** Domain models, status management, basic schedule view

- Domain models (AvailabilityStatus, DayAvailability, UserSchedule)
- UpdateMyStatusUseCase with validation
- MyScheduleView + MyScheduleViewModel
- Mock repository for testing

---

## Sprint 2: Local Persistence ✅

**Goal:** Offline-capable data storage with SwiftData

- SwiftData integration (SwiftDataAvailabilityRepository)
- PersistentDayAvailability model
- Upsert pattern, date normalization
- Foundation for cloud sync (Sprint 3)

---

## Sprint 2.5: Auth & Navigation ✅

**Goal:** User authentication and smooth navigation

- User entity, AuthRepository protocol
- FirebaseAuthRepository, MockAuthRepository (@MainActor)
- RootViewModel + RootView (auth navigation)
- LoginView (anonymous signin)
- Standard Apple-compliant nav bar
- AsyncStream for reactive auth state

---

## Sprint 3: Cloud Sync ✅

**Goal:** Hybrid offline-first sync with cloud fallback

- FirestoreDayDTO (Firestore ↔ Domain mapping)
- FirebaseAvailabilityRepository (Firestore read/write)
- CompositeAvailabilityRepository (offline-first orchestrator)
- Write-Through, Read-Back pattern (instant local + background remote)
- Network resilience without blocking UI

---

## Sprint 4: Friend Discovery & Requests ✅

**Goal:** Privacy-safe friend discovery with handshake protocol

- Contact Discovery
  - Hash-based contact sync + matching
  - AppleContactsRepository for contact access
  - CryptoUtils for hash-based privacy

- Phone Number Search
  - Blind index lookup (privacy-safe)
  - MockFriendRepository for testing

- Friend Requests
  - Request/Response handshake protocol
  - FirebaseFriendRepository
  - Real-time listener with AsyncStream
  - Privacy-first design (not publicly listed by phone)

- Friends Sync
  - Bidirectional add/remove
  - Swipe-to-remove UI
  - Test coverage: 30+ friend-related tests

---

## Sprint 5: Notification Center ✅

**Theme:** Real-Time Notifications & Awareness

### Architecture & Implementation

**Domain Layer:**
- `AppNotification` struct with `NotificationType` enum (extensible for friendRequest, nudge, future types)

**Data Layer:**
- `NotificationRepository` protocol
- `FirebaseNotificationRepository` (Firestore + AsyncStream listener)
- `MockNotificationRepository` for testing (no Firestore dependency)

**Presentation Layer:**
- `NotificationViewModel` (@MainActor, @Published unread badge count)
- `NotificationCenterView` (inbox with read/unread states)
- `NotificationBellButton` (reusable toolbar component, red badge)
- Environment injection for clean prop drilling across tabs

### Testing Patterns & Abstractions

- **TestNotificationBuilder** (Factory pattern): Single source of truth for test data creation. Eliminates duplication across tests.
- **NotificationTestAssertions** (Helper functions): Reusable assertions for message formatting. Central point to update message assertions.
- **Focused test classes**: One responsibility per test file (ViewModel logic, Repository behavior, View rendering)
- **DRY tests**: TestNotificationBuilder.friendRequest() replaces 5-line manual setup in every test
- 10+ unit tests covering badge logic, async behavior, message formatting, and nudge action

### Architecture Highlights

- **Abstractions**: Protocol repos reduce coupling, factory builders encapsulate test data
- **Maintainability**: Single responsibility per class, helpers centralize logic
- **Reusability**: Builders/assertions used by 3+ test files, ViewModel shared via environment
- **Extensibility**: NotificationType enum easily extended, test helpers scale with new types

### Firestore Security Rules

```javascript
match /users/{userId}/notifications/{document=**} {
  allow read: if request.auth.uid == userId;
  allow create: if request.auth.uid == resource.data.senderId;
  allow write: if request.auth.uid == userId;
}
```

---

## Sprint 5.1: Nudge Feature ✅

**Theme:** Real-Time User Engagement

### Live Nudging on FriendsScheduleView

- Wave button on each friend's card (orange icon, clear affordance)
- Tap to send real-time nudge notification
- `isNudging` flag for rapid-tap protection (guard clause pattern)
- Haptic feedback: `.medium()` on tap, `.success()` on completion, `.warning()` on error
- Button disabled/opaque while processing (visual feedback)
- Error messages shown in existing alert UI
- Dependency injection: NotificationRepository passed to FriendsScheduleViewModel

### Testing & Quality

- 4 new nudge-specific tests in FriendsScheduleViewModelTests
- Rapid-tap protection validated (single tap, rapid taps, sequential taps)
- Error state cleanup verified
- Total: 164+ unit tests (4 new for nudge feature)

### Files Modified

- `FriendsScheduleViewModel.swift` - Added nudge logic with rapid-tap protection
- `FriendsScheduleView.swift` - Added wave button to friend rows
- `FriendsScheduleViewModelTests.swift` - Added 4 nudge-specific tests
- `RootView.swift` - DI: Pass FirebaseNotificationRepository to FriendsScheduleViewModel

---

## Component Patterns Established (Sprints 1-5)

### Tappable Component Pattern

All interactive UI components follow:
1. **ViewModel** (@MainActor, @Published state, rapid-tap protection via `guard !isProcessing`)
2. **View** (separate file, stateless props or @StateObject for ViewModel)
3. **Tests** (single tap, rapid taps, sequential taps)

**Example:** `StatusBannerView` + `StatusBannerViewModel` (status cycling, 0.3s processing, rapid-tap protection)

### Files to Create (Standard Pattern)

- `{Component}ViewModel.swift` - State management (@MainActor, @Published)
- `{Component}View.swift` - UI with @StateObject or stateless
- `{Component}ViewModelTests.swift` - Rapid-tap scenarios (if stateful)
- Parent view - Layout orchestration only

### Shared Utilities

- `AvailabilityStatus+Colors.swift` - Domain-level color extension (`.displayColor`)
- `ButtonStyles.swift` - NoInteractionButtonStyle (removes default highlight)
- `HapticManager.swift` - Unified feedback API

---

## Architecture Evolution (Sprints 1-5)

### Core Layers

| Layer | Introduced | Key Components |
|-------|-----------|---|
| **Domain** | Sprint 1 | User, AvailabilityStatus, DayAvailability, UserSchedule, UserProfile, Protocols |
| **Data** | Sprint 1+ | FirebaseAuthRepository, SwiftDataRepository, CompositeRepository, Mocks |
| **Presentation** | Sprint 1+ | ViewModels, AsyncStream state management |
| **UI** | Sprint 1+ | SwiftUI only (no UIKit), Apple-compliant navigation |

### Data Flow (Offline-First)

```
UI → ViewModel → CompositeRepository → SwiftData [instant]
                       ↓ (background)
                    Firestore [sync, non-blocking]
```

### Navigation Pattern (Sprint 2.5+)

```
RootView (ViewModels created once, persisted)
    ↓
MainAppView (TabView with NavigationStack at parent)
    ├─ Tab 1: ScheduleContainer → MyScheduleView
    ├─ Tab 2: FriendsScheduleView  
    └─ Tab 3: FriendsView (phone search + handshake)
```

---

## Code Style & Conventions (Established Sprint 1-5)

**Swift Standards:**
- SwiftUI only (no UIKit)
- `@Published` for ViewModel state (required for `@StateObject`)
- Async/await for concurrency (not Combine Publishers)
- `@MainActor` on UI/Presentation components and auth repos
- Dependency injection via init parameters
- Protocol-based repos for testability
- Actor for mocks requiring concurrent access

**Naming:** CamelCase types, camelCase properties/functions. Descriptive names (e.g., `AuthRepository`, not `Auth`)

**Architecture Principles:**
- **Abstractions**: Protocol-based repos + Factory patterns reduce coupling
- **Maintainability**: Single Responsibility - each class/struct does one thing well
- **Reusability**: Shared utilities avoid duplication
- **Extensibility**: Enum-based types allow easy additions without breaking changes

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

## Test Coverage Growth

| Sprint | Tests | Notes |
|--------|-------|-------|
| Sprint 1-2 | 40+ | Core scheduling + persistence |
| Sprint 2.5 | 60+ | Auth + navigation |
| Sprint 3 | 90+ | Cloud sync + offline-first |
| Sprint 4 | 130+ | Friend discovery + requests |
| Sprint 5 | 150+ | Notifications + builders/helpers |
| Sprint 5.1 | 164+ | Nudge feature |

---

## UI Conventions (Established Sprint 1-5)

| Element | Style |
|---------|-------|
| Main Title | "UFree" (navigationTitle) |
| Subtitle | "See when friends are available" (navigationSubtitle) |
| Status Colors | Free (green), Busy (gray), Morning (yellow), Afternoon (orange), Evening (purple) |
| Corner Radius | Cards (20pt), Buttons (8pt), Banner (24pt) |
| Status Banner Height | 110pt |
| Spacing | Large (24pt), Medium (12pt), Small (8pt) |
| Nav Bar | Large title + Sign Out button (trailing) |

---

## HapticManager API

```swift
HapticManager.light()      // Card taps
HapticManager.medium()     // Primary actions
HapticManager.heavy()      // Significant changes
HapticManager.success()    // Success feedback (friend added)
HapticManager.warning()    // Destructive action (remove friend)
HapticManager.selection()  // Day filter selection
```

---

## Firestore Schema (Established Sprint 3)

```
users/{auth_uid}
├── displayName: String
├── hashedPhoneNumber: String
├── friendIds: [String]
└── availability/{YYYY-MM-DD}
    ├── status: Int (0-4)
    ├── note: String?
    └── updatedAt: Timestamp
```

---

## Key Learnings & Decisions (Sprints 1-5)

1. **Offline-First Architecture** - SwiftData for instant local writes, Firestore for eventual consistency. Users get responsive UI even without network.

2. **Privacy-Safe Discovery** - Blind index for phone numbers, hash-based contact matching. No public listings, no data leaks.

3. **AsyncStream for Auth** - No Combine Publishers. Simple, clean reactive state management without subscription boilerplate.

4. **Protocol-Based DI** - Mock repositories swap easily for testing. No Firebase dependency in tests.

5. **Rapid-Tap Protection** - Guard clause pattern (`guard !isProcessing else { return }`) prevents concurrent operations. Simple, effective, testable.

6. **Factory Patterns for Tests** - TestNotificationBuilder eliminates duplication. Single source of truth for test data.

7. **@MainActor Isolation** - Thread safety by default. UI updates always on main thread, no race conditions.

8. **Handshake Protocol** - Friend requests require both-way acceptance. Prevents spam, ensures mutual consent.

---

**Last Updated:** January 8, 2026 | **Total Sprints:** 5 (Plus Sprint 5.1) | **Tests:** 164+

**Next Phase:** Sprint 6 - Discovery & Intentions (Heatmap + Group Nudging)
