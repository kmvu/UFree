# UFree Development Plan Analysis

## 🎯 Domain Layer Design - DECIDED ✅

The domain layer has been **designed and is ready for implementation**. This is the most stable part of the architecture—independent of UI (SwiftUI/UIKit) and database (Firebase/SwiftData).

### Core Domain Models
- **`AvailabilityStatus`**: Enum with Int backing (busy=0, free=1, eveningOnly=2, unknown=3)
- **`DayAvailability`**: Entity representing one day's status with optional note
- **`UserSchedule`**: Aggregate containing user info + 7-day `weeklyStatus` array
- **`AvailabilityRepository`**: Protocol for dependency inversion (Data layer implements)

See [Domain Layer Design section](#-domain-layer-design-decided) for full details.

---

## Current Workspace Status vs. Development Plan

### ✅ What's Already Built (Foundation)

#### Architecture Infrastructure
- **Clean Architecture Structure**: Complete scaffolding with Domain/Data/Presentation/UI layers
- **Core Architecture Components**:
  - `LoadResourcePresenter` - Generic presenter for resource loading
  - `LoadResourcePresentationAdapter` - Adapter for Combine publishers
  - `AsyncLoadResourcePresentationAdapter` - Adapter for async/await
  - `WeakRefVirtualProxy` - Memory-safe view proxy
  - `ResourceView`, `ResourceLoadingView`, `ResourceErrorView` protocols
- **Networking**: `HTTPClient` protocol with Combine extension
- **Combine Extensions**: `fallback`, `dispatchOnMainThread` utilities
- **UI Foundation**: `ListViewController` (SwiftUI-backed, basic implementation)

#### Existing Feature Scaffold
- **`UpdateMyStatusUseCase`**: Template-generated feature structure
  - ⚠️ **Status**: Placeholder only - contains only `id: UUID`, no actual status/availability logic
  - **Structure**: Complete (Domain/Data/Presentation/UI layers)
  - **Tests**: Basic template tests exist
  - **Potential**: Could be repurposed for Feature 1 or Feature 2, but needs complete redesign

---

### ❌ What's Missing (Required for Plan)

## Phase 1: The "Self" Engine

### Feature 1: "My Week" Editor (Sprint 1 - CURRENT FOCUS)
**Status**: 🚧 **IN PROGRESS** - Sprint 1 Implementation

**Components**:
- ✅ **Domain Models**: **DESIGNED** - `AvailabilityStatus`, `DayAvailability`, `UserSchedule` (ready to implement)
- ✅ **Repository Protocol**: **DESIGNED** - `AvailabilityRepository` (ready to implement)
- ✅ **Use Case**: **DESIGNED** - `UpdateMyStatusUseCase` with protocol (ready to implement)
- ✅ **ViewModel**: **DESIGNED** - `MyScheduleViewModel` with status cycling (ready to implement)
- ✅ **View**: **DESIGNED** - `MyScheduleView` SwiftUI interface (ready to implement)
- [ ] **Mock Repository**: `MockAvailabilityRepository` for development (needs implementation)
- [ ] **Local Storage**: Implementation using `AvailabilityRepository` protocol (Sprint 2)
- [ ] **Remote API**: Implementation using `AvailabilityRepository` protocol (Sprint 3)

**Current Scaffold Alignment**:
- ✅ Can repurpose existing `UpdateMyStatusUseCase` scaffold structure
- ✅ Architecture patterns already established (presenters, adapters)
- ✅ `ListViewController` exists but will use new SwiftUI view instead
- ⚠️ Need to create Domain layer directory structure

### Feature 2: Live Status Toggle
**Status**: ❌ Not Started

**Missing Components**:
- [ ] **Real-time Sync**: Firestore listeners or WebSocket implementation
- [ ] **Immediate Status Update**: Use case for "right now" status changes
- [ ] **UI**: Big button component for instant status toggle
- [ ] **Backend Integration**: Real-time data sync infrastructure

**Current Scaffold Alignment**:
- Could share the same domain model as Feature 1
- Would need separate use case or extend existing one

---

## Phase 2: The "Social" Grid

### Feature 3: Weekly Dashboard (The Grid)
**Status**: ❌ Not Started

**Missing Components**:
- [ ] **Use Case**: `FetchFriendSchedulesUseCase` (uses `AvailabilityRepository.getFriendsSchedules()`)
- [ ] **Domain Model**: ✅ **DESIGNED** - `UserSchedule` (already includes friend data structure)
- [ ] **View Model**: `FriendViewModel` (presentation layer - maps `UserSchedule` to UI)
- [ ] **UI**: Horizontal scrolling grid in SwiftUI
- [ ] **Data Aggregation**: Logic to combine multiple `UserSchedule` objects

**Current Scaffold Alignment**:
- Would need new feature scaffold (could use `generate_feature.sh`)
- Architecture patterns already established

### Feature 4: "Who's Free Friday?" Filter
**Status**: ❌ Not Started

**Missing Components**:
- [ ] **Domain Logic**: Pure function to filter/sort `[UserSchedule]` by `AvailabilityStatus` for a specific `Date` (can use `UserSchedule.status(for:)` helper)
- [ ] **UI**: Date selector component
- [ ] **Integration**: Connect filter to Feature 3's grid

**Current Scaffold Alignment**:
- Pure business logic - fits well in Domain layer
- No UI dependencies needed initially

---

## Phase 3: The "Connection" Layer

### Feature 5: Contact Discovery & Invites
**Status**: ❌ Not Started

**Missing Components**:
- [ ] **Permission Handler**: Service for iOS Contacts framework access
- [ ] **Contact Sync**: Logic to match phone contacts with ufree users
- [ ] **Invite System**: Send invites to non-users
- [ ] **UI**: Contact list and invite interface

**Current Scaffold Alignment**:
- Would be a new service/use case
- Follows SRP (Single Responsibility Principle) as mentioned in plan

### Feature 6: Push Notification for "Best Friend"
**Status**: ❌ Not Started

**Missing Components**:
- [ ] **Backend**: Cloud Functions or server logic
- [ ] **Notification Service**: iOS push notification handling
- [ ] **Best Friend Logic**: Define and track "best friend" relationships
- [ ] **Trigger**: Listen for `Availability` entity changes

**Current Scaffold Alignment**:
- Requires backend infrastructure (not in current codebase)
- Would need notification service in iOS app

---

## 🎯 Domain Layer Design (DECIDED)

### ✅ Chosen Approach: Object-Oriented with Int-Backed Enum

The domain layer has been designed with Clean Architecture principles, focusing on stability and independence from UI/database concerns.

### Domain Models

#### 1. `AvailabilityStatus` Enum
```swift
enum AvailabilityStatus: Int, Codable, CaseIterable {
    case busy = 0
    case free = 1
    case eveningOnly = 2
    case unknown = 3
    
    var displayName: String {
        switch self {
        case .busy: return "Busy"
        case .free: return "Free"
        case .eveningOnly: return "Evening Only"
        case .unknown: return "No Status"
        }
    }
}
```

**Design Decisions**:
- ✅ `Int` backing for easy database storage
- ✅ `Codable` for JSON serialization
- ✅ `CaseIterable` for UI iteration
- ✅ `displayName` computed property for presentation

#### 2. `DayAvailability` Entity
```swift
struct DayAvailability: Identifiable, Codable {
    let id: UUID
    let date: Date
    var status: AvailabilityStatus
    var note: String?

    init(id: UUID = UUID(), date: Date, status: AvailabilityStatus = .unknown, note: String? = nil) {
        self.id = id
        self.date = date
        self.status = status
        self.note = note
    }
}
```

**Design Decisions**:
- ✅ `Identifiable` for SwiftUI list rendering
- ✅ `var` status and note for mutability (updates)
- ✅ Optional `note` field for social context ("free for dinner")
- ✅ Default `unknown` status for unset days

#### 3. `UserSchedule` Aggregate
```swift
struct UserSchedule: Identifiable {
    let id: String // The User's Unique ID
    let name: String
    let avatarURL: URL?
    var weeklyStatus: [DayAvailability]
    
    // Helper to find status for a specific day
    func status(for date: Date) -> DayAvailability? {
        return weeklyStatus.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
}
```

**Design Decisions**:
- ✅ Aggregate root for user's complete schedule
- ✅ Contains user metadata (name, avatar) for UI display
- ✅ `weeklyStatus` array of 7 `DayAvailability` objects
- ✅ Helper method for date-based queries (supports Feature 4)

#### 4. `AvailabilityRepository` Protocol (Dependency Inversion)
```swift
protocol AvailabilityRepository {
    func getFriendsSchedules() async throws -> [UserSchedule]
    func updateMySchedule(for day: DayAvailability) async throws
    func getMySchedule() async throws -> UserSchedule
}
```

**Design Decisions**:
- ✅ Protocol in Domain layer (Dependency Inversion Principle)
- ✅ Async/await for modern Swift concurrency
- ✅ Separate methods for different use cases
- ✅ Data layer will implement this protocol

### Architecture Benefits

✅ **Decoupling**: Changing enum cases only affects Domain layer  
✅ **Testability**: Mock repository for UI testing without backend  
✅ **Flexibility**: Can swap Firebase/SwiftData/API implementations  
✅ **Stability**: Domain layer doesn't depend on frameworks

---

## 📋 Suggested Implementation Order

### Sprint 1: "My Week" Editor Feature ✅ **CURRENT FOCUS**

**Goal**: Build a screen that displays the next 7 days and allows the user to tap a day to cycle through statuses (Free, Busy, Evening Only).

**Why This First**: 
- Establishes the "Source of Truth" for availability data
- Forces complete Clean Architecture plumbing (Domain → Use Case → Presentation → UI)
- Provides immediate UI feedback and momentum
- Validates SOLID principles (Dependency Inversion via Repository injection)

#### Phase 1.1: Domain Layer Foundation
1. **Create `AvailabilityStatus` enum** (Domain layer)
   - Int-backed, Codable, CaseIterable
   - Include `displayName` computed property
   - Cases: `.busy = 0`, `.free = 1`, `.eveningOnly = 2`, `.unknown = 3`
2. **Create `DayAvailability` struct** (Domain layer)
   - Identifiable, Codable
   - Date, status, optional note
   - Default `unknown` status
3. **Create `UserSchedule` aggregate** (Domain layer)
   - Identifiable
   - User metadata + weeklyStatus array
   - `status(for:)` helper method
4. **Create `AvailabilityRepository` protocol** (Domain layer)
   - Define interface: `getFriendsSchedules()`, `updateMySchedule(for:)`, `getMySchedule()`
   - Async/await methods

#### Phase 1.2: Use Case (Domain Layer)
5. **Create `UpdateMyStatusUseCase`** (Domain layer)
   - Protocol: `UpdateMyStatusUseCaseProtocol` with `execute(day:)` method
   - Implementation: `UpdateMyStatusUseCase` class
   - Inject `AvailabilityRepository` (dependency inversion)
   - Business logic: validation (e.g., "Cannot set status for dates in the past")
   - **Note**: Can repurpose existing `UpdateMyStatusUseCase` scaffold

#### Phase 1.3: ViewModel (Presentation Layer)
6. **Create `MyScheduleViewModel`** (Presentation layer)
   - `@MainActor` class conforming to `ObservableObject`
   - `@Published var weeklySchedule: [DayAvailability]`
   - `setupInitialWeek()`: Generate next 7 days with `unknown` status
   - `toggleStatus(for:)`: Cycle status and call use case
   - `cycleStatus(_:)`: Logic to cycle through statuses (unknown → free → busy → eveningOnly → free)
   - Inject `UpdateMyStatusUseCaseProtocol`

#### Phase 1.4: View (SwiftUI Layer)
7. **Create `MyScheduleView`** (UI layer)
   - `@StateObject` for view model
   - `List` displaying `weeklySchedule`
   - `HStack` with date formatting and status button
   - `Button` with `day.status.displayName` that calls `toggleStatus`
   - Color coding: green (free), red (busy), orange (eveningOnly), gray (unknown)
   - Navigation title: "My Week"

#### Phase 1.5: Mock Repository (Data Layer - Temporary)
8. **Create `MockAvailabilityRepository`** (Data layer - for development)
   - Implement `AvailabilityRepository` protocol
   - In-memory storage (no persistence)
   - Allows app to run without backend
   - Used for testing and initial development

#### Phase 1.6: Integration & Testing
9. **Wire up components**
   - Create dependency injection setup
   - Connect View → ViewModel → Use Case → Repository
   - Update `ContentView` or create navigation to `MyScheduleView`
10. **Write tests**
    - Domain model tests
    - Use case tests (with mock repository)
    - ViewModel tests
    - UI integration tests

**Deliverable**: Working "My Week" Editor screen with status cycling functionality

### Sprint 1 Implementation Details

#### Use Case Structure
```swift
// UpdateMyStatusUseCase.swift (Domain Layer)

protocol UpdateMyStatusUseCaseProtocol {
    func execute(day: DayAvailability) async throws
}

class UpdateMyStatusUseCase: UpdateMyStatusUseCaseProtocol {
    private let repository: AvailabilityRepository
    
    init(repository: AvailabilityRepository) {
        self.repository = repository
    }
    
    func execute(day: DayAvailability) async throws {
        // Business Logic: Validation (e.g., prevent past dates)
        try await repository.updateMySchedule(for: day)
    }
}
```

#### ViewModel Structure
```swift
// MyScheduleViewModel.swift (Presentation Layer)

@MainActor
class MyScheduleViewModel: ObservableObject {
    @Published var weeklySchedule: [DayAvailability] = []
    private let updateUseCase: UpdateMyStatusUseCaseProtocol
    
    init(updateUseCase: UpdateMyStatusUseCaseProtocol) {
        self.updateUseCase = updateUseCase
        setupInitialWeek()
    }
    
    private func setupInitialWeek() {
        // Generate next 7 days with 'unknown' status
        self.weeklySchedule = (0..<7).map { i in
            DayAvailability(date: Calendar.current.date(byAdding: .day, value: i, to: Date())!)
        }
    }
    
    func toggleStatus(for day: DayAvailability) {
        if let index = weeklySchedule.firstIndex(where: { $0.id == day.id }) {
            let nextStatus = cycleStatus(weeklySchedule[index].status)
            weeklySchedule[index].status = nextStatus
            
            Task {
                try? await updateUseCase.execute(day: weeklySchedule[index])
            }
        }
    }
    
    private func cycleStatus(_ current: AvailabilityStatus) -> AvailabilityStatus {
        switch current {
        case .unknown: return .free
        case .free: return .busy
        case .busy: return .eveningOnly
        case .eveningOnly: return .free
        }
    }
}
```

#### View Structure
```swift
// MyScheduleView.swift (UI Layer)

struct MyScheduleView: View {
    @StateObject var viewModel: MyScheduleViewModel
    
    var body: some View {
        List(viewModel.weeklySchedule) { day in
            HStack {
                Text(day.date.formatted(.dateTime.weekday().day()))
                    .font(.headline)
                
                Spacer()
                
                Button(day.status.displayName) {
                    viewModel.toggleStatus(for: day)
                }
                .buttonStyle(.borderedProminent)
                .tint(colorFor(day.status))
            }
        }
        .navigationTitle("My Week")
    }
    
    func colorFor(_ status: AvailabilityStatus) -> Color {
        switch status {
        case .free: return .green
        case .busy: return .red
        case .eveningOnly: return .orange
        default: return .gray
        }
    }
}
```

#### Key Design Decisions
- ✅ **Dependency Inversion**: Repository injected into Use Case
- ✅ **State Management**: `@Published` + `@StateObject` for reactive UI
- ✅ **Async Handling**: `Task` for async use case calls
- ✅ **Status Cycling**: Simple state machine (unknown → free → busy → eveningOnly → free)
- ✅ **Immediate Feedback**: UI updates before async call completes
- ✅ **Mock Repository Required**: Need `MockAvailabilityRepository` to run app without backend

### Sprint 2: Persistence & Real Data (Post-MVP)
**After Sprint 1 MVP is working**, add persistence:

1. **Implement local repository** (concrete `AvailabilityRepository` implementation)
   - Replace `MockAvailabilityRepository` with real storage
   - Use `UpdateMyStatusUseCaseStore` or SwiftData/CoreData
   - Implement `getMySchedule()`, `updateMySchedule(for:)`
   - Persist `DayAvailability` changes locally
2. **Load existing schedule on app launch**
   - Update `MyScheduleViewModel` to load from repository
   - Merge with generated week (fill gaps with `unknown`)
3. **Add note editing capability**
   - Extend UI to allow note input per day
   - Update `DayAvailability` with notes

### Sprint 3: Remote Sync & Fallback Pattern
1. **Implement remote repository** (concrete `AvailabilityRepository` implementation using API)
   - Implement all three repository methods
   - Map `DayAvailability`/`UserSchedule` to/from API models
   - Use `HTTPClient` protocol for network calls
2. **Create composite repository** (combines local + remote)
   - Use existing `fallback` Combine extension
   - Try local first, fallback to remote
   - Handle offline scenarios gracefully
3. **Add remote mappers** (Data layer)
   - Map API responses to `UserSchedule`
   - Map `DayAvailability` to API requests
   - Complete `UpdateMyStatusUseCaseMapper` implementation
4. **Integration tests** (test repository implementations)

### Sprint 4: Feature 2 - Live Status Toggle
1. **Extend domain model** for "current" status
2. **Real-time sync implementation** (Firestore/WebSocket)
3. **Big button UI component**
4. **Integration with Feature 1**

---

## 🔗 Architecture Alignment Notes

### What Works Well
- ✅ Clean Architecture structure is ready
- ✅ Generic presenters/adapters can be reused
- ✅ Combine infrastructure supports async operations
- ✅ Test structure is established

### What Needs Attention
- ⚠️ `UpdateMyStatusUseCase` naming might be confusing - consider renaming to `UpdateWeeklyStatusUseCase` or `UpdateAvailabilityUseCase`
- ⚠️ Current model is too simple - needs complete redesign
- ⚠️ No concrete implementations of Store/API protocols yet
- ⚠️ `ListViewController` is basic - will need enhancement for grid view

### Naming Convention Suggestion
Consider renaming:
- `UpdateMyStatusUseCase` → `UpdateWeeklyStatusUseCase` (for Feature 1)
- Create new `UpdateLiveStatusUseCase` (for Feature 2)
- Or use more generic: `UpdateAvailabilityUseCase` that handles both

---

## 📊 Progress Tracking

### Phase 1: The "Self" Engine
- [ ] Feature 1: Weekly Status Editor
- [ ] Feature 2: Live Status Toggle

### Phase 2: The "Social" Grid
- [ ] Feature 3: Weekly Dashboard
- [ ] Feature 4: "Who's Free Friday?" Filter

### Phase 3: The "Connection" Layer
- [ ] Feature 5: Contact Discovery
- [ ] Feature 6: Push Notifications

---

## 🚀 Next Immediate Steps - Sprint 1: "My Week" Editor

### ✅ **CURRENT SPRINT** - Build Complete Feature End-to-End

#### Step 1: Domain Layer Foundation
1. **Create Domain layer directory structure**
   - `UFree/Core/Domain/Entities/` (or `UFree/Core/Domain/Models/`)
2. **Implement `AvailabilityStatus` enum**
   - File: `AvailabilityStatus.swift`
   - Cases: `.busy = 0`, `.free = 1`, `.eveningOnly = 2`, `.unknown = 3`
   - `displayName` computed property
3. **Implement `DayAvailability` struct**
   - File: `DayAvailability.swift`
   - Properties: `id`, `date`, `status`, `note?`
   - Default initializer with `unknown` status
4. **Implement `UserSchedule` aggregate**
   - File: `UserSchedule.swift`
   - Properties: `id`, `name`, `avatarURL?`, `weeklyStatus`
   - `status(for:)` helper method
5. **Create `AvailabilityRepository` protocol**
   - File: `AvailabilityRepository.swift`
   - Methods: `getFriendsSchedules()`, `updateMySchedule(for:)`, `getMySchedule()`
   - All async/await

#### Step 2: Use Case (Domain Layer)
6. **Create/Update `UpdateMyStatusUseCase`**
   - File: `UpdateMyStatusUseCase.swift` (can repurpose existing scaffold)
   - Protocol: `UpdateMyStatusUseCaseProtocol` with `execute(day:) async throws`
   - Implementation: `UpdateMyStatusUseCase` class
   - Inject `AvailabilityRepository` in initializer
   - Add validation logic (e.g., prevent past date updates)

#### Step 3: ViewModel (Presentation Layer)
7. **Create `MyScheduleViewModel`**
   - File: `MyScheduleViewModel.swift` (in Presentation layer)
   - `@MainActor class MyScheduleViewModel: ObservableObject`
   - `@Published var weeklySchedule: [DayAvailability]`
   - `setupInitialWeek()`: Generate next 7 days starting from today
   - `toggleStatus(for:)`: Find day, cycle status, call use case
   - `cycleStatus(_:)`: unknown → free → busy → eveningOnly → free
   - Inject `UpdateMyStatusUseCaseProtocol`

#### Step 4: View (SwiftUI Layer)
8. **Create `MyScheduleView`**
   - File: `MyScheduleView.swift` (in UI layer)
   - `@StateObject var viewModel: MyScheduleViewModel`
   - `List(viewModel.weeklySchedule)` with `HStack` rows
   - Date formatting: `day.date.formatted(.dateTime.weekday().day())`
   - Button with `day.status.displayName` and color coding
   - Navigation title: "My Week"

#### Step 5: Mock Repository (Data Layer - Temporary)
9. **Create `MockAvailabilityRepository`**
   - File: `MockAvailabilityRepository.swift` (in Data layer)
   - Implement `AvailabilityRepository` protocol
   - In-memory storage (Dictionary or Array)
   - `updateMySchedule(for:)` stores in memory
   - `getMySchedule()` returns stored schedule or empty
   - `getFriendsSchedules()` returns empty array for now

#### Step 6: Dependency Injection & Integration
10. **Create dependency setup**
    - In `ContentView` or app entry point
    - Create `MockAvailabilityRepository` instance
    - Create `UpdateMyStatusUseCase` with repository
    - Create `MyScheduleViewModel` with use case
    - Present `MyScheduleView` with view model
11. **Write initial tests**
    - Domain model tests (enum, structs)
    - Use case tests with mock repository
    - ViewModel tests (status cycling logic)

### Integration with Existing Code
- ✅ Repurpose existing `UpdateMyStatusUseCase` scaffold (update model, add use case logic)
- ✅ Use existing `ListViewController` or create new SwiftUI view
- ✅ Follow existing Clean Architecture patterns (presenters, adapters)
- ✅ Mock repository allows development without backend

### Success Criteria
- [ ] App runs without crashing
- [ ] Screen displays next 7 days
- [ ] Tapping a day cycles through statuses
- [ ] Status colors display correctly
- [ ] Use case is called when status changes
- [ ] Mock repository stores changes in memory

