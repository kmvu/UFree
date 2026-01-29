# UFree - Weekly Availability Scheduler

**Status:** ✅ Production Ready | **Version:** 6.1.0+ | **Tests:** 206+ | **Coverage:** 85%+ | **Warnings:** 0

---

## Quick Links

- **Getting Started:** `AGENTS.md` (setup, code style, testing)
- **Architecture:** This file (overview, features, models)
- **Manual Testing:** `SMOKE_TEST_CHECKLIST.md` (30 min validation)
- **Test Details:** `TESTING_GUIDE.md` (206+ test organization)
- **Dev History:** `SPRINT_HISTORY.md` (Sprint 1-6 evolution)

---

## Quick Reference

| Feature | Status | Notes |
|---------|--------|-------|
| Local Persistence (SwiftData) | ✅ | Offline-capable, upsert pattern |
| Firebase Auth | ✅ | Anonymous signin, @MainActor safety |
| Cloud Sync (Firestore) | ✅ | CompositeRepository (offline-first) |
| Contact Discovery | ✅ | Hash-based contact sync + matching |
| Phone Number Search | ✅ | Blind index lookup, privacy-safe |
| Friend Requests | ✅ | Request/Response handshake, privacy-first |
| Friends Sync | ✅ | Bidirectional add/remove, swipe-to-remove |
| Navigation | ✅ | TabView with single NavigationStack (no flicker) |
| Haptic Feedback | ✅ | HapticManager integrated throughout |
| Real-time Sync | ✅ | AsyncStream listeners (observeIncomingRequests) |
| Notification Center | ✅ | Real-time bell icon + badge, inbox view |
| Nudge Feature | ✅ | Wave button on friend cards, haptic feedback, rapid-tap protection |
| Availability Heatmap | ✅ | "Who's free on..." with live counts per day |
| Group Nudging | ✅ | Parallel "Nudge All" for free friends, success/failure messaging |
| Universal Links | ✅ | App Site Association (deep link from notifications) |
| Build Automation | ✅ | Fastlane (tests → alpha → beta pipeline) |
| Certificate Management | ✅ | match (encrypted, auto-sync) |
| Crash Reporting | ✅ | Firebase Crashlytics (readable stack traces) |
| Analytics | ✅ | Firebase Analytics (real-time usage metrics) |

---

## Current Architecture

**Navigation & State (Top-Level):**
```
RootView (ViewModels created once, persisted)
    ↓
MainAppView (TabView with single NavigationStack)
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

**Layers:**

| Layer | Key Components |
|-------|---|
| **Domain** | User, AvailabilityStatus, DayAvailability, UserSchedule, UserProfile, Protocols |
| **Data** | FirebaseAuthRepository, SwiftDataAvailabilityRepository, FirebaseAvailabilityRepository, CompositeAvailabilityRepository, FirebaseFriendRepository, FirebaseNotificationRepository |
| **Presentation** | RootViewModel, MyScheduleViewModel, FriendsScheduleViewModel, FriendsViewModel, StatusBannerViewModel, DayFilterViewModel, NotificationViewModel |
| **UI** | RootView, LoginView, MyScheduleView, FriendsView, FriendsScheduleView, NotificationCenterView, Components |

**Projects:**
- **UFree** - Main app (SwiftUI)
- **UFreeTests** - 206+ unit tests
- **UFreeUITests** - Integration tests

---

## File Structure (Key Files)

```
UFree/Core/Domain/
├── User.swift, AuthRepository.swift
├── AvailabilityStatus.swift, AvailabilityStatus+Colors.swift
├── DayAvailability.swift, UserSchedule.swift
├── AppNotification.swift, NotificationRepository.swift

UFree/Core/Data/
├── Auth/ → FirebaseAuthRepository.swift, MockAuthRepository.swift
├── Repositories/ → SwiftData/Firebase/Composite repositories
├── Utilities/ → CryptoUtils, HapticManager, AnalyticsManager
└── Mocks/ → MockAuthRepository, MockAvailabilityRepository, MockFriendRepository

UFree/Features/
├── Root/ → RootViewModel, RootView (auth + TabView), LoginView
├── MySchedule/ → ViewModel, View (MyScheduleView), Components
│   ├── StatusBannerView + ViewModel (status cycling)
│   ├── DayStatusCardView (stateless day card)
│   └── DayFilterButtonView + ViewModel (day filter + heatmap badge)
├── FriendsSchedule/ → FriendsScheduleView, FriendsScheduleViewModel
├── FindFriends/ → FriendsView, FriendsViewModel
└── Notifications/ → NotificationCenterView, NotificationViewModel, NotificationBellButton

UFree/Core/Extensions/
├── Color+Hex.swift
└── ButtonStyles.swift (NoInteractionButtonStyle)
```

---

## Core Models

| Model | Fields | Purpose |
|-------|--------|---------|
| `User` | id, isAnonymous, displayName | Auth entity |
| `DayAvailability` | id, date (midnight), status, note | Schedule per day |
| `UserProfile` | id, displayName, hashedPhoneNumber | Friend profile |
| `AvailabilityStatus` | 6 states + colors | Domain enum (free, busy, afternoonOnly, eveningOnly, unknown) |
| `AppNotification` | id, type, senderId, recipientId | Notification (friendRequest, nudge) |

---

## Component Architecture

### Tappable Component Pattern

All interactive UI components follow:
1. **ViewModel** (@MainActor, @Published state, rapid-tap protection via `guard !isProcessing`)
2. **View** (separate file with @StateObject for ViewModel)
3. **Tests** (single tap, rapid taps, sequential taps)

**Example:** `StatusBannerView` + `StatusBannerViewModel` (status cycling, 0.3s processing, rapid-tap protection)

### Components

| Component | Type | Feedback |
|-----------|------|----------|
| StatusBannerView | Stateful (ViewModel) | `.medium()` |
| DayStatusCardView | Stateless | `.light()` |
| DayFilterButtonView | Parent-managed state | `.selection()` |
| FriendsView | Various | `.medium()`/`.success()`/`.warning()` |
| NotificationBellButton | Reusable toolbar | No feedback (notification center handles it) |

### Shared Utilities

- `AvailabilityStatus+Colors.swift` - Domain-level color extension (`.displayColor`)
- `ButtonStyles.swift` - NoInteractionButtonStyle (no highlight flash)
- `HapticManager.swift` - Unified feedback API
- `AnalyticsManager.swift` - Type-safe event tracking (Firebase Analytics)

---

## Firestore Schema

```
users/{auth_uid}
├── displayName: String
├── hashedPhoneNumber: String
├── friendIds: [String]
├── availability/{YYYY-MM-DD}
│   ├── status: Int (0-4)
│   ├── note: String?
│   └── updatedAt: Timestamp
└── notifications/{notificationId}
    ├── type: String ("friendRequest", "nudge")
    ├── senderId: String
    ├── recipientId: String
    ├── read: Bool
    └── createdAt: Timestamp
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
  match /notifications/{document=**} {
    allow read: if request.auth.uid == userId;
    allow create: if request.auth.uid == resource.data.senderId;
    allow write: if request.auth.uid == userId;
  }
}
```

---

## Running Tests

```bash
# Quick validation (recommended)
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

## Code Style & Conventions

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

## Features End-to-End

1. **Auth Flow** - Firebase init → LoginView → Anonymous signin → MainAppView
2. **Schedule** - View 7 days, update per-day status (5 states), persist locally
3. **Status Banner** - Cycle through states with gradient animations + rapid-tap protection
4. **Day Filter** - Select days, filter schedule view, see "Who's free on..." heatmap
5. **Cloud Sync** - Local instant + background Firestore sync
6. **Friend Discovery** - Contact hash OR phone search, view profiles
7. **Friend Requests** - Send request, real-time incoming list, accept/decline (handshake)
8. **Friends Sync** - Bidirectional add/remove, swipe-to-remove, privacy-protected
9. **Friends Schedule** - View friend availability next 5 days
10. **Nudge Feature** - Tap wave button to send nudge, real-time notifications, rapid-tap protection
11. **Batch Nudging** - Tap "Nudge All" to send nudges to all free friends (parallel execution)
12. **Notifications** - Real-time bell icon with unread badge, inbox view with read/unread states
13. **Deep Linking** - Universal Links (App Site Association) for notification tap-through
14. **Error Handling** - Past date rejection, network resilience, permission alerts
15. **Haptic Feedback** - Tactile feedback throughout UI
16. **Navigation** - Smooth tabbed navigation, no flickering
17. **Crash Reporting** - Automatic crash capture via Crashlytics, readable stack traces
18. **Analytics** - Event tracking for nudges, searches, status updates, handshakes

---

## Current Status (Sprint 6+)

### Production Stack ✅
- **Distribution:** Fastlane three-tier pipeline (tests → alpha → beta)
- **Certificates:** match (encrypted, auto-synced)
- **Crash Reporting:** Firebase Crashlytics (readable stack traces)
- **Analytics:** Firebase Analytics (real-time metrics + event tracking)
- **Testing:** 206+ unit tests, Debug Auth Strategy for multi-user dev testing
- **CI/CD:** GitHub Actions (push to main → TestFlight)

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
✅ Fastlane automation (tests → distribution)  
✅ Firebase Crashlytics + Analytics  
✅ Zero warnings, zero memory leaks, zero flaky tests

---

## Documentation

- **AGENTS.md** - Code style, architecture, testing protocols
- **TESTING_GUIDE.md** - 206+ tests, test patterns, organization
- **SMOKE_TEST_CHECKLIST.md** - Manual validation (30 min, two devices)
- **SPRINT_HISTORY.md** - Development history (Sprint 1-6)
- **UNIVERSAL_LINKS_SETUP.md** - Deep linking (App Site Association)
- **fastlane/Docs/FASTLANE_SETUP.md** - Build automation
- **fastlane/Docs/FIREBASE_SETUP.md** - Crashlytics + Analytics
- **fastlane/Docs/MATCH_GUIDE.md** - Certificate management
- **Docs/GITHUB_ACTIONS_SETUP.md** - CI/CD (GitHub Actions → TestFlight)

---

## Launch Checklist

1. ✅ Add Firebase test phone numbers (5 minutes)
2. ✅ Run smoke tests (30 minutes, two devices)
3. ✅ `bundle exec fastlane beta` → TestFlight
4. ✅ Monitor Crashlytics + Analytics

---

**Last Updated:** January 29, 2026 (Sprint 6+ - Production Ready) | **Status:** ✅ Ready for Distribution
