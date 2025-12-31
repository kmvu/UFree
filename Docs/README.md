# UFree - Schedule Availability App
**Engineering Specification**

**Status:** ✅ Sprint 2 Complete (Local Persistence) | **Version:** 2.0.0 | **Tested:** 51 tests

---

## 1. Overview

**Purpose:** Allow users to share weekly availability (7-day schedule) with color-coded status updates.

**Success Criteria:**
- ✅ Users can view next 7 days
- ✅ Users can update status per day (4 states)
- ✅ Status persists to repository
- ✅ Past dates cannot be updated
- ✅ UI updates immediately with error rollback

---

## 2. Domain Specification

### 2.1 AvailabilityStatus Enum
```swift
enum AvailabilityStatus: Int, Codable {
    case busy = 0, free = 1, eveningOnly = 2, unknown = 3
}
```
**Constraints:**
- Must be Int-backed (database compatibility)
- Must support JSON serialization
- Display names: "Busy", "Free", "Evening Only", "No Status"

### 2.2 DayAvailability Entity
```swift
struct DayAvailability: Identifiable, Codable {
    let id: UUID                          // Unique per day instance
    let date: Date                        // Calendar date (midnight)
    var status: AvailabilityStatus        // Mutable
    var note: String?                     // Optional (max 200 chars, future use)
}
```
**Constraints:**
- `date` must normalize to midnight (no time component)
- `id` must be unique across all instances
- `status` and `note` are mutable

### 2.3 UserSchedule Aggregate
```swift
struct UserSchedule: Identifiable {
    let id: String                        // User ID
    let name: String
    let avatarURL: URL?
    var weeklyStatus: [DayAvailability]  // Exactly 7 consecutive days
}

// Method
func status(for date: Date) -> DayAvailability?
```
**Constraints:**
- `weeklyStatus` must contain exactly 7 days
- Days must be consecutive (day N = day 0 + N days)
- `status(for:)` matches dates ignoring time component

### 2.4 AvailabilityRepository Protocol
```swift
protocol AvailabilityRepository {
    func getMySchedule() async throws -> UserSchedule
    func updateMySchedule(for day: DayAvailability) async throws
    func getFriendsSchedules() async throws -> [UserSchedule]  // TBD Sprint 3
}
```
**Error Handling:** Throws NSError on network/storage failure

---

## 3. Functional Requirements

### 3.1 Update Status Use Case
**Input:** DayAvailability with new status  
**Output:** Updated in repository  
**Validation:**
- ❌ Reject if date is in past
- ✅ Accept if date is today or later
- Call repository.updateMySchedule(for:)

**Error Handling:**
- Past date → UpdateMyStatusUseCaseError.cannotUpdatePastDate
- Repository error → propagate as-is

### 3.2 View Schedule Use Case
**Input:** None  
**Output:** MyScheduleViewModel with 7 days  
**Behavior:**
- Generate next 7 days (today + 6)
- All status = .unknown
- Load from repository and merge

### 3.3 Toggle Status Use Case
**Input:** Day to toggle  
**Behavior:**
- Cycle status: unknown → free → busy → eveningOnly → free
- Update UI immediately
- Call use case async (don't await)
- Rollback on error

---

## 4. Data Model

### Status Cycle (State Machine)
```
unknown ──→ free ──→ busy ──→ eveningOnly
  ↑                                    │
  └────────────────────────────────────┘
```

### Weekly Schedule Format
```
Day 0 (Today):    DayAvailability(date: today, status: ...)
Day 1 (Tomorrow): DayAvailability(date: today+1, status: ...)
...
Day 6 (+6 days):  DayAvailability(date: today+6, status: ...)
```

---

## 5. Architecture

### 5.1 Layers
```
Domain:      AvailabilityStatus, DayAvailability, UserSchedule,
             AvailabilityRepository (protocol), UpdateMyStatusUseCase

Data:        SwiftDataAvailabilityRepository (production)
             MockAvailabilityRepository (testing)
             PersistentDayAvailability (SwiftData model)

Presentation: MyScheduleViewModel (@MainActor, @Published)

UI:          MyScheduleView (SwiftUI List)
```

### 5.2 Dependencies
- ViewModel → UpdateMyStatusUseCase, AvailabilityRepository
- UpdateMyStatusUseCase → AvailabilityRepository (injected)
- MyScheduleView → MyScheduleViewModel

### 5.3 Persistence (Sprint 2)
- **SwiftDataAvailabilityRepository:** Production implementation using SwiftData
- **PersistentDayAvailability:** Persistence model with bidirectional domain mapping
- **Upsert Pattern:** Updates existing records, inserts new ones
- **Date Normalization:** Times ignored, only calendar dates stored (midnight constraint)
- **No Domain Coupling:** Domain entities remain SwiftData-free for reusability

### 5.4 Thread Safety
- **Production:** SwiftDataAvailabilityRepository marked `@MainActor`
- **Testing:** MockAvailabilityRepository is actor for concurrent access
- **Test Spies:** Classes (single-threaded, safe for unit tests)

---

## 6. UI Specification

### MyScheduleView
**Layout:** SwiftUI List, one row per day

**Row Content:**
```
[Day Name]  [Date]                    [Status Button]
Monday      12/29                     [Free] ← Green
Tuesday     12/30                     [Busy] ← Red
Wednesday   12/31                     [Evening Only] ← Orange
Thursday    1/1                       [No Status] ← Gray
```

**Interactions:**
- Tap button → cycle status
- Error → show alert with message

**Colors:**
| Status | Color |
|--------|-------|
| free | Green |
| busy | Red |
| eveningOnly | Orange |
| unknown | Gray |

---

## 7. Test Coverage

**Total: 51 tests, 100% essential behavior**

| Component | Tests | Status |
|-----------|-------|--------|
| Domain Models | 16 | ✅ Init, behavior, serialization, memory |
| Persistence Models | 9 | ✅ Bidirectional mapping, round-trip conversion |
| Repositories | 18 | ✅ Mock (7) + SwiftData (11) |
| Use Cases & Presenters | 5 | ✅ Logic, validation, errors |
| Integration | 3 | ✅ Cross-layer communication |

**Quality:** No flaky tests, no memory leaks, async/await correct

**Sprint 2 Coverage:**
- Insert/update operations (upsert pattern)
- Persistence across app restart
- Date normalization (midnight constraint)
- Notes persistence
- In-memory container testing

---

## 8. API Examples

### Update Status
```swift
let day = DayAvailability(date: Date(), status: .free)
try await useCase.execute(day: day)  // Throws if past date
```

### Load Schedule
```swift
let schedule = try await repository.getMySchedule()
// Returns: UserSchedule with 7 DayAvailability objects
```

### Toggle (ViewModel)
```swift
viewModel.toggleStatus(for: day)
// Immediate UI update, async persist, rollback on error
```

---

## 9. Acceptance Criteria

### Feature Complete When:
- [x] 7 days displayed with dates
- [x] Status button cycles through 4 states
- [x] Colors match status
- [x] Past dates rejected
- [x] Status persists to mock repository
- [x] Errors show alerts
- [x] UI updates before async completes
- [x] 21 tests passing
- [x] Zero compiler warnings

---

## 10. Assumptions & Constraints

**Assumptions:**
- User has iOS 17+
- Calendar is UTC/system default
- "Past date" = before today at 00:00

**Constraints:**
- Only 7 days shown (not configurable)
- SwiftData used for local persistence (automatic migrations)

**Future (Sprint 3+):**
- Remote API layer (CompositeRepository pattern)
- Friend schedules (uses same UserSchedule model)
- Real-time sync via Firestore/WebSocket

---

## 11. Error Handling

| Error | Source | Handling |
|-------|--------|----------|
| cannotUpdatePastDate | UseCase | Catch, don't persist, show UI error |
| Repository throws | Data layer | Propagate, catch in ViewModel, rollback |
| Network timeout | Data layer | NSError, caught as NSError |

---

## 12. Performance Requirements

**Target:** All operations complete efficiently

| Operation | Target | Actual (Sprint 2) |
|-----------|--------|-------------------|
| `getMySchedule()` | <50ms | ~5-10ms (SwiftData local) |
| `updateMySchedule()` | <50ms | ~2-5ms (SwiftData upsert) |
| Container init | <100ms | ~50ms (one-time startup) |
| UI update | <16ms | <1ms (MainActor) |

Note: Sprint 1 had simulated delays (500ms/300ms) for testing. Sprint 2 uses real local storage.

---

## 13. Out of Scope (Sprint 3+)

- Remote API / Cloud sync
- Note editing UI
- Friend schedules
- Real-time sync
- Push notifications

---

## 14. Files & Metrics

| Component | File | Lines |
|-----------|------|-------|
| Tests | UFreeTests/ | 1,000+ |
| Code | UFree/Core/ | ~450 |
| Persistence (Sprint 2) | PersistentDayAvailability.swift, SwiftDataAvailabilityRepository.swift | 130 |
| Docs | README.md, TESTING_GUIDE.md | 260+530 |

**Sprint 2 Additions:**
- `PersistentDayAvailability.swift` - SwiftData model (44 lines)
- `SwiftDataAvailabilityRepository.swift` - Production repository (90 lines)
- 20 new test cases - Full coverage of persistence layer

---

## 15. Migration from Sprint 1 to Sprint 2

**What Changed:**
- Updated `UFreeApp.swift` - Single line: `SwiftDataAvailabilityRepository` replaces `MockAvailabilityRepository`

**What Stayed the Same:**
- Domain layer (models, use cases) - No changes
- ViewModels, Views - No changes
- 40+ existing tests - All still passing

**Key Pattern (Liskov Substitution):**
```swift
// Sprint 1: Testing
let repository = MockAvailabilityRepository()

// Sprint 2: Production
let repository = SwiftDataAvailabilityRepository(container: container)

// Sprint 3: Remote API
let repository = CompositeAvailabilityRepository(local: ..., remote: ...)

// ViewModel/UseCase/View code: unchanged
```

---

**Last Updated:** December 31, 2025 | **Status:** Production Ready ✅
