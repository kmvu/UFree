# UFree - Weekly Availability Scheduler

**Status:** ✅ Sprint 2.5+ (UI Enhancements) | **Version:** 2.5.2 | **Tests:** 106 | **Coverage:** 85%+

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

## Architecture Evolution (Sprint 1 → 3)

### Sprint 1-2: Local-Only Foundation
```
UI → ViewModel → Repository → SwiftData
```
- Single source of truth: SwiftData
- Fully functional offline
- No network layer

### Sprint 2.5: Auth Infrastructure
```
UI → ViewModel → FirebaseAuthRepository → Firebase Auth
     ↓ (also)
     RootViewModel (auth state management)
```
- Added anonymous authentication
- Firebase Auth initialization
- AsyncStream for reactive auth state

### Sprint 3: Cloud-Synced (Offline-First)
```
UI → ViewModel → CompositeRepository → SwiftData (Local) [instant]
                       ↓ (background)
                       FirebaseAvailabilityRepository → Firestore
                              ↓ (on success)
                       Syncs back to SwiftData
```
- **Local-first:** UI always gets instant data
- **Background sync:** Remote fetch doesn't block
- **Resilient:** Works offline, syncs when connected
- **Clean:** No Firebase in Domain layer

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
├── AvailabilityStatus+Colors.swift ✅ Sprint 2.5+ (refactor)
├── DayAvailability.swift          ✅ Sprint 1
└── UserSchedule.swift             ✅ Sprint 1

UFree/Core/Data/
├── Auth/                          ✅ Sprint 2.5
│   └── FirebaseAuthRepository.swift
├── Network/                       ⏳ Sprint 3
│   └── FirestoreDayDTO.swift      (DTO for Firestore ↔ Domain mapping)
├── Mocks/
│   ├── MockAuthRepository.swift   ✅ Sprint 2.5
│   └── MockAvailabilityRepository.swift  ✅ Sprint 1
├── Repositories/
│   ├── SwiftDataAvailabilityRepository.swift  ✅ Sprint 2
│   ├── FirebaseAvailabilityRepository.swift   ⏳ Sprint 3 (implement)
│   └── CompositeAvailabilityRepository.swift  ⏳ Sprint 3 (new)
└── Persistence/
    └── PersistentDayAvailability.swift  ✅ Sprint 2

UFree/Features/
├── Root/                          ✅ Sprint 2.5
│   ├── RootViewModel.swift
│   ├── RootView.swift
│   └── LoginView.swift
└── MySchedule/                    ✅ Sprint 1-2.5+
    ├── MyScheduleViewModel.swift
    ├── MyScheduleView.swift (refactored)
    ├── StatusBannerView.swift     ✅ Sprint 2.5+ (extracted)
    ├── StatusBannerViewModel.swift ✅ Sprint 2.5+
    ├── DayStatusCardView.swift    ✅ Sprint 2.5+ (extracted)
    ├── DayFilterButtonView.swift  ✅ Sprint 2.5+ (extracted)
    ├── DayFilterViewModel.swift   ✅ Sprint 2.5+
    └── UserStatus.swift           ✅ Sprint 2.5+

UFree/Core/Extensions/
├── Color+Hex.swift                ✅ Sprint 2.5
└── ButtonStyles.swift             ✅ Sprint 2.5+ (extracted)
```

---

## Test Coverage (106 Total)

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
| StatusBannerViewModel | 10 | 2.5+ |
| DayFilterViewModel | 6 | 2.5+ |
| **Total** | **106** | — |

---

## Key Features Working End-to-End

1. **Authentication Flow:** App launch → Firebase init → LoginView → anonymous sign-in → MainAppView
2. **Schedule Management:** View 7 days, update status per day (cycles through 5 states: busy → free → morningOnly → afternoonOnly → eveningOnly → busy)
3. **Status Banner:** Initial state "Check My Schedule" with one-way cycling to Busy ↔ Free cycle, gradient colors, icon transitions, and rapid-tap protection
4. **Day Filtering:** Select individual days to filter schedule; state managed via DayFilterViewModel with toggle behavior
5. **Persistence:** Schedule saved locally via SwiftData (survives app restart)
6. **Auth State:** Real-time UI updates via AsyncStream when user logs in/out
7. **Navigation:** Standard Apple-compliant large title nav bar with Sign Out button
8. **Error Handling:** Past date rejection, network errors, auth failures with rollback

---

## Sprint 3: Cloud Sync & Resilience (Upcoming)

**Architecture: Offline-First Pattern**

Instead of replacing SwiftData with Firestore, we chain them for resilience:
1. UI requests data
2. Composite Repository returns Local Data (SwiftData) immediately (instant, offline-capable)
3. Composite Repository triggers Remote Fetch (Firebase) in background
4. On success: Remote data syncs into Local Data
5. UI updates automatically (observes Local Data)

**Benefits:**
- Never shows loading spinner for user's own schedule
- Works offline (local data always available)
- Syncs in background (non-blocking)
- Clean Architecture preserved (no Firebase in Domain layer)

**Implementation Roadmap:**

Step 3.1: Create FirestoreDayDTO.swift
- DTO for mapping Firestore documents to DayAvailability
- Encoder: DayAvailability → Firestore JSON
- Decoder: Firestore JSON → DayAvailability

Step 3.2: Implement FirebaseAvailabilityRepository.swift
- updateMySchedule(day:) - Write to Firestore at users/{uid}/availability/{YYYY-MM-DD}
- getMySchedule() - Query Firebase for current week availability
- Handle date normalization (YYYY-MM-DD format)
- Map Firebase responses via FirestoreDayDTO

Step 3.3: Create CompositeAvailabilityRepository.swift
- Orchestrate Local + Remote sync
- updateMySchedule: Optimistic local update + background remote sync
- getMySchedule: Return local immediately + background refresh
- Error resilience (remote failures don't block UI)

**Firestore Schema (NoSQL Document Structure):**

```
Collection: users
├── Document: {auth_uid}
│   ├── displayName: String
│   ├── lastUpdated: Timestamp
│   └── Subcollection: availability
│       ├── Document: 2026-01-01
│       │   ├── status: Int (0=Busy, 1=Free, 2=MorningOnly, 3=AfternoonOnly, 4=EveningOnly)
│       │   ├── note: String? (optional)
│       │   └── updatedAt: Timestamp
│       ├── Document: 2026-01-02
│       └── ... (one doc per day)
```

**Security Rules (Firebase Console):**

Copy/paste into Firestore Security Rules tab:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check ownership
    function isOwner(userId) {
      return request.auth != null && request.auth.uid == userId;
    }

    // User Profiles
    match /users/{userId} {
      allow read: if request.auth != null; // Friends can read
      allow write: if isOwner(userId);     // Only you can write
      
      // Availability Subcollection
      match /availability/{dayId} {
        allow read: if request.auth != null;
        allow write: if isOwner(userId);
      }
    }
  }
}
```

**Why This Schema?**
- Scalable: Only fetch days you need (current week), not entire history
- Queryable: Later enable "Collection Group Query" to find all users free on specific date
- Practical: YYYY-MM-DD document ID matches DayAvailability date normalization
- Subcollections: Avoid fetching user profile every time you query availability

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
- **Status Banner Subheadline:** "Tap to change your live status" (applies to all UserStatus states)

### Navigation Bar Style
- Uses `.navigationTitle("UFree")` for main title string
- Subtitle added via `.toolbar` with `.principal` placement for Apple-compliant large title effect
- Subtitle uses `.subheadline` font with `.gray` foreground color
- Sign Out button: trailing placement via `.toolbar`, dropdown menu (ellipsis icon), destructive role

### Schedule Sections
- **My Week:** Horizontal carousel of day status cards (5 colors: green/busy/yellow/orange/purple)
- **Status Banner:** Interactive banner showing user's current live status (Check Schedule, Busy, Free) with gradient colors and cycling behavior
- **Who's free on...:** Day filter buttons with purple selection highlight managed by DayFilterViewModel

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
| Afternoon Only | Orange | `sun.max.fill` |
| Evening Only | Purple | `moon.stars.fill` |

### Status Banner States & Cycling
- **Check My Schedule:** Purple gradient (`#8180f9` → `#6e6df0`), moon icon — Initial state only
- **Busy Right Now:** Gray/blue gradient (`#7da0c2` → `#637d96`), cup and saucer icon
- **I'm Free Now!:** Green gradient (`#6dd69c` → `#5abf87`), bolt icon
- **Cycling Behavior:** First tap goes from Check My Schedule → Busy. After that, cycles between Busy ↔ Free indefinitely.
- **Primary Color:** Purple gradient (`#8180f9` → `#6e6df0`)
- **Large Spacing:** 24pt (between sections)
- **Medium Spacing:** 12pt (within sections)
- **Small Spacing:** 8pt (tight grouping)
- **Card Corner Radius:** 20pt
- **Button Corner Radius:** 8pt
- **Status Banner Corner Radius:** 24pt
- **Status Banner Height:** 110pt
- **Processing State:** Subtle border overlay (not opaque fill) to maintain visibility

---

## Recent Changes

**Code Architecture Refactoring (Sprint 2.5+):**

*Component Extraction (5 new files):*
- Extracted `StatusBannerView.swift` (70 lines) - Standalone status banner UI with icon transitions, gradient animations, border overlay. Instantiates StatusBannerViewModel for state. Includes preview.
- Extracted `DayStatusCardView.swift` (62 lines) - Reusable day status card for weekly schedule. Stateless component receiving day, color, and onTap callback. Spring animation on status change. Includes preview.
- Extracted `DayFilterButtonView.swift` (44 lines) - Reusable day selection button for "Who's free on..." section. Props: day, isSelected, onTap. Purple selection highlight with toggle behavior. Includes preview.
- Extracted `ButtonStyles.swift` (13 lines) - Centralized custom button styles in UFree/Core/Extensions/. Contains NoInteractionButtonStyle for removing default button highlight flash. Reusable across entire UI layer.
- Created `AvailabilityStatus+Colors.swift` (22 lines) - Domain-level color mapping extension. Property: `displayColor: Color`. Eliminates custom `colorFor()` function. Reusable everywhere status color is needed.

*MyScheduleView Refactor:*
- Reduced MyScheduleView from 323 lines to 139 lines (57% reduction)
- Now focuses on layout orchestration only: displays sections, handles navigation, error handling
- Replaced embedded StatusBanner component with StatusBannerView()
- Replaced embedded DayStatusCard component with DayStatusCardView()
- Replaced inline day filter buttons with DayFilterButtonView()
- Replaced custom colorFor() function with status.displayColor property
- Cleaner section views (myWeekCarouselSection, whosFreOnFilterSection, emptyStateSection) with clear responsibilities

*Architecture Benefits:*
- Single responsibility per file: easier to test, maintain, and extend
- Reusability: Components can be used in friend schedules (Sprint 3) and other screens
- Testability: Components have previews for visual validation; ViewModels isolated for unit testing
- Maintainability: Changes to components isolated to their files; easy to find component-specific code
- All 106 tests remain passing, zero warnings, zero compiler warnings

**Status Banner & Day Filter UI Enhancements (Sprint 2.5+):**
- Created `UserStatus` enum with three states: checkSchedule, busy, free
- Each state has custom title, icon, and gradient colors
- Implemented `StatusBannerViewModel` to manage state with rapid-tap protection (guard clause)
- Multi-stage animation: 0.5s processing phase (border overlay) → state transition with text slide animation + gradient color change
- Created `DayFilterViewModel` to manage day selection state (toggle behavior)
- Updated DayStatusCard colors: Pink → Orange for afternoonOnly, Orange → Purple for eveningOnly
- Day names and numbers now use status color instead of grey
- Established tappable component pattern: All interactive components have dedicated ViewModels with rapid-tap protection
- Added comprehensive unit tests: StatusBannerViewModelTests (10 tests covering rapid-tap scenarios) and DayFilterViewModelTests (6 tests)
- Custom `NoInteractionButtonStyle` to remove default button highlight flash

**Previous: Navigation Bar & UI Refinement (Sprint 2.5):**
- Removed custom header section from MyScheduleView
- Implemented standard Apple-compliant large title navigation bar with subtitle
- Added subtitle "See when friends are available" below main title "UFree"
- Added Sign Out button via toolbar (right side only, dropdown menu with destructive styling)
- Documented UI terminology and conventions for consistent styling across sprints
- Passed rootViewModel through dependency hierarchy for auth actions

**Earlier: Legacy Code & Test Coverage Cleanup:**
- Removed MVP architecture patterns (Presenters, Adapters, Protocols)
- Removed unused template boilerplate (ContentView, UpdateMyStatusUseCaseViewModel, mapper files)
- Simplified to lean clean architecture
- Repository pattern now the sole abstraction for backend integration
- Added Color+Hex extension tests (7 tests)

---

---

## Component Architecture (Sprint 2.5+)

### Tappable Component Pattern

All interactive/tappable UI components follow a standardized pattern to prevent rapid-tap issues and maintain consistent UX:

1. **Extract state management to a ViewModel** (one ViewModel per component type)
   - ViewModel handles all state: processing flags, data updates, cycling logic
   - Prevents rapid-tap issues and logic duplication
   - Marked with `@MainActor` for thread safety
   - Conforms to `ObservableObject` with `@Published` properties

2. **Extract component views to separate files** for reusability
   - Each component in its own file (e.g., `{Component}View.swift`)
   - Include preview for design iteration without app launch
   - Parent view stays lean, orchestrating component layout only

3. **Implement rapid-tap protection** using guard clause
   ```swift
   func handleTap() {
       guard !isProcessing else { return }  // Prevent concurrent taps
       isProcessing = true
       // ... async operation ...
   }
   ```

4. **Add comprehensive unit tests** covering rapid-tap scenarios
   - Test single tap → correct state update
   - Test rapid taps → ignored while processing, final state is correct
   - Test sequential taps → each processed correctly

### Component Inventory

**Stateful Components (with ViewModels):**
| Component | ViewModel | Lines | Tests | Purpose |
|-----------|-----------|-------|-------|---------|
| StatusBannerView | StatusBannerViewModel | 70 | 10 | Status cycling (Check Schedule → Free → Busy ↔) with 0.3s processing |
| DayFilterButtonView* | DayFilterViewModel | 44 | 6 | Day selection toggle for "Who's free on..." filter |

**Stateless Components (presentation only):**
| Component | Props | Lines | Purpose |
|-----------|-------|-------|---------|
| DayStatusCardView | day, color, onTap | 62 | Reusable day card with icon, status text, spring animation |

**Shared Utilities:**
| File | Location | Purpose |
|------|----------|---------|
| ButtonStyles.swift | UFree/Core/Extensions/ | NoInteractionButtonStyle (removes default highlight flash) |
| AvailabilityStatus+Colors.swift | UFree/Core/Domain/ | Domain-level color mapping (`displayColor` property) |

\* DayFilterViewModel is instantiated in MyScheduleView, not in the button itself (parent-managed state)

### MyScheduleView Architecture

**Layout Orchestration (139 lines):**
```
MyScheduleView
├── navigationTitle & toolbar (Sign Out)
├── ScrollView
│   ├── StatusBannerView() — uses StatusBannerViewModel internally
│   ├── myWeekCarouselSection
│   │   └── ForEach day → DayStatusCardView (stateless, uses day.status.displayColor)
│   └── whosFreOnFilterSection
│       └── ForEach day → DayFilterButtonView (stateless, uses dayFilterViewModel.selectedDay)
└── emptyStateSection
```

**Key Design:**
- MyScheduleView only handles layout, navigation, error alerts
- Component state managed by dedicated ViewModels (StatusBannerViewModel) or parent (DayFilterViewModel)
- Color mapping via domain extension (status.displayColor), not view-level helper functions
- All sub-components have previews for independent design iteration

### Benefits of This Architecture

1. **Reusability:** DayStatusCardView can be used in friend schedules (Sprint 3); ButtonStyles used globally; Color extension eliminates duplication
2. **Testability:** Each component has independent preview; ViewModels isolated for unit testing; no tight coupling
3. **Maintainability:** Single responsibility per file; changes isolated; clear dependency flow
4. **Scalability:** Easy to add new components following the same pattern; new button styles added to ButtonStyles.swift; new status colors added to AvailabilityStatus+Colors.swift

---

**Last Updated:** January 1, 2026 | **Status:** Production Ready ✅

**Status Banner Cycling Update:**
- Changed initial tap flow: "Check My Schedule" → "I'm Free Now!" (instead of "Busy Right Now")
- Subsequent cycles: Free ↔ Busy indefinitely

