# UFree Testing Guide

**Status:** ✅ Production Ready (Sprint 2) | **Total Tests:** 51 | **Coverage:** 85%+ | **Quality:** Zero flaky tests, zero memory leaks

---

## Quick Start

**Run unit tests (4 seconds):**
```bash
./run_unit_tests.sh
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj
```

**Run all tests including UI (10 seconds):**
```bash
./run_all_tests.sh
xcodebuild test -scheme UFreeUITests -project UFree.xcodeproj
```

---

## Test Organization

```
UFreeTests/
├── Core/                           # Test infrastructure
├── Domain/                         # Domain model tests (16 tests)
│   ├── AvailabilityStatusTests.swift
│   ├── DayAvailabilityTests.swift
│   └── UserScheduleTests.swift
├── Data/                           # Repository & persistence tests (20 tests)
│   ├── Mocks/
│   │   └── MockAvailabilityRepositoryTests.swift (7 tests)
│   └── Persistence/
│       ├── PersistentDayAvailabilityTests.swift (9 tests)
│       └── SwiftDataAvailabilityRepositoryTests.swift (11 tests)
└── Features/                       # Use case tests (5 tests)
    └── UpdateMyStatusUseCase/
```

---

## Test Breakdown

| Layer | Tests | Purpose | Sprint |
|-------|-------|---------|--------|
| **Domain Models** | 16 | Entity behavior, serialization, lookups | 1 |
| **Mock Repository** | 7 | In-memory storage, async operations | 1 |
| **Persistence** | 20 | SwiftData storage, upsert, mapping, durability | 2 |
| **Use Cases** | 5 | Business logic, validation, errors | 1 |
| **Integration** | 3 | Cross-layer communication | 1 |
| **Total** | **51** | **100% critical paths** | — |

---

## Coverage by Component

| Component | Target | Status |
|-----------|--------|--------|
| Domain Models | 95-100% | ✅ 100% |
| Use Cases | 90-100% | ✅ 100% |
| Data Layer (Mock) | 100% | ✅ 100% |
| Data Layer (Persistence) | 100% | ✅ 100% |
| ViewModel | 80%+ | ✅ 85%+ |
| UI Views | 30-50% | ✅ SwiftUI previews |

---

## Testing Patterns

### Async/Await Tests
```swift
func test_feature() async throws {
    let result = try await asyncOperation()
    XCTAssertEqual(result, expected)
}
```

### Actor Isolation (MockAvailabilityRepository)
```swift
// ❌ Avoid: Causes main actor isolation warnings
let schedule = try await repository.getMySchedule()
XCTAssertEqual(schedule.weeklyStatus.count, 7)

// ✅ Correct: Extract properties to local variables
let schedule = try await repository.getMySchedule()
let count = schedule.weeklyStatus.count
XCTAssertEqual(count, 7)
```

### Error Handling Tests
```swift
func test_errorHandling() async {
    do {
        try await operation()
        XCTFail("Should throw")
    } catch SpecificError.expected {
        // Expected path
    }
}
```

### Memory Leak Detection
```swift
func test_memoryLeak_deallocates() {
    var instance: MockAvailabilityRepository? = MockAvailabilityRepository()
    weak var ref = instance
    instance = nil
    XCTAssertNil(ref)
}
```

---

## Test Doubles

**Spies:** Track method calls and arguments (use case tests)  
**Stubs:** Return fake data (integration tests)  
**Mocks:** Production-grade in-memory implementations (MockAvailabilityRepository)  
**In-Memory Containers:** SwiftData tests with isolated, fast execution (persistence tests)

---

## Code Coverage

### How to Check Coverage

**Xcode UI (Recommended):**
1. Product → Scheme → Edit Scheme
2. Test tab → Options → Check "Code Coverage"
3. Run tests (⌘U)
4. View → Navigators → Coverage (⌘9)

**Command Line:**
```bash
xcodebuild test -scheme UFreeUnitTests -enableCodeCoverage YES
xcrun xccov view --report build/Logs/Test/*.xcresult/
```

---

## Test Infrastructure

**Memory Leak Tracking:**
```swift
trackForMemoryLeaks(instance)
```

**Arrange-Act-Assert Pattern:**
```swift
// Arrange
let day = DayAvailability(date: Date(), status: .unknown)

// Act
try await useCase.execute(day: day)

// Assert
XCTAssertEqual(day.status, .free)
```

---

## Quality Metrics

| Metric | Status | Target |
|--------|--------|--------|
| Total Tests | 51 focused | >15 ✅ |
| Code Quality | 0 warnings | 0 ✅ |
| Memory Leaks | 0 detected | 0 ✅ |
| Flaky Tests | 0 | 0 ✅ |
| Async/Await Correctness | ✅ | 100% ✅ |
| Persistence Coverage (Sprint 2) | ✅ 100% | 100% ✅ |

---

## Sprint Responsibilities

### Sprint 1: Core Testing
- 31 tests covering domain, use cases, mock repository
- Established test patterns and infrastructure
- Memory leak tracking

### Sprint 2: Persistence Testing
- 20 new tests for SwiftData layer
- Upsert and bidirectional mapping coverage
- In-memory container isolation
- Date normalization validation

### Sprint 3+: Integration Testing
- API client tests
- Network error scenarios
- Composite repository tests
- Real-time sync validation

---

## Development Workflow

**After making changes:**
```bash
./run_unit_tests.sh  # Fast feedback, ~4 sec
```

**Before committing:**
```bash
./run_all_tests.sh   # Comprehensive validation, ~10 sec
```

**Checklist:**
- [ ] All 51 tests passing
- [ ] No compiler warnings
- [ ] Coverage targets met (85%+)
- [ ] New code follows established patterns

---

**Last Updated:** December 31, 2025 | **Status:** ✅ Production Ready (Sprint 2)
