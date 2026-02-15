# UFree Coding Standards & Setup

**Code style, testing, setup, and project protocols**

---

## Path Format

Always use spaces naturally in paths (they work fine):
```
/Users/KhangVu/Documents/Development/git_project/Khang_business_projects/UFree
```

---

## Testing Protocol

**Skip tests for docs/comments. Run tests ONLY if code logic changes.**

```bash
# Quick validation (recommended)
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | \
  grep -E '(PASS|FAIL|passed|failed|warning)'

# Single test suite
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing UFreeTests/MockAuthRepositoryTests
```

---

## Architecture & Layers

| Layer | Key Components |
|-------|---|
| **Domain** | User, AvailabilityStatus, DayAvailability, Protocols |
| **Data** | Firebase/SwiftData repos, CompositeRepository, Crypto |
| **Presentation** | ViewModels (all @MainActor with @Published) |
| **UI** | SwiftUI views only (no UIKit) |

**Data Flow:** UI → ViewModel → CompositeRepository → SwiftData (instant) + Firestore (background)

---

## Code Style

**Swift Standards:**
- SwiftUI only (no UIKit)
- `@Published` for ViewModel state
- Async/await (no Combine)
- `@MainActor` on UI components
- Protocol-based repos for testability
- Dependency injection via init

**Naming:** CamelCase types, camelCase properties/functions

**Testing:** Arrange-Act-Assert pattern. Test names: `test_[method]_[expectedBehavior]()`

---

## Environment Setup

### Apple Silicon (M3) Ruby (15 min)

```bash
# 1. Clean up
rvm uninstall 3.3.0 && rvm cleanup all

# 2. Install to correct path
brew install openssl@3 libyaml

# 3. M3 Magic Install (compile from source with explicit paths)
rvm install 3.3.0 \
  --disable-binary \
  --with-openssl-dir=$(brew --prefix openssl@3) \
  --with-libyaml-dir=$(brew --prefix libyaml)

# 4. Verify
ruby -ropenssl -e 'puts OpenSSL::OPENSSL_VERSION'
```

### New Machine Setup (20 min total)

```bash
# 1. Ruby (use above if M3)
# 2. Gems
bundle install

# 3. Certificates
export MATCH_PASSWORD="your-password"
bundle exec fastlane match appstore
```

### Fastlane Golden Configuration

**Key Settings:**
```ruby
build_app(
  export_method: "app-store",        # NOT "app-store-connect"
  export_options: {
    signingStyle: "manual",           # Forces Xcode to use our profiles
    provisioningProfiles: profile_mapping
  }
)
```

### Bitbucket User Limits

**Problem:** Fastlane match fails (read-only access)

**Fix:** Bitbucket Free = 5 users max. Revoke pending invites, remove inactive users.

---

## Testing Patterns

### Debug Auth Strategy (Development Only)

Add Firebase test phone numbers (Console > Authentication):
- +1 555-000-0001 (code: 123456)
- +1 555-000-0002 (code: 123456)

LoginView shows developer overlay in DEBUG to quick-login.

### Rapid-Tap Protection

All interactive ViewModels use:
```swift
func doSomething() {
    guard !isProcessing else { return }
    isProcessing = true
    Task {
        defer { isProcessing = false }
        // ... async work
    }
}
```

Test: single tap → rapid taps → sequential taps

### Testing Organization

```
UFreeTests/
├── Auth/                (17 tests)
├── Domain/              (18 tests)
├── Data/                (60+ tests)
├── Core/Extensions/     (7 tests)
└── Features/            (77+ tests)
```

See TESTING_GUIDE.md for full details.

---

## Deep Linking & Navigation

### Universal Links Setup

**In Xcode:**
1. Add "Associated Domains" capability
2. Add: `applinks:ufree.app`
3. Add to Info.plist: `com.apple.developer.associated-domains`

**Server (.well-known/apple-app-site-association):**
```json
{
  "applinks": {
    "apps": [],
    "details": [{
      "appID": "TEAM_ID.com.khangvu.UFree",
      "paths": ["/notification/*"]
    }]
  }
}
```

**In Code:**
```swift
.onOpenURL { url in
    let deepLink = DeepLink.parse(url)
    handleNavigation(deepLink)
}
```

---

## Security & Secrets

**Never Commit:**
- `.env` (credentials)
- `fastlane/Keys/*.p8` (API key)
- Passwords in code

**Protect Locally:**
```bash
git status | grep -i ".env"           # Should be empty
git diff --cached fastlane/           # Should show no secrets
```

**Local Environment Variables:**
```
FASTLANE_USER
FASTLANE_PASSWORD
MATCH_PASSWORD
ASC_KEY_ID
ASC_ISSUER_ID
ASC_KEY_PATH (absolute path)
```

### GitHub Secrets Setup

Think of it as two doors: **SSH_PRIVATE_KEY** unlocks the house (Bitbucket repo), **MATCH_PASSWORD** unlocks the safe inside (decrypts certificates).

**Generate SSH Key for GitHub Actions:**

```bash
# Create new deploy key (leave password blank)
ssh-keygen -t ed25519 -C "github_actions_deploy" -f ./github_actions_deploy

# You now have:
# - github_actions_deploy (private key → GitHub)
# - github_actions_deploy.pub (public key → Bitbucket)
```

**Add Public Key to Bitbucket:**
1. Go: Bitbucket > ufree-certificates repo > Settings > Access Keys > Add Key
2. Label: `GitHub Actions CI`
3. Key: Paste entire contents of `github_actions_deploy.pub`
4. Permission: Read
5. Save

**Add Private Key to GitHub Secrets:**
1. Go: GitHub > UFree > Settings > Secrets and variables > Actions > New repository secret
2. Name: `SSH_PRIVATE_KEY`
3. Value: Paste entire block from `github_actions_deploy` (includes BEGIN/END lines)
4. Save

**Cleanup:**
```bash
rm github_actions_deploy github_actions_deploy.pub
```

**GitHub Secrets Checklist:**

| Secret | Source | Purpose |
|--------|--------|---------|
| `SSH_PRIVATE_KEY` | Generated key | Clone Bitbucket certs repo |
| `MATCH_PASSWORD` | Your `.env` file | Decrypt certificates |
| `ASC_KEY_CONTENT` | `base64 fastlane/AuthKey_*.p8` | Apple API authentication |
| `ASC_KEY_ID` | Your `.env` file | Identify API key |
| `ASC_ISSUER_ID` | Your `.env` file | Identify team |
| `FASTLANE_USER` | Your `.env` file | Apple ID (fallback) |
| `GOOGLE_SERVICE_INFO_PLIST` | `base64 GoogleService-Info.plist` | Firebase configuration (decoded in CI) |

**Generate `GOOGLE_SERVICE_INFO_PLIST`:**
```bash
# Locally, encode the Firebase config file to base64
base64 GoogleService-Info.plist | pbcopy

# Then paste into GitHub Secrets as GOOGLE_SERVICE_INFO_PLIST
```

In the workflow, it's decoded before the build runs with:
```bash
echo "${{ secrets.GOOGLE_SERVICE_INFO_PLIST }}" | base64 --decode > ./GoogleService-Info.plist
```

**Environment Variables (Workflow):**
These are set in testflight.yml (not secrets, just env config):
```yaml
FASTLANE_XCODEBUILD_SETTINGS_TIMEOUT: 120    # Package resolution timeout
FASTLANE_XCODEBUILD_SETTINGS_RETRIES: 3      # Retry attempts
```

These prevent timeout warnings and reduce build time by ~45 seconds.

---

## File Organization

| Type | Location |
|------|----------|
| Domain Models | `UFree/Core/Domain/` |
| Repos | `UFree/Core/Data/` |
| ViewModels | `UFree/Features/*/` |
| Views | `UFree/Features/*/` |
| Tests | `UFreeTests/` |

---

## Common Patterns

### Add a New ViewModel

```swift
@MainActor
final class MyViewModel: ObservableObject {
    @Published var state: State = .initial
    private let repo: MyRepository
    
    init(repo: MyRepository = .shared) {
        self.repo = repo
    }
    
    func doSomething() async {
        do {
            state = .loading
            let result = try await repo.fetch()
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
    var mockRepo: MockMyRepository!
    
    override func setUp() {
        super.setUp()
        mockRepo = MockMyRepository()
        sut = MyViewModel(repository: mockRepo)
    }
    
    func test_doSomething_succeeds() async {
        mockRepo.stubbedResult = .success(42)
        await sut.doSomething()
        XCTAssertEqual(sut.state, .success(42))
    }
}
```

---

## Build Automation

**Commands:**
```bash
fastlane tests          # Run 206+ tests
fastlane alpha          # Build for Firebase
fastlane beta           # Build for TestFlight
fastlane sync_certs     # Refresh certificates
```

**More details:** See `fastlane/Docs/DISTRIBUTION.md`

---

## Performance Targets

| Operation | Expected |
|-----------|----------|
| Tests | ~90 sec |
| Build (fresh) | ~8 min |
| Build (cached) | ~4 min |
| Real-time sync | < 3 sec |
| Phone search | < 2 sec |
| Nudge delivery | < 2 sec |

---

## CI/CD & Secrets

### Two-Workflow Strategy (Free Plan)

**ci.yml (Automatic Quality Gate):**
- Trigger: Every push to main + pull requests
- Purpose: Safety net — runs 206+ tests, reports status
- Time: ~90 seconds
- Failure: Blocks deployment (you see red X)

**deploy.yml (Manual Button):**
- Trigger: Manual only (GitHub → Actions → "🚀 Deploy to TestFlight" → Run)
- Purpose: Controlled release — only deploy when you decide
- Time: ~8 minutes total
- Failure: You fix and try again

**Why two workflows?** Free GitHub plan = limited concurrent runs. Split into fast auto-check + slow manual deploy saves quota.

### ci.yml (Automatic Quality Check)

```yaml
on:
  push: [ main ]
  pull_request: [ main ]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - Checkout code
      - Setup Ruby (3.3.0)
      - Run `fastlane tests` → All 206+ tests pass or fail
```

**What happens:**
- ✅ All tests pass → green checkmark → you can deploy
- ❌ Any test fails → red X → fix code → try again

### deploy.yml (Manual TestFlight Deployment)

```yaml
on:
  workflow_dispatch:  # Manual trigger only

jobs:
  deploy:
    runs-on: macos-latest
    steps:
      1. Checkout code
      2. Setup Ruby (3.3.0, bundler cache)
      3. Setup SSH + Trust Bitbucket (prevents hangs)
      4. Setup Xcode (latest)
      5. Create temporary keychain (3600s, auto-cleanup)
      6. Decode GoogleService-Info.plist from secrets
      7. Run `fastlane beta` (tests → certs → build → upload)
```

**Deployment Flow:**
1. Push code to main
2. ci.yml runs automatically (tests only)
3. If tests pass, you decide when to deploy
4. Click "Run workflow" on deploy.yml
5. Build signs, uploads to TestFlight (immediate return, no wait)
6. You manually approve in TestFlight before distribution

### Test Configuration

**Device:** iPhone 16 Pro (verified to exist on runners)

**Timeouts:**
```yaml
FASTLANE_XCODEBUILD_SETTINGS_TIMEOUT: 120    # Package resolution (seconds)
```

**Persistence:** Unit tests auto-use in-memory SwiftData (no disk I/O). Detected via `TestConfiguration.isRunningUnitTests`. See TESTING_GUIDE.md for details.

### SSH & Certificate Management

**SSH Access:** `webfactory/ssh-agent@v0.9.0` loads private key so `match` can clone Bitbucket certificates repo.

**Bitbucket Trust:** Pre-adds to known_hosts to prevent 3+ hour SSH handshake delays:
```bash
ssh-keyscan bitbucket.org >> ~/.ssh/known_hosts
```

**Keychain Setup:** Temporary throwaway keychain (3600s timeout) created before fastlane. No password stored.

**Firebase Configuration:** `GoogleService-Info.plist` is base64-encoded in secrets, decoded before build runs.

### Secret Protection

All secrets stored in GitHub (Settings > Secrets and variables > Actions):
- Never commit `.env` locally
- See "GitHub Secrets Setup" above for SSH key generation and all required secrets

---

## Debugging Tips

**Tests timeout?**
- Kill xcodebuild: `killall xcodebuild`
- Check disk space: `df -h`

**Build hangs?**
- Clear Xcode cache: `rm -rf ~/Library/Developer/Xcode/DerivedData/*`
- Restart Xcode

**Analytics not appearing?**
- Wait 5-10 minutes (Firebase batches)
- Check Release build (Debug disables analytics)
- Verify AnalyticsManager.log() is called

**Crashes not in Crashlytics?**
- Verify dSYM upload in build phases
- Wait 5 minutes
- Check Firebase Console > Crashlytics

---

**Last Updated:** January 30, 2026 | **Sprint:** 6.1 | **Status:** ✅ Production Ready
