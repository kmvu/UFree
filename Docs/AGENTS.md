# UFree Agent Instructions

## Build & Test Commands

**Run all unit tests (fast feedback):**
```bash
./run_unit_tests.sh          # ~5-6 seconds, 69 tests
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj
```

**Run single test:**
```bash
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -only-testing UFreeTests/MockAuthRepositoryTests
```

**Run UI tests (comprehensive):**
```bash
./run_all_tests.sh           # ~10 seconds
```

## Architecture & Structure

**Clean Architecture Layers:**
- **Domain:** User, AvailabilityStatus, DayAvailability, UserSchedule, AuthRepository (protocol), AvailabilityRepository (protocol), UpdateMyStatusUseCase
- **Data:** FirebaseAuthRepository, MockAuthRepository, SwiftDataAvailabilityRepository, MockAvailabilityRepository, PersistentDayAvailability, FirebaseAvailabilityRepository (skeleton)
- **Presentation:** RootViewModel (auth), MyScheduleViewModel (schedule)
- **UI:** RootView (auth routing), LoginView, MyScheduleView

**Key Subprojects:**
- UFree: Main app bundle
- UFreeTests: Unit tests (83 tests covering auth, domain, data, use cases, view models)
- UFreeUITests: UI integration tests

**Persistence:** SwiftData local-only (Sprint 2.5). Firebase auth ready. Firestore integration pending (Sprint 3).

## Code Style & Conventions

**Swift/iOS Standards:**
- SwiftUI for UI (avoid UIKit)
- Async/await for concurrency (not Combine Publishers)
- @MainActor on UI/presentation components (RootViewModel, auth repositories)
- Dependency injection via init parameters
- Protocol-based repositories for testability (AuthRepository, AvailabilityRepository)
- Actor for test doubles that need concurrent access (MockAuthRepository, MockAvailabilityRepository)

**Naming:** CamelCase types/classes, camelCase properties/functions. Use descriptive names reflecting domain (e.g., AuthRepository, User, not Auth, CurrentUser).

**Testing:** Arrange-Act-Assert pattern. Name tests as `test_[method]_[expectedBehavior]()`. Use MockAuthRepository (actor for thread safety) and MockAvailabilityRepository (actor for thread safety) and in-memory SwiftData containers.

**Auth State Streaming:** Use AsyncStream for reactive UI updates instead of Combine. Example:
```swift
var authState: AsyncStream<User?> { get }

// In ViewModel:
Task {
    for await user in authRepository.authState {
        self.currentUser = user
    }
}
```

**Actor Isolation Patterns:**
1. Make initializers `nonisolated` if they don't access actor state:
```swift
nonisolated public init(user: User? = nil) {
    self.user = user
}
```

2. Make properties `nonisolated` if they don't need isolation (e.g., AsyncStream):
```swift
nonisolated public var authState: AsyncStream<User?> {
    authStateStream
}
```

3. In tests, extract properties to local variables before assertions:
```swift
// ❌ Causes warnings
let user = await repository.currentUser
XCTAssertEqual(user?.id, "123")

// ✅ Correct pattern
let user = await repository.currentUser
let userId = user?.id
XCTAssertEqual(userId, "123")
```

**Error Handling:** Use typed errors (UpdateMyStatusUseCaseError.cannotUpdatePastDate). Propagate repository errors; catch and rollback in ViewModel. Auth errors propagate to RootViewModel as `errorMessage: String?` for display.

**Imports:** Group into Foundation, SwiftUI, SwiftData, FirebaseAuth, FirebaseFirestore (when needed), then local modules. Follow clean architecture boundaries.

## Sprint 2.5 Context

**What's New:**
- User domain entity and AuthRepository protocol
- FirebaseAuthRepository wrapping Firebase Auth SDK
- RootViewModel managing auth state via AsyncStream
- RootView routing between LoginView (not authenticated) and MainAppView (authenticated)
- MockAuthRepository for testing (actor-based, concurrent access safe)

**For Next Sprint (3):**
- Implement FirebaseAvailabilityRepository methods (currently skeleton throwing "Not implemented yet")
- Build CompositeAvailabilityRepository pattern (local + remote fallback)
- Define Firestore document schema for UserSchedule
- Add network tests with Firebase emulator
