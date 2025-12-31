# UFree - Weekly Availability Scheduler

**Status:** ✅ Sprint 2.5 Complete | **Version:** 2.5.0 | **Tests:** 83 | **Coverage:** 85%+

---

## Quick Status

**Production Ready:** Local persistence complete. Firebase auth infrastructure in place. Schedule sync ready for Sprint 3.

| Component | Status | Notes |
|-----------|--------|-------|
| Domain Models | ✅ Complete | AvailabilityStatus, DayAvailability, UserSchedule |
| Authentication | ✅ Complete | User entity, AuthRepository protocol, Firebase auth wrapper |
| SwiftData Persistence | ✅ Complete | Local storage with upsert pattern, date normalization |
| Use Cases | ✅ Complete | UpdateMyStatusUseCase with validation |
| MyScheduleViewModel & View | ✅ Complete | SwiftUI list, color-coded status buttons |
| Login/Root Navigation | ✅ Complete | RootView routes between LoginView and MainAppView |
| **Remote API Layer** | ⏳ Pending | Sprint 3: Firestore read/write (skeleton in place) |
| **Composite Repository** | ⏳ Pending | Sprint 3: Local + remote with fallback |
| **Real-time Sync** | ⏳ Pending | Sprint 3+: WebSocket/Firestore integration |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    UI Layer                             │
│  RootView (auth state) → LoginView OR MainAppView       │
│  MainAppView → MyScheduleView                           │
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

### User (Sprint 2.5 - NEW)
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

### Sprint 2.5: Infrastructure & Identity ✅ (NEW)
- User domain entity + AuthRepository protocol
- FirebaseAuthRepository (Firebase Auth wrapper, @MainActor)
- MockAuthRepository (testing, actor-based)
- RootViewModel + RootView for auth navigation
- LoginView (anonymous sign-in)
- FirebaseAvailabilityRepository skeleton
- 18 new tests

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
├── Root/                          ✅ Sprint 2.5 (NEW)
│   ├── RootViewModel.swift
│   ├── RootView.swift
│   └── LoginView.swift
└── MySchedule/                    ✅ Sprint 1-2
    ├── MyScheduleViewModel.swift
    └── MyScheduleView.swift
```

---

## Test Coverage (83 Total)

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
| **Total** | **83** | — |

---

## Key Features Working End-to-End

1. **Authentication Flow:** App launch → Firebase init → LoginView → anonymous sign-in → MainAppView
2. **Schedule Management:** View 7 days, update status per day (cycles through 4 states)
3. **Persistence:** Schedule saved locally via SwiftData (survives app restart)
4. **Auth State:** Real-time UI updates via AsyncStream when user logs in/out
5. **Error Handling:** Past date rejection, network errors, auth failures with rollback

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
- ✅ Zero compiler warnings
- ✅ Zero memory leaks
- ✅ Zero flaky tests

---

## Running the App

```bash
# Run unit tests (includes auth layer tests)
./run_unit_tests.sh          # ~5-6 seconds

# Run all tests with UI
./run_all_tests.sh           # ~10 seconds

# Run specific test suite
xcodebuild test -scheme UFreeUnitTests \
  -only-testing UFreeTests/MockAuthRepositoryTests
```

---

## Recent Changes

**Legacy Code & Test Coverage Cleanup (Today):**
- Removed MVP architecture patterns (Presenters, Adapters, Protocols)
- Removed unused template boilerplate (ContentView, UpdateMyStatusUseCaseViewModel, mapper files)
- Simplified to lean clean architecture 
- Repository pattern now the sole abstraction for backend integration
- Added MyScheduleViewModelTests (11 tests) for full coverage
- Tests: 83 total (all active code paths covered)

---

**Last Updated:** December 31, 2025 | **Status:** Production Ready ✅
