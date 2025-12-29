# UFree - Schedule Availability App
**Engineering Specification**

**Status:** ✅ Sprint 1 Complete | **Version:** 1.0.0 | **Tested:** 21 tests

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

Data:        MockAvailabilityRepository (actor, in-memory)

Presentation: MyScheduleViewModel (@MainActor, @Published)

UI:          MyScheduleView (SwiftUI List)
```

### 5.2 Dependencies
- ViewModel → UpdateMyStatusUseCase, AvailabilityRepository
- UpdateMyStatusUseCase → AvailabilityRepository (injected)
- MyScheduleView → MyScheduleViewModel

### 5.3 Thread Safety
- **Production Mock:** Actor (concurrent safety)
- **Test Spies:** Classes (single-threaded)

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

**Total: 21 tests, 100% essential behavior**

| Component | Tests | Status |
|-----------|-------|--------|
| Domain Models | 16 | ✅ Init, behavior, serialization, memory |
| Use Cases | 4 | ✅ Logic, validation, errors |
| Integration | 1 | ✅ Presenter |

**Quality:** No flaky tests, no memory leaks, async/await correct

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
- No backend connectivity in Sprint 1
- MockAvailabilityRepository has no persistence

**Future Assumptions:**
- Sprint 2 will add local storage
- Sprint 3 will add API layer
- Friends feature uses same UserSchedule model

---

## 11. Error Handling

| Error | Source | Handling |
|-------|--------|----------|
| cannotUpdatePastDate | UseCase | Catch, don't persist, show UI error |
| Repository throws | Data layer | Propagate, catch in ViewModel, rollback |
| Network timeout | Data layer | NSError, caught as NSError |

---

## 12. Performance Requirements

**Target:** All operations complete in <500ms

- `getMySchedule()`: 500ms (mocked delay)
- `updateMySchedule()`: 300ms (mocked delay)
- UI update: <16ms (immediate)

---

## 13. Out of Scope (Sprint 2+)

- Local persistence
- Remote API
- Note editing
- Friend schedules
- Real-time sync
- Push notifications

---

## 14. Files & Metrics

| Component | File | Lines |
|-----------|------|-------|
| Tests | UFreeTests/ | 605 |
| Code | UFree/Core/ | ~320 |
| Docs | README.md, TESTING_GUIDE.md | 230+260 |

---

**Last Updated:** December 29, 2025 | **Status:** Production Ready ✅
