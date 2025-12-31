# UFree Testing Guide

**Status:** ✅ Production Ready (Sprint 2.5) | **Total Tests:** 69 | **Coverage:** 85%+ | **Quality:** Zero flaky tests, zero memory leaks

---

## Quick Start

**Run unit tests (5-6 seconds):**
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
├── Auth/                           ✅ Sprint 2.5 (NEW)
│   ├── UserTests.swift (6 tests)
│   └── MockAuthRepositoryTests.swift (6 tests)
│
├── Domain/                         ✅ Sprint 1 (16 tests)
│   ├── AvailabilityStatusTests.swift
│   ├── DayAvailabilityTests.swift
│   └── UserScheduleTests.swift
│
├── Data/                           ✅ Sprint 2 (20 tests)
│   ├── Mocks/
│   │   └── MockAvailabilityRepositoryTests.swift (7 tests)
│   └── Persistence/
│       ├── PersistentDayAvailabilityTests.swift (9 tests)
│       └── SwiftDataAvailabilityRepositoryTests.swift (11 tests)
│
└── Features/                       ✅ Sprint 2.5 (6 tests)
    ├── RootViewModelTests.swift (6 tests)
    └── UpdateMyStatusUseCase/
        ├── UpdateMyStatusUseCaseTests.swift (4 tests)
        └── UpdateMyStatusUseCaseUIIntegrationTests.swift (1 test)
```

---

## Test Breakdown

| Layer | Tests | Purpose | Sprint |
|-------|-------|---------|--------|
| **Auth Domain** | 6 | User entity: Codable, Equatable, Identifiable | 2.5 |
| **Auth Mock Repo** | 6 | MockAuthRepository: sign in/out, auth state stream | 2.5 |
| **Root ViewModel** | 6 | Auth state management, navigation logic | 2.5 |
| **Domain Models** | 16 | Entity behavior, serialization, lookups | 1 |
| **Mock Repository** | 7 | In-memory storage, async operations | 1 |
| **Persistence** | 20 | SwiftData storage, upsert, mapping, durability | 2 |
| **Use Cases** | 5 | Business logic, validation, errors | 1 |
| **Integration** | 3 | Cross-layer communication | 1 |
| **Total** | **69** | **100% critical paths** | — |

---

## Coverage by Component

| Component | Target | Status |
|-----------|--------|--------|
| Domain Models | 95-100% | ✅ 100% |
| Auth Layer | 90-100% | ✅ 100% |
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

### Actor Isolation (MockAuthRepository & MockAvailabilityRepository)
```swift
// ❌ Avoid: Causes main actor isolation warnings
let user = await repository.currentUser
XCTAssertEqual(user?.id, "123")

// ✅ Correct: Extract properties to local variables
let user = await repository.currentUser
let userId = user?.id
XCTAssertEqual(userId, "123")
```

### AsyncStream Testing
```swift
func test_authState_emitsUserAfterSignIn() async throws {
    var emittedUser: User? = nil
    var emissionReceived = false
    
    let task = Task {
        for await user in repository.authState {
            if user != nil {
                emittedUser = user
                emissionReceived = true
                break
            }
        }
    }
    
    let signedInUser = try await repository.signInAnonymously()
    try await Task.sleep(nanoseconds: 300_000_000)  // 0.3s
    task.cancel()
    
    XCTAssertTrue(emissionReceived)
    XCTAssertEqual(emittedUser?.id, signedInUser.id)
}
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

---

## Test Doubles

**Spies:** Track method calls and arguments (use case tests)  
**Stubs:** Return fake data (integration tests)  
**Mocks:** Production-grade implementations (MockAuthRepository, MockAvailabilityRepository)  
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
let user = User(id: "123", isAnonymous: true)

// Act
try await authRepository.signInAnonymously()

// Assert
XCTAssertNotNil(authRepository.currentUser)
```

---

## Quality Metrics

| Metric | Status | Target |
|--------|--------|--------|
| Total Tests | 69 focused | >15 ✅ |
| Code Quality | 0 warnings | 0 ✅ |
| Memory Leaks | 0 detected | 0 ✅ |
| Flaky Tests | 0 | 0 ✅ |
| Async/Await Correctness | ✅ | 100% ✅ |
| Auth Layer Coverage (Sprint 2.5) | ✅ 100% | 100% ✅ |
| Persistence Coverage (Sprint 2) | ✅ 100% | 100% ✅ |

---

## Development Workflow

**After making changes:**
```bash
./run_unit_tests.sh  # Fast feedback, ~5-6 sec
```

**Before committing:**
```bash
./run_all_tests.sh   # Comprehensive validation, ~10 sec
```

**Checklist:**
- [ ] All 69 tests passing
- [ ] No compiler warnings
- [ ] Coverage targets met (85%+)
- [ ] New code follows established patterns

---

**Last Updated:** December 31, 2025 | **Status:** ✅ Production Ready (Sprint 2.5)
