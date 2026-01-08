# UFree - Weekly Availability Scheduler

**Status:** ✅ Sprint 5.1 | **Version:** 5.1.0 | **Tests:** 164+ | **Coverage:** 85%+ | **Warnings:** 0

---

## Quick Reference

| Feature | Status | Notes |
|---------|--------|-------|
| Local Persistence (SwiftData) | ✅ | Offline-capable, upsert pattern |
| Firebase Auth | ✅ | Anonymous signin, @MainActor safety |
| Cloud Sync (Firestore) | ✅ | CompositeRepository (offline-first) |
| Contact Discovery | ✅ | Hash-based contact sync + matching |
| Phone Number Search | ✅ | Blind index lookup, privacy-safe |
| Friend Requests | 🚀 | Request/Response handshake, privacy-first |
| Friends Sync | ✅ | Bidirectional add/remove, swipe-to-remove |
| Navigation | ✅ | TabView with single NavigationStack (no flicker) |
| Haptic Feedback | ✅ | HapticManager integrated throughout |
| Real-time Sync | ✅ | AsyncStream listeners (observeIncomingRequests) |
| Notification Center | ✅ | Real-time bell icon + badge, inbox view |
| Nudge Feature | ✅ | Wave button on friend cards, haptic feedback, rapid-tap protection |

---

## Architecture

**Current (Sprint 4):**
```
RootView (ViewModels created once, persisted)
    ↓
MainAppView (TabView with NavigationStack at parent)
    ├─ Tab 1: ScheduleContainer → MyScheduleView
    ├─ Tab 2: FriendsScheduleView  
    └─ Tab 3: FriendsView (phone search + handshake)
```

**Data Flow (Offline-First):**
```
UI → ViewModel → CompositeRepository → SwiftData [instant]
                       ↓ (background)
                    Firestore [sync, non-blocking]
```

---

## Core Models

| Model | Fields | Purpose |
|-------|--------|---------|
| `User` | id, isAnonymous, displayName | Auth entity |
| `DayAvailability` | id, date (midnight), status, note | Schedule per day |
| `UserProfile` | id, displayName, hashedPhoneNumber | Friend profile |
| `AvailabilityStatus` | 6 states + colors | Domain enum |

---

## File Structure (Key Files)

```
UFree/Core/Domain/
├── User.swift, AuthRepository.swift
├── AvailabilityStatus.swift, AvailabilityStatus+Colors.swift
└── DayAvailability.swift, UserSchedule.swift

UFree/Core/Data/
├── Auth/ → FirebaseAuthRepository.swift, MockAuthRepository.swift
├── Repositories/ → SwiftData/Firebase/Composite repositories
├── Utilities/ → CryptoUtils, HapticManager
└── Mocks/ → MockAuthRepository, MockAvailabilityRepository, MockFriendRepository

UFree/Features/
├── Root/ → RootViewModel, RootView (auth + TabView), LoginView
├── MySchedule/ → ViewModel, View (MyScheduleView), Components
│   ├── StatusBannerView + ViewModel (status cycling)
│   ├── DayStatusCardView (stateless day card)
│   └── DayFilterButtonView + ViewModel (day filter)
├── FriendsSchedule/ → FriendsScheduleView, FriendsScheduleViewModel
└── FindFriends/ → FriendsView, FriendsViewModel

UFree/Core/Extensions/
├── Color+Hex.swift
└── ButtonStyles.swift (NoInteractionButtonStyle)
```

---

## Sprint Completion

### Sprint 5: Notification Center ✅

**Real-Time Notification System**
- AppNotification domain model with NotificationType enum (friendRequest, nudge, extensible)
- NotificationRepository protocol + FirebaseNotificationRepository (AsyncStream listener)
- MockNotificationRepository for testing (no Firestore dependency)
- NotificationViewModel (@MainActor, unread badge count)
- NotificationCenterView (inbox with read/unread states)
- NotificationBellButton (reusable toolbar component, red badge)
- Environment injection for clean prop drilling across tabs

**Testing Patterns & Abstractions**
- TestNotificationBuilder (Factory pattern): Single source of truth for test data
- NotificationTestAssertions (Helper assertions): Centralized message assertions
- Focused test organization: One class per responsibility (ViewModel, Repository, View)
- DRY tests: Builders replace 5-line manual setup, helpers replace duplicated assertions
- 10+ unit tests covering badge logic, async behavior, message formatting, and nudge action

**Architecture Highlights**
- **Abstractions**: Protocol repos reduce coupling, factory builders encapsulate test data
- **Maintainability**: Single responsibility per class, helpers centralize logic
- **Reusability**: Builders/assertions used by 3+ test files, ViewModel shared via environment
- **Extensibility**: NotificationType enum easily extended, test helpers scale with new types

### Sprint 5.1: Nudge Feature ✅

**Live Nudging on FriendsScheduleView**
- Wave button on each friend's card (orange icon, clear affordance)
- Tap to send real-time nudge notification
- `isNudging` flag for rapid-tap protection (guard clause pattern)
- Haptic feedback: medium on tap, success on completion, warning on error
- Button disabled/opaque while processing (visual feedback)
- Error messages shown in existing alert UI
- Dependency injection: NotificationRepository passed to FriendsScheduleViewModel

**Testing & Quality**
- 4 new nudge-specific tests in FriendsScheduleViewModelTests
- Rapid-tap protection validated (single tap, rapid taps, sequential taps)
- Error state cleanup verified
- Total: 164+ unit tests (4 new for nudge feature)

**Files Modified**
- `FriendsScheduleViewModel.swift` - Added nudge logic with rapid-tap protection
- `FriendsScheduleView.swift` - Added wave button to friend rows
- `FriendsScheduleViewModelTests.swift` - Added 4 nudge-specific tests
- `RootView.swift` - DI: Pass FirebaseNotificationRepository to FriendsScheduleViewModel

---

### Sprint 6: Discovery & Intentions (Planned 🔮)

**Theme:** Transform "Who's free on..." from static filter to dynamic Availability Discovery Engine.

**Core Intention:** "Before tapping a day, show: How many friends can I actually hang out with today?"

**Phase 1: Availability Heatmap (Intentional Availability)**
- Count ALL "generally available" states: `.free`, `.afternoonOnly`, `.eveningOnly`
- Intent: Show user "who is a potential match" for that day
- DayFilterViewModel observes friendSchedules, aggregates counts per day
- @Published friendCountByDay: [Date: Int] with status color tinting
- Reactive updates on schedule changes

**Phase 2: Capsule UI Refactor**
- Replace square DayFilterButtonView with vertical capsules
- Active state: displayColor highlight (matching Status Banner)
- Inactive state: .thinMaterial (light gray background)
- Embed friend count badge with color tinting (green if majority `.free`, orange if partial)
- Visual affordance: "3 free" or "2 free, 1 evening"

**Phase 3: Contextual Group Nudge (Parallel Processing)**
- "Nudge All" button appears when day selected + friends available
- Tap to send nudge to ALL available users on that day
- Implementation: `withThrowingTaskGroup` fires all `sendNudge(to:)` calls in parallel
- Why: Firestore writes are independent. Parallel = speed of slowest single write (vs 0.5s * N sequential)
- Haptic Strategy: `.medium()` on tap, `.success()` on completion, `.warning()` on partial failure
- Error Handling: Show "Nudged 3 of 4 friends" with success count (never binary Success/Failure)
- New @Published successMessage property for temporary toast notifications

**Implementation Approach (TDD First):**
1. Phase 1: Count aggregation tests → heatmap logic with color tinting
2. Phase 2: Visual state tests → capsule UI with badges
3. Phase 3: Batch nudge tests → TaskGroup parallel processing + error handling

**Finalized Design Decisions:**
- **Intentional Availability:** Count `.free` + partial states (matches user intent)
- **Batch Processing:** Parallel TaskGroup (performance + app architecture consistency)
- **Haptics:** Single medium + single success (premium feel, no "machine gun" spam)
- **Error Handling:** Partial success counts + success/warning messages (graceful, user-aware)

**Est. Effort:** 5-6 hours total (1-2 hrs per phase)

---

### Sprint 4: Two-Way Handshake & Phone Search ✅

**Phone Number Search (Privacy-Safe)**
- findUserByPhoneNumber() in FriendRepositoryProtocol + FirebaseFriendRepository
- Blind index pattern: Clean → Hash → Firestore query on hashedPhoneNumber
- Raw phone numbers never exposed (privacy-safe)
- FriendsViewModel: searchText, searchResult, isSearching state + performPhoneSearch()
- UI: "Find by Phone Number" section with TextField + Search button
- Haptic feedback: medium() on search, success() on add
- Clears search state after adding (clean UX)
- Prevents self-add via Auth user ID check
- 7 unit tests (search empty, found/not found, state toggle, clear after add, workflow)

**Friend Request Handshake System (Privacy-First)**
- FriendRequest domain model (id, fromId/Name, toId, RequestStatus enum, timestamp)
- sendFriendRequest() creates pending request in Firestore (instead of immediate friend add)
- observeIncomingRequests() AsyncStream for real-time listener (instant notification)
- acceptFriendRequest() atomic batch write: mark accepted + bidirectional friendIds add
- declineFriendRequest() marks request as declined (stops showing in list)
- FriendsViewModel: listenToRequests() + stopListening() for view lifecycle management
- .task { listenToRequests() } starts listener when view appears
- .onDisappear { stopListening() } stops listener (saves battery/data)
- Real-time animation: requests pop in with .spring() when other user sends
- UI: "Friend Requests" section at top with Accept/X Decline buttons (haptic feedback)
- 5 unit tests for handshake (send, accept, decline, multiple requests, observation, lifecycle)
- Privacy-first: schedule visibility only after both parties consent

---

### Sprint 3.2: Stability & Polish ✅

**Navigation (Flickering Fix)**
- Moved NavigationStack to MainAppView TabView parent
- Removed nested NavigationStack from child views
- Data loads before MainAppView shown (RootView level)
- Result: Smooth transitions, no flicker

**App Configuration**
- Firebase: Disabled swizzling (`Info.plist`), manual config in AppDelegate
- SF Symbols: Fixed `person.2.wave.vertical` → `person.2.fill`
- Zero compiler warnings

**Firestore Security**
- Updated rules: All authenticated users read `/users` (friend discovery)
- Availability subcollection: Owner-only write, all-authenticated read
- Proper auth checks in ViewModels

**Contacts & Permissions**
- Check authorization first, only request if needed
- Diagnostic logging: total contacts, phone numbers, hashes, failures
- User-friendly error messages (no contacts, no phone numbers, denied access)
- Permission alert with Settings button

**Haptic Feedback (HapticManager.swift)**
- 6 feedback types: light, medium, heavy, success, warning, error, selection
- Integrated: StatusBannerView (medium), DayStatusCardView (light), DayFilterButtonView (selection), FriendsView (medium/success/warning)
- Improves perceived responsiveness

**ViewModel Lifecycle**
- FriendsScheduleViewModel, FriendsViewModel created at RootView level
- Persist across tab switches (no re-init, no data loss)
- FriendsScheduleViewModel loads on first auth (RootView.onChange)
- ScheduleContainer creates CompositeAvailabilityRepository inline

---

### Sprint 3.1: Friends ✅

- CryptoUtils (SHA-256 hashing, privacy-safe)
- AppleContactsRepository (permission handling, contact fetching)
- FriendRepositoryProtocol + FirebaseFriendRepository (Firestore ops + matching)
- FriendsViewModel (@MainActor, state mgmt)
- FriendsView (two sections: My Trusted Circle + Add Friends)
- TabView integration, bidirectional sync
- Contact batching (10-item Firestore limit with TaskGroup)

### Sprint 3: Cloud Sync ✅

- FirestoreDayDTO (Firestore ↔ Domain mapping)
- FirebaseAvailabilityRepository (Firestore read/write)
- CompositeAvailabilityRepository (offline-first orchestrator)
- Write-Through, Read-Back pattern (instant local + background remote)

### Sprint 2.5: Auth & Navigation ✅

- User entity, AuthRepository protocol
- FirebaseAuthRepository, MockAuthRepository (@MainActor)
- RootViewModel + RootView (auth navigation)
- LoginView (anonymous signin)
- Standard Apple-compliant nav bar
- AsyncStream for reactive auth state

### Sprint 2: Local Persistence ✅

- SwiftData integration (SwiftDataAvailabilityRepository)
- PersistentDayAvailability model
- Upsert pattern, date normalization

### Sprint 1: Core ✅

- Domain models (AvailabilityStatus, DayAvailability, UserSchedule)
- UpdateMyStatusUseCase with validation
- MyScheduleView + MyScheduleViewModel
- Mock repository for testing

---

## Component Architecture

### Tappable Component Pattern

All interactive UI components follow:
1. **ViewModel** (@MainActor, @Published state, rapid-tap protection via `guard !isProcessing`)
2. **View** (separate file, stateless props or @StateObject for ViewModel)
3. **Tests** (single tap, rapid taps, sequential taps)

### Components

| Component | Type | Feedback |
|-----------|------|----------|
| StatusBannerView | Stateful (ViewModel) | `.medium()` |
| DayStatusCardView | Stateless | `.light()` |
| DayFilterButtonView | Parent-managed state | `.selection()` |
| FriendsView | Various | `.medium()`/`.success()`/`.warning()` |

### Shared Utilities

- `AvailabilityStatus+Colors.swift` - Domain-level color extension (`.displayColor`)
- `ButtonStyles.swift` - NoInteractionButtonStyle (no highlight flash)
- `HapticManager.swift` - Unified feedback API

---

## Firestore Schema

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

**Security Rules:**
```javascript
match /users/{userId} {
  allow read: if request.auth != null;
  allow write: if isOwner(userId);
  match /availability/{dayId} {
    allow read: if request.auth != null;
    allow write: if isOwner(userId);
  }
}
```

---

## Running Tests

```bash
# Quick validation
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | \
  grep -E '(PASS|FAIL|passed|failed|warning)'

# Full output
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Single test suite
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing UFreeTests/MockAuthRepositoryTests
```

See AGENTS.md for troubleshooting.

---

## UI Conventions

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

## Technical Highlights

✅ Clean Architecture (Domain → Data → Presentation → UI)  
✅ Protocol-based DI (swap repos easily)  
✅ @MainActor isolation (thread safety)  
✅ Actor-based mocks with nonisolated inits  
✅ AsyncStream for auth state (no Combine)  
✅ Conditional Firebase init  
✅ Async/await throughout  
✅ Single NavigationStack (no nesting)  
✅ Zero warnings, zero memory leaks, zero flaky tests

---

## Features End-to-End

1. **Auth Flow** - Firebase init → LoginView → Anonymous signin → MainAppView
2. **Schedule** - View 7 days, update per-day status (5 states), persist locally
3. **Status Banner** - Cycle through states with gradient animations + rapid-tap protection
4. **Day Filter** - Select days, filter schedule view
5. **Cloud Sync** - Local instant + background Firestore sync
6. **Friend Discovery** - Contact hash OR phone search, view profiles
7. **Friend Requests** - Send request, real-time incoming list, accept/decline (handshake)
8. **Friends Sync** - Bidirectional add/remove, swipe-to-remove, privacy-protected
9. **Friends Schedule** - View friend availability next 5 days
10. **Nudge Feature** - Tap wave button to send nudge, real-time notifications, rapid-tap protection
11. **Error Handling** - Past date rejection, network resilience, permission alerts
12. **Haptic Feedback** - Tactile feedback throughout UI
13. **Navigation** - Smooth tabbed navigation, no flickering

---

## Recent Changes (Sprint 5.1 Complete)

**Notification Center** - Real-time bell icon in toolbar (next to Sign Out). AsyncStream listener for live updates. Unread badge count. Inbox view with read/unread states. Extensible notification types (friendRequest, nudge, future: scheduleChange, eventInvite).

**Nudge Feature** - Wave button on FriendsScheduleView cards. Tap to send nudge notifications instantly. Rapid-tap protection via isNudging flag. Haptic feedback (medium on tap, success on completion, warning on error). Button disabled/opaque while processing.

**Testing Abstractions** - TestNotificationBuilder (factory pattern) eliminates repetitive test data setup. NotificationTestAssertions (helper assertions) centralizes message formatting logic. Tests now ~40% shorter with better DRY principle adherence.

**Architecture Patterns** - Applied abstractions (protocol repos, factory builders) to reduce coupling. Emphasized single responsibility (one class/helper per concern). Designed for reusability (builders/assertions used across test files) and extensibility (new notification types scale automatically).

---

**Last Updated:** January 8, 2026 (Sprint 5.1 Complete - Nudge Feature) | **Status:** Production Ready ✅

**Path Update:** January 8, 2026 - Migrated to `Khang_business_projects/UFree` (underscores instead of spaces)
