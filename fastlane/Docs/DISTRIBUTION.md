# Distribution & Workflows

**All distribution lanes, certificate management, performance tuning, and Firebase setup**

---

## 3 Main Lanes

### fastlane tests
**Run all unit tests (validation gate)**
```bash
fastlane tests
```

- Runs 206+ unit tests
- ~90 seconds
- Exit code 1 if any fail (prevents broken code reaching testers)

### fastlane alpha
**Build & upload to Firebase (instant testing)**
```bash
fastlane alpha
```

**Workflow:**
1. Run 206+ tests (validation gate)
2. Build IPA for Ad-Hoc distribution
3. Upload to Firebase App Distribution
4. Get instant link to install on your device
5. ~3 minutes total

**Who uses it:** Developers, QA, internal testers

### fastlane beta
**Build & upload to TestFlight (formal testing)**
```bash
fastlane beta
```

**Workflow:**
1. Run 206+ tests (validation gate)
2. Sync certificates from GitHub (via match)
3. Auto-increment build number
4. Build IPA for App Store
5. Upload dSYMs to Firebase Crashlytics
6. Upload to TestFlight (immediate return, no wait)
7. ~8 minutes total

**Distribution:** Build uploads but requires manual approval in TestFlight before external testers are notified.

**Who uses it:** Product, external testers, App Store review

---

## Helper Lanes

### Get Latest TestFlight Build Number
```bash
fastlane get_testflight_build_number
```
Returns the latest build number on TestFlight. Used by `beta` to auto-increment.

### Sync Certificates Manually
```bash
fastlane sync_certs
```
Manually refresh certificates from GitHub. Use if:
- Certificates expire
- New developer joins team
- "Unknown provisioning profile" error

### Run Tests with Report
```bash
fastlane test_report
```
Same as `tests` but generates detailed HTML report in `fastlane/test_results/`

---

## Certificate Management: match

### What is match?

match solves certificate headaches:

| Problem | match Solution |
|---------|--------|
| ❌ Manually download .p12 from Apple | ✅ Encrypted GitHub repo |
| ❌ Share certificates via email | ✅ One MATCH_PASSWORD |
| ❌ Certificates expire without warning | ✅ Auto-renew on expiration |
| ❌ "Certificate not found" on new machines | ✅ Just set MATCH_PASSWORD & run |
| ❌ CI/CD requires Apple ID + password | ✅ GitHub secret + API key |

### How It Works

**Your first time:**
```bash
fastlane match appstore
# Creates certificates, encrypts, commits to GitHub
```

**Your team member (or new machine):**
```bash
export MATCH_PASSWORD=password_you_shared_securely
fastlane beta
# Automatically:
# 1. Clones encrypted repo from GitHub
# 2. Decrypts with MATCH_PASSWORD
# 3. Installs to ~/.match/
# 4. Builds and uploads
```

**When certificates expire (3 years):**
```bash
fastlane match appstore --force
# Creates new certs, updates GitHub, everyone syncs
```

### match Configuration

In `fastlane/Matchfile`:
```ruby
git_url("git@bitbucket.org:ufree-certificates/ios-certs.git")
storage_mode("git")
type("appstore")
app_identifier(["com.khangvu.UFree"])
team_id("SNUXAG727V")

# Temporary keychain (CI/CD only, created by GitHub Actions workflow)
keychain_name("build.keychain") if ENV["GITHUB_ACTIONS"] == "true"
keychain_password("") if ENV["GITHUB_ACTIONS"] == "true"

skip_confirmation(true)
verbose(false)
```

### match in Fastfile

Used in beta lane:
```ruby
api_key = setup_api_key

match(
  type: "appstore",
  readonly: true,          # Always read-only (prevent accidental writes)
  skip_confirmation: true, # Never prompt (certs already encrypted)
  api_key: api_key        # Use API key auth
)
```

**Why `readonly: true`?**
- Prevents accidental certificate modifications locally
- CI/CD creates temporary keychain automatically (no write needed)
- Safer pattern for team environments

---

## TestFlight Distribution Workflow

### Before: Manual Steps
1. ❌ Open Xcode manually
2. ❌ Download provisioning profiles
3. ❌ Archive app
4. ❌ Export IPA
5. ❌ Upload to TestFlight
6. ❌ Wait for Apple processing
7. ❌ Notify testers manually

### After: One Command
```bash
fastlane beta
```
- ✅ Runs 206+ tests
- ✅ Syncs certificates (match)
- ✅ Auto-increments build number
- ✅ Builds IPA (parallel compilation)
- ✅ Uploads dSYMs
- ✅ Uploads to TestFlight
- ✅ Sends notification to external testers

**Time:** ~8 minutes (vs 30+ minutes manually)

### TestFlight Configuration

In `fastlane/Fastfile`:
```ruby
upload_to_testflight(
  ipa: "./fastlane/builds/UFree.ipa",
  api_key: api_key,
  skip_submission: true,              # Requires manual approval in TestFlight
  skip_waiting_for_build_processing: true,  # Returns immediately
  beta_app_review_info: {
    contact_email: ENV["APPLE_ID"] || "kmvu91@gmail.com",
    contact_first_name: "Test_account",
    contact_last_name: "#{latest_build}",
    contact_phone: "+84932440258",
    demo_account_name: "test+ufree_#{latest_build}@example.com",
    demo_account_password: "password123",
    notes: "Real-world testing for availability discovery feature"
  }
)
```

---

## Firebase Setup

### Crashlytics: Monitor Crashes

**Auto-initialized.** Every build uploads dSYMs (debug symbols).

When users crash, you see:
- ✅ Readable stack traces (not memory addresses)
- ✅ Device info (iOS version, model)
- ✅ User session info
- ✅ Real-time alerts

**In Fastfile:**
```ruby
upload_symbols_to_crashlytics(
  gsp_path: "GoogleService-Info.plist"
)
```

**View crashes:** Firebase Console → Crashlytics

### Analytics: Track User Behavior

**Auto-initialized.** Call from ViewModels to track:

```swift
// In NudgeViewModel:
AnalyticsManager.logNudgeSent(isBatch: false)

// In SearchViewModel:
AnalyticsManager.logPhoneSearchSuccess()

// In StatusViewModel:
AnalyticsManager.log(.availabilityUpdated(status: newStatus))
```

**View events:** Firebase Console → Analytics → Realtime

---

## Performance Optimization

### Cold Start Time: 45s → <5s

**Three optimizations applied:**

#### 1. Shared Derived Data
```ruby
run_tests(
  # ...
  derived_data_path: "./fastlane/builds/DerivedData",
  xcargs: "-skipPackagePluginValidation -clonedSourcePackagesDirPath ./fastlane/spm_cache"
)

build_app(
  # ...
  derived_data_path: "./fastlane/builds/DerivedData",
  xcargs: "-skipPackagePluginValidation -clonedSourcePackagesDirPath ./fastlane/spm_cache"
)
```

**What:** Reuses indexed code across test and build steps.

**Why:** Prevents Xcode from re-indexing 206+ tests + 14+ Firebase packages.

#### 2. SPM Package Caching
```ruby
xcargs: "-skipPackagePluginValidation -clonedSourcePackagesDirPath ./fastlane/spm_cache"
```

**What:** Caches downloaded packages and skips re-verification.

**Why:** Firebase verification takes 10-20s per run.

#### 3. CI Optimization
```ruby
lane :beta do
  setup_ci if is_ci
  # ... rest of lane
end
```

**What:** Configures Xcode with CI-optimized build settings.

**Why:** Faster metadata lookup on CI machines.

### Results

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Cold start | ~45s | <5s | 9x faster |
| Test + Build | ~8 min | ~4-5 min | 2x faster |
| Derived data reuse | None | Full | Every run |
| SPM re-verification | Every run | Cached | 10-20s saved |

---

## Build Number Management

### Auto-Increment Strategy

```ruby
increment_build_number(
  build_number: latest_testflight_build_number(api_key: api_key) + 1
)
```

**What happens:**
1. `latest_testflight_build_number(api_key: api_key)` queries Apple for latest
2. Add 1
3. `increment_build_number()` updates local Info.plist
4. Build uses new number

**Why:** Never manually increment. Automatic = no conflicts.

---

## File Structure

```
fastlane/
├── Fastfile                    ← 5 lanes (tests, alpha, beta, sync_certs, helpers)
├── Appfile                     ← App configuration (already clean)
├── Matchfile                   ← Certificate config
├── .env                        ← Credentials (NEVER commit)
├── .env.default                ← Template (commit this)
├── .gitignore                  ← Protections (commit this)
├── Keys/
│   └── AuthKey_*.p8            ← API key (NEVER commit)
├── builds/
│   ├── DerivedData/            ← Shared Xcode cache
│   ├── spm_cache/              ← SPM package cache
│   ├── UFree.xcarchive/        ← Archive
│   └── UFree.ipa               ← Built app
├── test_results/               ← Test output
└── Docs/
    ├── GETTING_STARTED.md      ← Local setup (3 steps)
    ├── DISTRIBUTION.md         ← Workflows (this file)
    ├── REFERENCE.md            ← Commands & troubleshooting
    └── INDEX.md                ← Navigation guide
```

**CI/CD Configuration:** See Docs/AGENTS.md → Security & Secrets → GitHub Secrets Setup

---

## Distribution Checklist

### Before Every fastlane beta

- [ ] Run `fastlane tests` → All pass
- [ ] Run `fastlane sync_certs` → No prompts
- [ ] Verify build number will increment
- [ ] Update release notes (optional)
- [ ] TestFlight build slot available

### After fastlane beta

- [ ] Build appears in TestFlight within 2-5 minutes
- [ ] External testers notified
- [ ] Monitor crashes in Crashlytics
- [ ] Track user behavior in Analytics

---

## Common Workflows

### Iteration: Test Local Changes
```bash
# Build for your device
fastlane alpha

# Install from Firebase link
# Test on device
# Fix bugs
# Repeat
```

### Release: Submit to External Testers
```bash
# Final validation
fastlane tests

# Build & submit to TestFlight
fastlane beta

# Approve in TestFlight (App Store Connect → TestFlight → "Approve for Testing" → "Send to Testers")
```

**Manual approval required:** After `fastlane beta` completes, you must manually approve the build in TestFlight before external testers are notified. This prevents accidental releases.

### Emergency: Force Refresh Certificates
```bash
fastlane match appstore --force
```

---

**Date:** January 26, 2026 | **Version:** 1.0
