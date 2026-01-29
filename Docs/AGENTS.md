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

## Deep Linking & Navigation

### Universal Links (App Site Association)

**Pattern:** iOS-native deep linking via URLs (no web fallback required)

```swift
// RootView.swift - Listen for incoming Universal Links
.onOpenURL { url in
    let deepLink = DeepLink.parse(url)
    handleNavigation(deepLink)
}

// DeepLink enum - Parse URLs into actions
enum DeepLink {
    case notification(senderId: String)
    case profile(userId: String)
    case unknown
    
    static func parse(_ url: URL) -> DeepLink { /* ... */ }
}

// URL format: https://ufree.app/notification/{userId}
```

**Setup:**
1. Create `.well-known/apple-app-site-association` on server
2. Add `applinks:ufree.app` to Info.plist Associated Domains
3. See **UNIVERSAL_LINKS_SETUP.md** for full guide

**Benefits:**
- ✅ Works from notifications, emails, web pages
- ✅ No SMS codes or web detour
- ✅ Seamless UX (app opens directly to content)

---

## Testing Patterns

### Debug Auth Strategy (Development Only)

For testing multi-user flows without SMS verification:

```swift
// AuthRepository protocol includes debug method:
#if DEBUG
func signInAsTestUser(phoneNumber: String) async throws -> User
#endif

// LoginView has developer overlay (DEBUG only):
#if DEBUG
VStack {
    Button("User 1") { await viewModel.loginAsTestUser(index: 0) }
    Button("User 2") { await viewModel.loginAsTestUser(index: 1) }
    Button("User 3") { await viewModel.loginAsTestUser(index: 2) }
}
#endif

// Firebase setup: Add test phone numbers in Console > Authentication
// +1 555-000-0001 (code: 123456)
// +1 555-000-0002 (code: 123456)
// +1 555-000-0003 (code: 123456)
```

### Tappable Component Pattern

**All interactive UI components follow:**

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

## Sprint 6+ Production Stack

### Distribution Automation ✅
- **Fastlane Three-Tier Pipeline:** `fastlane tests` → `fastlane alpha` → `fastlane beta`
- **Certificate Management:** match (encrypted certificates, auto-synced)
- **CI/CD Detection:** Handles local + GitHub Actions environments seamlessly
- **Build Management:** Auto-increment build numbers, artifact cleanup

### Firebase Integration ✅
- **Crashlytics:** Automatic crash capture with readable stack traces
- **Analytics:** Type-safe event tracking (AnalyticsManager enum)
- **Metrics:** nudgeSent, batchNudge, phoneSearch, availabilityUpdated, handshakeCompleted, appLaunched

### Continuous Delivery ✅
- **GitHub Actions:** Push to main → auto-deploy to TestFlight
- **Security:** Secrets in GitHub encrypted, no local .env in repo
- **Monitoring:** Real-time dashboards in Firebase Console

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

## Setup Instructions

### New Machine Setup (15 minutes)

**1. Ruby & OpenSSL**
```bash
rvm install 3.2 --with-openssl-dir=$(brew --prefix openssl@3)
rvm use 3.2 && rvm default 3.2
ruby -ropenssl -e 'puts OpenSSL::OPENSSL_VERSION'  # Verify
```

**2. Gems**
```bash
bundle install
```

**3. Certificates (match)**
```bash
export MATCH_PASSWORD="your-password-from-vault"
bundle exec fastlane match appstore
```

### Matchfile Configuration
- **Location:** `fastlane/Matchfile`
- **git_url:** `git@github.com:kmvu/ufree-certificates.git`
- **app_identifier:** `com.khangvu.UFree`
- **username:** `khang.vu.studio91@gmail.com`
- **Read-only in CI/CD:** Uses `readonly(is_ci)` variable

---

## File Organization

**Key locations:**

| Type | Location |
|------|----------|
| Documentation | `Docs/` (README.md, AGENTS.md, SPRINT_HISTORY.md, SMOKE_TEST_CHECKLIST.md, UNIVERSAL_LINKS_SETUP.md) |
| Fastlane Config | `fastlane/Matchfile`, `fastlane/Appfile`, `fastlane/Fastfile` |
| Build Setup | `fastlane/Docs/FASTLANE_SETUP.md`, `fastlane/Docs/MATCH_GUIDE.md` |
| Domain Models | `UFree/Core/Domain/` |
| Data Layer | `UFree/Core/Data/` |
| ViewModels | `UFree/Features/*/` |
| UI Components | `UFree/Features/*/` |
| Deep Linking | `UFree/Features/Root/RootView.swift` (DeepLink enum) |
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

**Before every push to Git:**
- ✅ `.env` is NOT tracked (`git status`)
- ✅ No `.p8` files tracked (`git status | grep p8`)
- ✅ No passwords in staged files (`git diff --cached fastlane/`)
- ✅ `.gitignore` protects: `.env`, `*.p8`, match credentials
- ✅ `Appfile` contains app config only (no secrets)
- ✅ Only committed from `fastlane/`: `Matchfile`, `Appfile`, `Fastfile`, `.gitignore`

**Verify nothing secret is staged:**
```bash
git status
git diff --cached fastlane/  # Should show only Appfile, Fastfile, Matchfile
```

**If you accidentally staged secrets:**
```bash
git reset HEAD fastlane/.env  # Unstage
git checkout fastlane/.env     # Discard
```

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

**Last Updated:** January 29, 2026 | **Status:** Production Ready ✅

**Quick Reference:**
- `README.md` - Architecture overview
- `TESTING_GUIDE.md` - Test organization (206+)
- `SMOKE_TEST_CHECKLIST.md` - Manual validation
- `SPRINT_HISTORY.md` - Development history
- `fastlane/Docs/FASTLANE_SETUP.md` - Build automation
- `fastlane/Docs/FIREBASE_SETUP.md` - Crashlytics + Analytics
- `fastlane/Docs/MATCH_GUIDE.md` - Certificates
- `Docs/GITHUB_ACTIONS_SETUP.md` - CI/CD
