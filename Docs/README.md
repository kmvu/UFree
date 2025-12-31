# UFree - Weekly Availability Scheduler

**Status:** ✅ Sprint 2 Complete | **Version:** 2.0.0 | **Tests:** 51 | **Coverage:** 85%+

---

## Quick Status

**Production Ready:** Local persistence fully implemented. All core features tested and working. Ready for Sprint 3 (remote API integration).

| Component | Status | Notes |
|-----------|--------|-------|
| Domain Models | ✅ Complete | AvailabilityStatus, DayAvailability, UserSchedule - stable API |
| Mock Repository | ✅ Complete | In-memory testing, actor-based for thread safety |
| SwiftData Persistence | ✅ Complete | Local storage with upsert pattern, date normalization |
| Update Status Use Case | ✅ Complete | Validation for past dates, error handling |
| MyScheduleViewModel | ✅ Complete | State management, immediate UI updates with rollback |
| MyScheduleView (UI) | ✅ Complete | SwiftUI list, color-coded status buttons |
| **Remote API Layer** | ⏳ Pending | Sprint 3: Cloud sync via Composite Repository |
| **Real-time Sync** | ⏳ Pending | Sprint 3: WebSocket/Firestore integration |
| **Friend Schedules** | ⏳ Pending | Sprint 3+: Uses existing UserSchedule model |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ MyScheduleView (SwiftUI)                              │  │
│  │ - List of 7 days, color-coded status buttons          │  │
│  │ - Tap to cycle status, error alerts                   │  │
│  └───────────────────────────────────────────────────────┘  │
│                           ↓                                  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ MyScheduleViewModel (@MainActor)                      │  │
│  │ - State: @Published weeklyStatus: [DayAvailability]   │  │
│  │ - Methods: loadSchedule(), toggleStatus()             │  │
│  │ - Error handling: rollback on failure                 │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                   Presentation Layer (DONE)                 │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                    Domain Layer (DONE)                       │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ UpdateMyStatusUseCase                                 │  │
│  │ - Validate date not in past                           │  │
│  │ - Call repository.updateMySchedule()                  │  │
│  │ - Throw UpdateMyStatusUseCaseError.cannotUpdatePastD. │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ AvailabilityRepository (protocol)                     │  │
│  │ - getMySchedule() → UserSchedule                      │  │
│  │ - updateMySchedule(for: DayAvailability)              │  │
│  │ - getFriendsSchedules() → [UserSchedule]              │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                     Data Layer                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ SwiftDataAvailabilityRepository (@MainActor) - PROD   │  │
│  │ - Reads/writes to SwiftData container                 │  │
│  │ - Upsert pattern for updates                          │  │
│  │ - Date normalization (midnight)                       │  │
│  │ ⏳ NEXT: Add RemoteAvailabilityRepository (Sprint 3)   │  │
│  │ ⏳ NEXT: Create CompositeRepository pattern            │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ MockAvailabilityRepository (actor) - TESTING          │  │
│  │ - In-memory storage for unit tests                    │  │
│  │ - Thread-safe via actor isolation                     │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ PersistentDayAvailability (SwiftData model)           │  │
│  │ - Bidirectional mapping to DayAvailability            │  │
│  │ - Date normalization constraint                       │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                  SwiftData Container                         │
│  - In-memory for tests, persistent for production           │
└─────────────────────────────────────────────────────────────┘
```

---

## File Structure & Current State

### Domain Layer (Stable)
```
UFree/Core/Domain/
├── AvailabilityStatus.swift         ✅ Enum with 4 states, Codable
├── DayAvailability.swift            ✅ Identifiable, mutable status/note
├── UserSchedule.swift               ✅ Contains exactly 7 DayAvailability
├── AvailabilityRepository.swift      ✅ Protocol (3 methods)
└── UseCases/
    └── UpdateMyStatusUseCase.swift   ✅ Validates past date, propagates errors
```

### Data Layer (Partially Complete)
```
UFree/Core/Data/
├── Mocks/
│   └── MockAvailabilityRepository.swift  ✅ Actor, in-memory storage, thread-safe
├── Repositories/
│   └── SwiftDataAvailabilityRepository.swift  ✅ @MainActor, upsert pattern
└── Persistence/
    ├── PersistentDayAvailability.swift       ✅ SwiftData model, bidirectional mapping
    └── ⏳ RemoteAvailabilityRepository.swift  (Pending Sprint 3)
    └── ⏳ CompositeRepository.swift           (Pending Sprint 3)
```

### Presentation Layer (Complete)
```
UFree/Features/MySchedule/
├── Presentation/
│   └── MyScheduleViewModel.swift     ✅ @MainActor, state management
└── UI/
    └── MyScheduleView.swift          ✅ SwiftUI List with status buttons
```

### Tests (Comprehensive)
```
UFreeTests/
├── Domain/                           ✅ 16 tests
│   ├── AvailabilityStatusTests
│   ├── DayAvailabilityTests
│   └── UserScheduleTests
├── Data/
│   ├── Mocks/
│   │   └── MockAvailabilityRepositoryTests  ✅ 7 tests
│   └── Persistence/
│       ├── PersistentDayAvailabilityTests   ✅ 9 tests
│       └── SwiftDataAvailabilityRepositoryTests  ✅ 11 tests
└── Features/                         ✅ 5 tests
    └── UpdateMyStatusUseCase/
```

---

## Current Implementation Details

### Domain Models (Sprint 1 - Complete)
```swift
// AvailabilityStatus: Int-backed enum
// DayAvailability: Struct with UUID id, Date, status, optional note
// UserSchedule: Aggregate with 7 consecutive DayAvailability objects
```

### Data Layer (Sprint 2 - Complete)
**SwiftDataAvailabilityRepository:**
- @MainActor for thread safety
- Upsert pattern: checks existing record by date, updates or inserts
- Date normalization: all dates stored at midnight
- Uses PersistentDayAvailability as persistence model

**PersistentDayAvailability:**
- SwiftData @Model with @Attribute(\.unique) for id
- Maps bidirectionally to domain DayAvailability
- Stores note as optional String

**MockAvailabilityRepository:**
- Actor-based for concurrent test access
- In-memory array storage
- Simulated 500ms/300ms delays for testing

### Presentation Layer (Sprint 1 - Complete)
**MyScheduleViewModel:**
- @MainActor with @Published properties
- Async operation for load/update without blocking UI
- Error handling with state rollback
- toggleStatus() cycles: unknown → free → busy → eveningOnly

### UI Layer (Sprint 1 - Complete)
**MyScheduleView:**
- SwiftUI List with 7 rows
- Status button with color coding
- Tap to cycle, shows error alerts

---

## Test Coverage (51 Tests Total)

| Layer | Tests | Details |
|-------|-------|---------|
| Domain | 16 | All model initialization, behavior, serialization |
| Mock Repo | 7 | Storage, async, protocol conformance |
| Persistence | 20 | Upsert, mapping, durability, date normalization |
| Use Cases | 5 | Validation, error handling, async |
| Integration | 3 | Cross-layer communication |

**All tests use:**
- Async/await patterns
- Actor isolation handling (extract properties before assertions)
- Arrange-Act-Assert structure
- In-memory containers (no disk I/O)

---

## Dependencies & Integrations

**Production App Initialization (UFreeApp.swift):**
```swift
let container = ModelContainer(for: PersistentDayAvailability.self)
let repository = SwiftDataAvailabilityRepository(container: container)
let useCase = UpdateMyStatusUseCase(repository: repository)
let viewModel = MyScheduleViewModel(useCase: useCase, repository: repository)
```

**Testing Initialization:**
```swift
let repository = MockAvailabilityRepository()  // Actor-based, thread-safe
```

---

## Key Decisions & Patterns

1. **Repository Protocol First:** Enables multiple implementations (Mock, SwiftData, Remote)
2. **Domain Entities are Swift Structs:** Codable, SwiftData-free, reusable
3. **Persistence Model Separate:** PersistentDayAvailability maps to/from domain
4. **Actor for Thread Safety:** MockAvailabilityRepository is actor for concurrent tests
5. **@MainActor for UI:** ViewModel and production repo isolated to main thread
6. **Upsert Pattern:** SwiftData inserts new or updates existing by date
7. **Date Normalization:** All dates stored at midnight, no time component

---

## What's Ready for Next Sprint (Sprint 3)

### Remote API Layer
**What to build:**
- `RemoteAvailabilityRepository` - Implements AvailabilityRepository protocol
- HTTP client wrapper (URLSession or third-party)
- Network error handling with retry logic
- API endpoint definitions for:
  - GET /schedule (fetch user's schedule)
  - PATCH /schedule/{dayId} (update day status)
  - GET /friends (fetch friends' schedules)

**Where to add:**
```
UFree/Core/Data/Repositories/RemoteAvailabilityRepository.swift
UFree/Core/Data/Network/HTTPClient.swift  (or similar)
```

### Composite Repository Pattern
**What to build:**
- `CompositeAvailabilityRepository` - Combines local + remote
- Logic: Try remote first, fallback to local on failure
- Sync strategy: Update local after remote succeeds

**Where to add:**
```
UFree/Core/Data/Repositories/CompositeAvailabilityRepository.swift
```

### Real-time Sync (Optional for Sprint 3)
- WebSocket listener for schedule changes
- Firestore integration as alternative to custom API
- Push updates to local storage

### Friend Schedules
- Reuses existing `UserSchedule` model
- Filter/search friends
- Display in list alongside own schedule

---

## Known Constraints & Technical Debt

**None currently.** Sprint 1 & 2 completed with:
- ✅ Zero compiler warnings
- ✅ Zero flaky tests
- ✅ Zero memory leaks
- ✅ Clean architecture enforced
- ✅ 85%+ test coverage

---

## How to Continue Development

**Start Sprint 3:**
1. Review this README for current state
2. Focus on RemoteAvailabilityRepository (implement AvailabilityRepository protocol)
3. Run `./run_unit_tests.sh` after each change
4. All existing tests should still pass (Liskov Substitution Principle)
5. Add network tests in `UFreeTests/Data/Network/`

**Add new features:**
1. Identify which layer: Domain (entity), Data (repository), Presentation (ViewModel), or UI (View)
2. Check AGENTS.md for code style
3. Check TESTING_GUIDE.md for test patterns
4. Write tests first (TDD approach recommended)
5. Target 85%+ coverage on new code

---

**Last Updated:** December 31, 2025 | **Status:** Production Ready ✅
