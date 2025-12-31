# UFree Agent Instructions

## Build & Test Commands

**Run all unit tests (fast feedback):**
```bash
./run_unit_tests.sh          # ~4 seconds, 51 tests
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj
```

**Run single test:**
```bash
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -only-testing UFreeTests/UpdateMyStatusUseCaseTests
```

**Run UI tests (comprehensive):**
```bash
./run_all_tests.sh           # ~10 seconds
```

## Architecture & Structure

**Clean Architecture Layers:**
- **Domain:** Entities (AvailabilityStatus, DayAvailability, UserSchedule), use cases, repository protocols
- **Data:** SwiftDataAvailabilityRepository (production), MockAvailabilityRepository (testing), PersistentDayAvailability model
- **Presentation:** MyScheduleViewModel (@MainActor, @Published for state)
- **UI:** MyScheduleView (SwiftUI), driven by view model

**Key Subprojects:**
- UFree: Main app bundle
- UFreeTests: Unit tests (51 tests covering domain, data, use cases)
- UFreeUITests: UI integration tests

**Persistence:** SwiftData with in-memory containers for testing. Domain entities remain SwiftData-free.

## Code Style & Conventions

**Swift/iOS Standards:**
- SwiftUI for UI (avoid UIKit)
- Async/await for concurrency (not Combine Publishers)
- @MainActor on UI/presentation components
- Dependency injection via init parameters
- Protocol-based repositories for testability

**Naming:** CamelCase types/classes, camelCase properties/functions. Use descriptive names reflecting domain (e.g., AvailabilityStatus, DayAvailability, not Status, Day).

**Testing:** Arrange-Act-Assert pattern. Name tests as `test_[method]_[expectedBehavior]()`. Use MockAvailabilityRepository (actor for thread safety) and in-memory SwiftData containers.

**Error Handling:** Use typed errors (UpdateMyStatusUseCaseError.cannotUpdatePastDate). Propagate repository errors; catch and rollback in ViewModel.

**Imports:** Group into Foundation, SwiftUI, SwiftData, then local modules. Follow clean architecture boundaries.
