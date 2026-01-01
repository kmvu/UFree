# UFree - Weekly Availability Scheduler

**Status:** ✅ Sprint 2.5 Complete | **Version:** 2.5.1 | **Tests:** 90 | **Coverage:** 85%+

---

## Quick Status

**Production Ready:** Local persistence complete. Firebase auth infrastructure in place. Standard Apple-compliant navigation. Schedule sync ready for Sprint 3.

| Component | Status | Notes |
|-----------|--------|-------|
| Domain Models | ✅ Complete | AvailabilityStatus, DayAvailability, UserSchedule |
| Authentication | ✅ Complete | User entity, AuthRepository protocol, Firebase auth wrapper |
| SwiftData Persistence | ✅ Complete | Local storage with upsert pattern, date normalization |
| Use Cases | ✅ Complete | UpdateMyStatusUseCase with validation |
| MyScheduleViewModel & View | ✅ Complete | SwiftUI schedule, color-coded status buttons, standard nav bar |
| Login/Root Navigation | ✅ Complete | RootView routes between LoginView and MainAppView |
| Navigation Bar | ✅ Complete | Standard large title bar, Sign Out button on right |
| **Remote API Layer** | ⏳ Pending | Sprint 3: Firestore read/write (skeleton in place) |
| **Composite Repository** | ⏳ Pending | Sprint 3: Local + remote with fallback |
| **Real-time Sync** | ⏳ Pending | Sprint 3+: WebSocket/Firestore integration |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    UI Layer                             │
│  RootView (auth state) → LoginView OR MainAppView       │
│  MainAppView → ScheduleContainer → MyScheduleView       │
│  MyScheduleView: Standard nav bar + Sign Out button     │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│            Presentation Layer                           │
│  RootViewModel (auth state) + MyScheduleViewModel       │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│              Domain Layer                               │
│  User, AuthRepository, UpdateMyStatusUseCase            │
│  AvailabilityRepository (protocol)                      │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│               Data Layer                                │
│  FirebaseAuthRepository + MockAuthRepository            │
│  SwiftDataAvailabilityRepository (local)                │
│  FirebaseAvailabilityRepository (skeleton for Sprint 3) │
└─────────────────────────────────────────────────────────┘
```

---

## Core Models

### User (Sprint 2.5)
```swift
struct User: Identifiable, Equatable, Codable {
    let id: String
    let isAnonymous: Bool
}
```

### DayAvailability (Sprint 1-2)
```swift
struct DayAvailability: Identifiable, Codable {
    let id: UUID
    let date: Date        // Normalized to midnight
    var status: AvailabilityStatus
    var note: String?
}
```

### UserSchedule (Sprint 1-2)
```swift
struct UserSchedule: Identifiable {
    let id: String
    let name: String
    let avatarURL: URL?
    var weeklyStatus: [DayAvailability]  // Exactly 7 consecutive days
}
```

---

## Sprint Summary

### Sprint 1: Core Features ✅
- Domain models (AvailabilityStatus, DayAvailability, UserSchedule)
- Update status use case with validation
- Mock repository for testing
- MyScheduleView & MyScheduleViewModel
- 31 tests

### Sprint 2: Local Persistence ✅
- SwiftData integration (SwiftDataAvailabilityRepository)
- PersistentDayAvailability mapping model
- Upsert pattern for updates
- Date normalization (midnight constraint)
- 20 new tests

### Sprint 2.5: Infrastructure & UX Refinement ✅
- User domain entity + AuthRepository protocol
- FirebaseAuthRepository (Firebase Auth wrapper, @MainActor)
- MockAuthRepository (testing, actor-based)
- RootViewModel + RootView for auth navigation
- LoginView (anonymous sign-in)
- **Standard Apple-compliant navigation bar** (large title, Sign Out button)
- FirebaseAvailabilityRepository skeleton
- 7 new Color+Hex tests
- 39 total tests (90 across all suites)

### Sprint 3: Remote Sync (Upcoming)
- Implement FirebaseAvailabilityRepository (Firestore)
- CompositeRepository pattern (local + remote fallback)
- Schedule sync over network
- Real-time updates via listeners

---

## File Structure

```
UFree/Core/Domain/
├── Auth/                          ✅ Sprint 2.5
│   ├── User.swift
│   └── AuthRepository.swift
├── AvailabilityStatus.swift       ✅ Sprint 1
├── DayAvailability.swift          ✅ Sprint 1
└── UserSchedule.swift             ✅ Sprint 1

UFree/Core/Data/
├── Auth/                          ✅ Sprint 2.5
│   └── FirebaseAuthRepository.swift
├── Mocks/
│   ├── MockAuthRepository.swift   ✅ Sprint 2.5
│   └── MockAvailabilityRepository.swift  ✅ Sprint 1
├── Repositories/
│   ├── SwiftDataAvailabilityRepository.swift  ✅ Sprint 2
│   └── FirebaseAvailabilityRepository.swift   ✅ Sprint 2.5 (skeleton)
└── Persistence/
    └── PersistentDayAvailability.swift  ✅ Sprint 2

UFree/Features/
├── Root/                          ✅ Sprint 2.5
│   ├── RootViewModel.swift
│   ├── RootView.swift
│   └── LoginView.swift
└── MySchedule/                    ✅ Sprint 1-2.5
    ├── MyScheduleViewModel.swift
    └── MyScheduleView.swift

UFree/Core/Extensions/
└── Color+Hex.swift                ✅ Sprint 2.5
```

---

## Test Coverage (90 Total)

| Layer | Tests | Sprint |
|-------|-------|--------|
| Domain Models | 18 | 1 |
| Mock Repository (Availability) | 6 | 1 |
| Persistence Layer | 20 | 2 |
| Use Cases | 4 | 1 |
| User Entity | 7 | 2.5 |
| Mock Repository (Auth) | 10 | 2.5 |
| RootViewModel | 7 | 2.5 |
| MyScheduleViewModel | 11 | 1-2 |
| Color+Hex | 7 | 2.5 |
| **Total** | **90** | — |

---

## Key Features Working End-to-End

1. **Authentication Flow:** App launch → Firebase init → LoginView → anonymous sign-in → MainAppView
2. **Schedule Management:** View 7 days, update status per day (cycles through 5 states: busy → free → morningOnly → afternoonOnly → eveningOnly → busy)
3. **Persistence:** Schedule saved locally via SwiftData (survives app restart)
4. **Auth State:** Real-time UI updates via AsyncStream when user logs in/out
5. **Navigation:** Standard Apple-compliant large title nav bar with Sign Out button
6. **Error Handling:** Past date rejection, network errors, auth failures with rollback

---

## What's Next (Sprint 3)

**Firestore Integration:**
- Implement FirebaseAvailabilityRepository methods
- Define Firestore document schema
- Set up CompositeRepository pattern
- Test with Firebase emulator

**User Experience:**
- Sync schedules to cloud
- Enable friend schedule viewing
- Real-time schedule updates

---

## Technical Highlights

- ✅ Clean Architecture (Domain → Data → Presentation → UI)
- ✅ Protocol-based dependency injection (swap repositories easily)
- ✅ @MainActor isolation for thread safety on auth repos
- ✅ Actor-based mock repositories with `nonisolated` initializers & AsyncStream
- ✅ AsyncStream for reactive auth state (no Combine)
- ✅ Conditional Firebase init (uses MockAuthRepository in tests)
- ✅ Async/await throughout with proper actor isolation patterns
- ✅ Standard Apple-compliant navigation (no custom styling)
- ✅ Zero compiler warnings
- ✅ Zero memory leaks
- ✅ Zero flaky tests

---

## Running Tests

**Quick validation (recommended):**
```bash
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | \
  grep -E '(PASS|FAIL|Test Session|passed|failed|warning)'
```

**Full test output:**
```bash
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

**Run specific test suite:**
```bash
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing UFreeTests/MockAuthRepositoryTests
```

See `AGENTS.md` for troubleshooting and build command details.

---

## UI Terminology & Conventions (Sprint 2.5+)

### App-Level Copy
- **Main Title:** "UFree"
- **Subtitle:** "See when friends are available" (displayed below title in navigation bar)
- **Status Banner Headline:** "Check My Schedule"
- **Status Banner Subheadline:** "Tap to change your live status"

### Navigation Bar Style
- Uses `.navigationTitle("UFree")` for main title string
- Subtitle added via `.toolbar` with `.principal` placement for Apple-compliant large title effect
- Subtitle uses `.subheadline` font with `.gray` foreground color
- Sign Out button: trailing placement via `.toolbar`, dropdown menu (ellipsis icon), destructive role

### Schedule Sections
- **My Week:** Horizontal carousel of day status cards (5 colors: green/busy/yellow/pink/orange)
- **Who's free on...:** Day filter buttons with purple selection highlight

### Empty State
- **Heading:** "No Friends Yet"
- **Subheading:** "Invite friends to see their availability"
- **CTA Button:** "Find Friends" (purple background)

### Availability Status & Colors
| Status | Color | Icon |
|--------|-------|------|
| Free | Green | `checkmark.circle.fill` |
| Busy | Gray | `xmark.circle.fill` |
| Morning Only | Yellow | `sunrise.fill` |
| Afternoon Only | Pink | `sun.max.fill` |
| Evening Only | Orange | `moon.stars.fill` |

### Design System
- **Primary Color:** Purple gradient (`#8180f9` → `#6e6df0`)
- **Large Spacing:** 24pt (between sections)
- **Medium Spacing:** 12pt (within sections)
- **Small Spacing:** 8pt (tight grouping)
- **Card Corner Radius:** 20pt
- **Button Corner Radius:** 8pt
- **Status Banner Corner Radius:** 24pt

---

## Recent Changes

**Navigation Bar & UI Refinement (Sprint 2.5 Final):**
- Removed custom header section from MyScheduleView
- Implemented standard Apple-compliant large title navigation bar with subtitle
- Added subtitle "See when friends are available" below main title "UFree"
- Added Sign Out button via toolbar (right side only, dropdown menu with destructive styling)
- Documented UI terminology and conventions for consistent styling across sprints
- Passed rootViewModel through dependency hierarchy for auth actions
- All 90 tests passing, zero warnings

**Previous: Legacy Code & Test Coverage Cleanup:**
- Removed MVP architecture patterns (Presenters, Adapters, Protocols)
- Removed unused template boilerplate (ContentView, UpdateMyStatusUseCaseViewModel, mapper files)
- Simplified to lean clean architecture
- Repository pattern now the sole abstraction for backend integration
- Added Color+Hex extension tests (7 tests)

---

**Last Updated:** January 1, 2026 | **Status:** Production Ready ✅
