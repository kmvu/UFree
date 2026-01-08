# UFree Agent Instructions

## CRITICAL: Path Format

**ALWAYS USE UNDERSCORES (NO SPACES) - OR USE SPACES WITH QUOTES**

✅ CORRECT:
```
/Users/KhangVu/Documents/Development/git_project/Khang Business Projects/UFree
```

Use spaces naturally in this directory. All file operations will work with the space-based path.

---

## Project Structure

- **UFree/**: Main app source
- **UFreeTests/**: Unit tests
- **UFreeUITests/**: UI tests
- **Docs/**: Documentation
- **fastlane/**: Distribution automation

---

## Testing Protocol

**Skip tests for docs/comments changes. Run tests ONLY if code logic changes.**
- Docs/README/comments updates: No tests needed
- Code/logic changes: Ask user first: "Should I run tests to validate?"

**Test-Driven Development (TDD):** Write tests FIRST, then implement code.

## Test Commands

```bash
# Quick validation (recommended)
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | \
  grep -E '(PASS|FAIL|passed|failed|warning)'

# Full output
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Single suite
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing UFreeTests/MockAuthRepositoryTests
```

## Build Troubleshooting

| Issue | Solution |
|-------|----------|
| Provisioning profile error | Use `-scheme UFreeUnitTests`, not `-scheme UFree` |
| No simulator specified error | Always include `-destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |
| Device selection fails | Use `-destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |
| Certificate expired | Run `fastlane match appstore` to renew |
| match authentication fails | Check MATCH_PASSWORD in .env |

**Validation workflow:** 1) Make changes → 2) Run tests with grep → 3) Look for "passed" → 4) Done

---

## Architecture & Layers

| Layer | Key Components |
|-------|---|
| **Domain** | User, AvailabilityStatus, DayAvailability, UserSchedule, UserProfile, Protocols (AuthRepository, AvailabilityRepository, FriendRepositoryProtocol), UpdateMyStatusUseCase |
| **Data** | FirebaseAuthRepository, MockAuthRepository, SwiftDataAvailabilityRepository, FirebaseAvailabilityRepository, CompositeAvailabilityRepository, FirebaseFriendRepository, AppleContactsRepository, CryptoUtils, AnalyticsManager |
| **Presentation** | RootViewModel (auth), MyScheduleViewModel, FriendsScheduleViewModel, FriendsViewModel, StatusBannerViewModel, DayFilterViewModel, NotificationViewModel |
| **UI** | RootView (auth + tabs), LoginView, MyScheduleView, FriendsView, FriendsScheduleView, NotificationCenterView, Components |

**Projects:** UFree (app), UFreeTests (206+ unit tests), UFreeUITests (integration tests)

---

## Code Style & Conventions

**Swift Standards:**
- SwiftUI only (no UIKit)
- `@Published` for ViewModel state (required for `@StateObject`)
- Async/await for concurrency (not Combine Publishers)
- `@MainActor` on UI/Presentation components and auth repos
- Dependency injection via init parameters
- Protocol-based repos for testability
- Actor for mocks requiring concurrent access (MockAuthRepository, MockAvailabilityRepository)

**Naming:** CamelCase types, camelCase properties/functions. Descriptive names (e.g., `AuthRepository`, not `Auth`)

**Architecture Principles:**
- **Abstractions**: Protocol-based repos + Factory patterns (TestNotificationBuilder) reduce coupling
- **Maintainability**: Single Responsibility - each class/struct does one thing well
- **Reusability**: Shared utilities (HapticManager, AvailabilityStatus+Colors) avoid duplication
- **Extensibility**: Enum-based types (NotificationType) allow easy additions without breaking changes

**Testing:** Arrange-Act-Assert pattern. Test names: `test_[method]_[expectedBehavior]()`. Include rapid-tap protection tests (single tap, rapid taps, sequential taps).

**AsyncStream Pattern (Auth State):**
```swift
var authState: AsyncStream<User?> { get }

// In ViewModel:
Task {
    for await user in authRepository.authState {
        self.currentUser = user
    }
}
```

**Actor Isolation:**
1. `nonisolated` initializers if they don't access actor state
2. `nonisolated` properties if they don't need isolation (e.g., AsyncStream)
3. Extract properties to local variables before assertions in tests

**Error Handling:** Typed errors (e.g., `UpdateMyStatusUseCaseError.cannotUpdatePastDate`). Propagate repo errors; catch and rollback in ViewModel.

**Imports:** Foundation, SwiftUI, SwiftData, FirebaseAuth, FirebaseFirestore (if needed), then local modules.

---

## Tappable Component Pattern

**All interactive UI components follow this pattern:**

1. **ViewModel** (@MainActor, @Published state, rapid-tap protection via `guard !isProcessing`)
2. **View** (separate file with @StateObject for ViewModel)
3. **Tests** (single tap, rapid taps, sequential taps)

**Example:** `StatusBannerView` + `StatusBannerViewModel` (status cycling, 0.3s processing, rapid-tap protection)

**Files to create:**
- `{Component}ViewModel.swift` - State management (@MainActor, @Published)
- `{Component}View.swift` - UI with @StateObject or stateless
- `{Component}ViewModelTests.swift` - Rapid-tap scenarios (if stateful)
- Parent view - Layout orchestration only

**Shared Utilities:**
- `AvailabilityStatus+Colors.swift` - Domain-level color extension (`.displayColor`)
- `ButtonStyles.swift` - NoInteractionButtonStyle (removes default highlight)
- `HapticManager.swift` - Unified feedback API
- `AnalyticsManager.swift` - Type-safe event tracking

---

## Navigation & UI

**Apple-Compliant:**
- Use `.navigationTitle()`, `.navigationSubtitle()`, `.navigationBarTitleDisplayMode()`
- Add buttons via `.toolbar(placement: .navigationBarTrailing)`
- Do NOT use custom header sections or `.principal` placement for titles
- Single NavigationStack at MainAppView level (no nesting)

**Example:**
```swift
NavigationStack {
    VStack { /* content */ }
        .navigationTitle("UFree")
        .navigationSubtitle("See when friends are available")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Sign Out") { /* action */ }
            }
        }
}
```

---

## Recent Sprint (Sprint 6.1+) Summary

### Sprint 6.1: Distribution Automation ✅

**Theme:** Fastlane Automation - Every build validated before reaching testers

**Three-Tier Pipeline:**
- **tests lane** - Pre-flight validation: runs all 206+ unit tests, fails build if any test fails
- **alpha lane** - Internal Firebase distribution: tests → build → Firebase App Distribution (no Apple review, instant)
- **beta lane** - External TestFlight: tests → build → auto-increment build number → TestFlight (Apple review required, 1-2 days)

**Enhanced with match Certificate Management:**
- **match integration** - Stores certificates in private GitHub repo (encrypted with MATCH_PASSWORD)
- **Appfile** - Centralized app ID, team ID, Apple ID configuration
- **Hands-off signing** - beta lane automatically syncs and uses certificates from match
- **CI/CD ready** - New machines only need MATCH_PASSWORD to build and distribute

**Command Reference:**
```bash
fastlane tests          # Pre-flight validation (206+ tests)
fastlane alpha          # Build → Firebase (internal testers, instant)
fastlane beta           # Build → TestFlight (external testers, 1-2 days)
fastlane sync_certs     # Manual certificate sync (usually not needed)
fastlane test_report    # Generate detailed test report
```

**Files Created:**
- `fastlane/Fastfile` - Five lanes with match integration
- `fastlane/Appfile` - Centralized app configuration
- `fastlane/.env.default` - Template for credentials (Firebase, Apple ID, MATCH_PASSWORD)
- `fastlane/.gitignore` - Enhanced secrets protection
- `FASTLANE_SETUP.md` - Setup guide with match initialization (20 minutes one-time)
- `MATCH_GUIDE.md` - Deep dive on match certificate management

### Sprint 6.1+ Additions: Testing & Analytics Phase ✅

**Theme:** Stability & Insights - Crashlytics for crash reporting, Analytics for usage tracking

**Firebase Crashlytics Integration ✅**
- **UFreeApp.swift**: Added `import FirebaseCrashlytics`, enabled in Release builds, disabled in Debug
- **Fastfile (beta lane)**: Added `include_symbols: true` + `upload_symbols_to_crashlytics` for dSYM uploads
- **Build Phase Script**: Manual Xcode setup required - Run Script phase with Firebase SDK path
- **Captures**: Stack traces with line numbers, device model, iOS version, app version, network status
- **Result**: Readable crash reports in Firebase Console with device/version filtering

**Firebase Analytics Integration ✅**
- **AnalyticsManager.swift**: Type-safe event tracking (AnalyticsEvent enum + log methods)
- **UFreeApp.swift**: Added `import FirebaseAnalytics`, auto-enabled for Release, auto-disabled for Debug
- **Key Metrics**: nudgeSent, batchNudge, phoneSearch, availabilityUpdated, handshakeCompleted, appLaunched
- **Auto-logging**: All events timestamped, parameters typed (string, int, double, long)
- **Result**: Real-time user behavior in Firebase Console with Realtime dashboard

**Documentation Created:**
- `fastlane/Docs/FIREBASE_SETUP.md` - Combined Crashlytics + Analytics guide (Part 1 & Part 2)
- `MATCH_GUIDE.md` - Deep dive on certificate management (separate, detailed)
- Updated `FASTLANE_SETUP.md` (v1.4) - Added build phase instructions + AnalyticsManager wiring guide

**Testing Phase Complete:**
- ✅ **Automation**: Fastlane (tests → alpha → beta pipeline)
- ✅ **Security**: match (encrypted certificates, MATCH_PASSWORD sharing)
- ✅ **Stability**: Crashlytics (readable crash reports with context)
- ✅ **Insights**: Analytics (real-time usage metrics)

**Manual Steps Required (One-Time):**
1. Add Crashlytics build phase script to Xcode (5 minutes)
2. Wire AnalyticsManager.log() calls into ViewModels (10 minutes)

**Files Created/Modified:**
- `UFree/Core/Utilities/AnalyticsManager.swift` - Event tracking wrapper
- `UFree/UFreeApp.swift` - Updated with Crashlytics + Analytics imports
- `fastlane/Fastfile` - Updated beta lane with dSYM upload
- `fastlane/Docs/FIREBASE_SETUP.md` - Merged Crashlytics + Analytics guide
- `Scripts/upload_dsyms.sh` - Build phase script template

---

## Build Automation Commands

```bash
# Validate all tests (pre-flight)
fastlane tests

# Build and distribute internally (Firebase)
fastlane alpha

# Build and submit to TestFlight
fastlane beta

# Generate detailed test report
fastlane test_report

# Manually sync certificates
fastlane sync_certs
```

---

## File Organization

**Always know where to find things:**

| Type | Location |
|------|----------|
| Documentation | `Docs/` (README.md, AGENTS.md, SPRINT_HISTORY.md) |
| Firebase Setup | `Docs/FIREBASE_SETUP.md` |
| Fastlane Setup | `fastlane/Docs/FASTLANE_SETUP.md` |
| Match Guide | `fastlane/Docs/MATCH_GUIDE.md` |
| Domain Models | `UFree/Core/Domain/` |
| Data Layer | `UFree/Core/Data/` |
| ViewModels | `UFree/Features/*/` |
| UI Components | `UFree/Features/*/` |
| Tests | `UFreeTests/` |

---

## Common Tasks

### Add a New Feature

1. **Create domain model** in `UFree/Core/Domain/`
2. **Create repository protocol** if needed
3. **Implement repository** in `UFree/Core/Data/`
4. **Create ViewModel** in `UFree/Features/{Feature}/`
5. **Create View** in `UFree/Features/{Feature}/`
6. **Write tests first** (TDD)
7. **Wire dependency injection** in parent View
8. **Add analytics tracking** via AnalyticsManager

### Add a New ViewModel

```swift
@MainActor
final class MyViewModel: ObservableObject {
    @Published var state: MyState = .initial
    
    private let repository: MyRepository
    
    init(repository: MyRepository = .shared) {
        self.repository = repository
    }
    
    func doSomething() async {
        do {
            state = .loading
            // ... async work ...
            state = .success(result)
            AnalyticsManager.log(.featureUsed)
        } catch {
            state = .error(error)
        }
    }
}
```

### Add a New Test

```swift
final class MyViewModelTests: XCTestCase {
    var sut: MyViewModel!
    var mockRepository: MockMyRepository!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockMyRepository()
        sut = MyViewModel(repository: mockRepository)
    }
    
    func test_doSomething_succeeds() async {
        // Arrange
        mockRepository.stubbedResult = .success(42)
        
        // Act
        await sut.doSomething()
        
        // Assert
        XCTAssertEqual(sut.state, .success(42))
    }
}
```

---

## Pair Testing Strategy ("The Trusted Circle")

Before distribution, validate core features:

1. **Phone Search** - User A finds User B (blind index)
2. **Handshake** - A sends request, B accepts
3. **Heatmap** - Both see "Who's free on..." with counts
4. **Nudge** - A nudges B → B gets real-time notification
5. **Validation** - Check haptics, sync timing, rapid-tap protection

See `README.md` for more details.

---

## Security & Secrets

### Local Machine (.env Strategy)

Your `.env` file contains:
```
FASTLANE_USER, FASTLANE_PASSWORD, MATCH_PASSWORD, FIREBASE_TOKEN, FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD
```

**Protection:**
- `fastlane/.gitignore` prevents it from ever being committed
- Keep `.env` in password manager as backup
- Never share in Slack, email, or chat
- Only share MATCH_PASSWORD securely (1Password, Vault, verbal)

### Private match Repository

- **GitHub (private):** Encrypted certificates + provisioning profiles
- **Encryption:** AES-256-CBC (industry standard)
- **Access:** Only with MATCH_PASSWORD
- **Never commit** encrypted certs to main UFree repo (separate private repo only)

### Security Checklist

Before every push to Git:
- ✅ `.env` is NOT tracked (`git status`)
- ✅ No passwords in staged files (`git diff --cached fastlane/`)
- ✅ `.gitignore` has `.env` listed
- ✅ `Appfile` contains app config only (no secrets)
- ✅ Only `Fastfile` and `Appfile` are committed from `fastlane/`

---

## Performance Targets

| Operation | Expected |
|-----------|----------|
| Tests | ~90 sec |
| Alpha build | ~3 min |
| Beta build | ~8 min |
| match sync | ~30 sec |
| Real-time sync | < 3 sec |
| Phone search | < 2 sec |
| Nudge delivery | < 2 sec |

---

## Debugging Tips

**Network issues?**
- Check CompositeAvailabilityRepository logic (should use local first)
- Verify Firestore rules allow read/write for current user
- Check Firebase Console for write errors

**UI flickering?**
- Verify single NavigationStack at MainAppView (no nesting)
- Check ViewModel subscription cleanup in deinit
- Ensure AsyncStream listeners are cancelled properly

**Test failures?**
- Run with full output: `xcodebuild test ... (without grep)`
- Check mock setup in setUp() method
- Verify @MainActor isolation is correct

**Analytics not appearing?**
- Wait 5-10 minutes (Firebase batches events)
- Check Release build (Debug has analytics disabled)
- Verify `AnalyticsManager.log()` is called after action succeeds
- Check Firebase Console → Analytics → Realtime tab

---

## Continuous Delivery (CI/CD) via GitHub Actions ✅

**Workflow:** Push to main → GitHub Actions runs tests → Uploads to TestFlight automatically

**Setup File:** `.github/workflows/testflight.yml` (already in repo)

**One-Time Setup (15 minutes):**
1. Create App Store Connect API Key (see GITHUB_ACTIONS_SETUP.md)
2. Add 6 GitHub Secrets (FASTLANE_USER, MATCH_PASSWORD, ASC_KEY_ID, etc.)
3. Push to main
4. Watch GitHub Actions tab (build takes ~10-12 minutes)

**Benefits:**
- ✅ No manual `fastlane beta` needed
- ✅ Tests run automatically (fail fast)
- ✅ TestFlight uploads automated
- ✅ Testers notified automatically
- ✅ Free tier: 3,000 minutes/month on macOS (15+ builds)

**Common Customizations:**
- Deploy only on tags (not every push)
- Run tests on every PR
- Slack notifications on build completion

See `Docs/GITHUB_ACTIONS_SETUP.md` for complete setup guide and troubleshooting.

---

**Last Updated:** January 8, 2026 | **Status:** Production Ready ✅

**References:**
- `SPRINT_HISTORY.md` - Complete development record (Sprint 1-5.1)
- `README.md` - Architecture overview & quick reference
- `fastlane/Docs/FASTLANE_SETUP.md` - Build automation guide
- `fastlane/Docs/FIREBASE_SETUP.md` - Crashlytics + Analytics integration
- `fastlane/Docs/MATCH_GUIDE.md` - Certificate management deep dive
- `Docs/GITHUB_ACTIONS_SETUP.md` - Continuous delivery setup guide
