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
      "paths": ["/notification/*", "/profile/*"]
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

## Security & Repository Safety

### Public Repository Checklist

- ✅ **No Hardcoded Secrets**: All API keys use `ENV["..."]` environment variables.
- ✅ **GoogleService-Info.plist Protected**: `.gitignore` includes it; config is passed via base64 GitHub Secrets.
- ✅ **Clean Git History**: No private keys or passwords in commit logs.
- ✅ **GitHub Secrets**: Think of it as two doors — `SSH_PRIVATE_KEY` unlocks the house, `MATCH_PASSWORD` unlocks the safe.

**GitHub Secrets Checklist:**

| Secret | Source | Purpose |
|--------|--------|---------|
| `SSH_PRIVATE_KEY` | Generated key | Clone Bitbucket certs repo |
| `MATCH_PASSWORD` | Your `.env` file | Decrypt certificates |
| `ASC_KEY_CONTENT` | `base64 fastlane/AuthKey_*.p8` | Apple API authentication |
| `ASC_KEY_ID` | Your `.env` file | Identify API key |
| `ASC_ISSUER_ID` | Your `.env` file | Identify team |
| `FASTLANE_USER` | Your `.env` file | Apple ID (fallback) |
| `GOOGLE_SERVICE_INFO_PLIST` | `base64 GoogleService-Info.plist` | Firebase configuration |

**Never Commit:**
- `.env` (credentials)
- `fastlane/Keys/*.p8` (API key)
- Passwords in code

---

## Build Automation

**Commands:**
```bash
fastlane tests          # Run all unit tests
fastlane alpha          # Build for Firebase
fastlane beta           # Build for TestFlight
fastlane sync_certs     # Refresh certificates
```

---

## Performance Targets

| Operation | Expected |
|-----------|----------|
| Tests | ~90 sec |
| Build (fresh) | ~8 min |
| Real-time sync | < 3 sec |
| Phone search | < 2 sec |

---

**Last Updated:** April 26, 2026 | **Sprint:** 6.5 | **Status:** ✅ Optimized for Production
