# Fastlane Reference & Troubleshooting

**Quick commands, advanced configuration, and problem solving**

---

## Quick Command Reference

### Distribution Commands
```bash
fastlane tests                          # Run 206+ unit tests (~90s)
fastlane alpha                          # Build & upload to Firebase (~3 min)
fastlane beta                           # Build & upload to TestFlight (~8 min)
fastlane sync_certs                     # Manually refresh certificates (~30s)
fastlane get_testflight_build_number    # Get latest build number (~5s)
fastlane test_report                    # Tests with detailed report (~90s)
```

### Helpful Flags
```bash
fastlane beta --verbose                 # Detailed build logs
fastlane match appstore --force          # Force refresh certificates (renew)
fastlane match appstore --readonly       # Read-only mode (don't update)
```

---

## Configuration Reference

### Fastfile Structure
```ruby
default_platform(:ios)                              # iOS-only

def is_ci                                           # CI detector
  ENV["CI"] == "true" || ENV["GITHUB_ACTIONS"] == "true"
end

def setup_api_key                                   # API key loader
  app_store_connect_api_key(
    key_id: ENV["ASC_KEY_ID"],
    issuer_id: ENV["ASC_ISSUER_ID"],
    key_filepath: ENV["ASC_KEY_PATH"],
    duration: 1200,
    in_house: false
  )
end

platform :ios do
  lane :tests      # Run unit tests
  lane :alpha      # Firebase distribution
  lane :beta       # TestFlight distribution
  lane :sync_certs # Manual certificate sync
end
```

### Appfile (Configuration)
```ruby
app_identifier("com.khangvu.UFree")       # Bundle ID
team_id("SNUXAG727V")                     # Developer Portal Team ID
itc_team_id("SNUXAG727V")                 # App Store Connect Team ID

# DO NOT INCLUDE:
# apple_id()              ← Triggers password prompts
# itunes_connect_id()     ← Triggers password prompts
```

### Matchfile (Certificate Config)
```ruby
git_url("git@bitbucket.org:ufree-certificates/ios-certs.git")
storage_mode("git")
type("appstore")
app_identifier(["com.khangvu.UFree"])
team_id("SNUXAG727V")
skip_confirmation(true)
verbose(false)
```

### .env (Credentials)
```env
ASC_KEY_ID=87PFYWC45Y
ASC_ISSUER_ID=b69096cf-7844-40b1-9824-8f2154c1b541
ASC_KEY_PATH=/absolute/path/to/fastlane/Keys/AuthKey_87PFYWC45Y.p8
MATCH_PASSWORD=your_encryption_password
FIREBASE_APP_ID=1:639000000000:ios:a1b2c3d4e5f6g7h8i9j0
FIREBASE_GROUPS=internal-testers
```

**Never commit .env. Always use absolute paths.**

---

## File Structure Reference

```
fastlane/
├── Fastfile                 ← 6 lanes (tests, alpha, beta, sync_certs, helpers)
├── Appfile                  ← App configuration (commit this)
├── Matchfile                ← Certificate config (commit this)
├── .env                     ← Credentials (NEVER commit)
├── .env.default             ← Template (commit this)
├── .gitignore               ← Protection rules (commit this)
├── Keys/
│   └── AuthKey_*.p8         ← API key (NEVER commit)
├── builds/
│   ├── DerivedData/         ← Xcode cache (reused across builds)
│   ├── spm_cache/           ← SPM packages (cached)
│   ├── UFree.xcarchive/     ← Build archive
│   └── UFree.ipa            ← Signed app
├── test_results/            ← Test reports
└── Docs/
    ├── GETTING_STARTED.md   ← Start here
    ├── DISTRIBUTION.md      ← All workflows
    └── REFERENCE.md         ← This file
```

### Never Commit ❌
- `.env` (credentials)
- `Keys/*.p8` (API key file)
- `.fastlane_user`, `.fastlane_password` (sessions)
- `builds/`, `test_results/` (artifacts)

### Always Commit ✅
- `Fastfile`, `Appfile`, `Matchfile` (code & config)
- `.env.default`, `.gitignore` (templates & rules)
- `Docs/` (documentation)

---

## Troubleshooting

### Authentication Issues

#### "Please provide your Apple Developer Program account credentials"
**Cause:** Missing or misconfigured API key.

**Fix:**
```bash
# 1. Verify .env exists and is loaded
ls -la fastlane/.env

# 2. Verify ASC_KEY_PATH file exists
ls -la fastlane/Keys/AuthKey_*.p8

# 3. Verify Appfile doesn't have credentials
grep "apple_id\|itunes_connect" fastlane/Appfile

# 4. Test sync
fastlane sync_certs
```

**Still failing?**
- Verify ASC_KEY_PATH is ABSOLUTE (full path, not `./relative/path`)
- Verify ASC_KEY_ID and ASC_ISSUER_ID match App Store Connect
- Verify .env file is actually loaded: check `cat fastlane/.env | grep ASC`

#### "invalid number: '-----BEGIN' at line 1"
**Cause:** Using wrong key file format.

**Fix:** Use `.p8` file ONLY (not JSON, not other formats).

---

### Certificate Issues

#### "Certificate not found"
```bash
fastlane sync_certs
# or force refresh
fastlane match appstore --force
```

#### "Unknown provisioning profile"
```bash
# Refresh all certificates
fastlane match appstore --force

# Then rebuild
fastlane beta
```

#### "Git repo error"
**Cause:** Cannot access GitHub/Bitbucket certificate repo.

**Fix:**
```bash
# Test Git access
git clone git@bitbucket.org:ufree-certificates/ios-certs.git

# Verify SSH key is set up
ssh -T git@bitbucket.org
```

#### "Invalid passphrase"
**Cause:** MATCH_PASSWORD wrong or expired.

**Fix:**
```bash
# Find original passphrase (check password manager)
# Update fastlane/.env:
MATCH_PASSWORD=correct_password

# Try again
fastlane sync_certs
```

---

### Build Issues

#### Build takes 45+ seconds to start
**Cause:** Xcode re-indexing projects.

**Fix:** Already applied in your Fastfile:
- ✅ `derived_data_path: "./fastlane/builds/DerivedData"` (shared cache)
- ✅ `xcargs: "-skipPackagePluginValidation -clonedSourcePackagesDirPath ./fastlane/spm_cache"` (SPM caching)

If still slow, verify these are in `run_tests` AND `build_app`.

#### Tests fail but you want to build anyway
Edit `fastlane/Fastfile` and comment out `tests` call in beta lane:
```ruby
lane :beta do
  # tests  # ← Comment out to skip
  
  api_key = setup_api_key
  # ... rest of lane
end
```

**Not recommended** — tests are your safety gate.

#### "Xcode project not found"
```bash
# Verify project exists
ls -la UFree.xcodeproj

# Verify scheme exists
xcodebuild -list -project UFree.xcodeproj
```

---

### Firebase Issues

#### Crashes not appearing in Crashlytics
**Cause:** dSYM upload failed.

**Fix:**
1. Verify Xcode has build phase script:
   - Target → Build Phases → "Upload dSYMs to Firebase Crashlytics"
2. Run fastlane beta again (it uploads dSYMs)
3. Crash app on TestFlight device
4. Wait 5 minutes
5. Check Firebase Console → Crashlytics

#### Analytics events not showing
**Cause:** Not calling AnalyticsManager from code.

**Fix:** Add logging calls in ViewModels:
```swift
import FirebaseAnalytics

class NudgeViewModel {
  func sendNudge(_ friend: Friend) async {
    try await nudgeService.send(to: friend)
    AnalyticsManager.logNudgeSent(isBatch: false)  // ← Add this
  }
}
```

---

### Match & Certificate Management

#### How match works
1. Private GitHub repo stores encrypted certificates
2. `MATCH_PASSWORD` encrypts/decrypts them
3. `fastlane match appstore` downloads and installs locally
4. Xcode signs with these certificates

#### When to use `--force`
```bash
# Certificate expiring soon or expired
fastlane match appstore --force

# Renew yearly to avoid surprises
fastlane match appstore --force
```

#### Sharing certificates with team
1. They need: GitHub access + MATCH_PASSWORD
2. Run: `fastlane sync_certs`
3. Done (certificates auto-installed)

---

## Lanes in Detail

### tests Lane (~90 seconds)
```ruby
lane :tests do
  run_tests(
    project: "UFree.xcodeproj",
    scheme: "UFreeUnitTests",
    devices: ["iPhone 17 Pro"],
    clean: true,
    fail_build: true,
    output_directory: "fastlane/test_results",
    result_bundle: true,
    derived_data_path: "./fastlane/builds/DerivedData",
    xcargs: "-skipPackagePluginValidation -clonedSourcePackagesDirPath ./fastlane/spm_cache"
  )
end
```

**Use when:** Validating code before distribution.

### alpha Lane (~3 minutes)
```ruby
lane :alpha do
  tests
  build_app(
    project: "UFree.xcodeproj",
    scheme: "UFree",
    configuration: "Release",
    export_method: "ad-hoc",
    # ... builds for Firebase
  )
  firebase_app_distribution(
    app: ENV["FIREBASE_APP_ID"],
    ipa_path: "./fastlane/builds/UFree.ipa",
    groups: ENV["FIREBASE_GROUPS"]
  )
end
```

**Use when:** Testing on device instantly (no Apple review).

### beta Lane (~8 minutes)
```ruby
lane :beta do
  tests
  api_key = setup_api_key
  produce(...)          # Ensure App ID exists
  match(...)            # Get certificates
  increment_build_number(...)
  build_app(...)        # Build for App Store
  upload_symbols_to_crashlytics(...)
  upload_to_testflight(...)
end
```

**Use when:** Submitting to TestFlight for external testers.

### sync_certs Lane (~30 seconds)
```ruby
lane :sync_certs do
  api_key = setup_api_key
  match(
    type: "appstore",
    readonly: is_ci,
    skip_confirmation: true,
    api_key: api_key
  )
end
```

**Use when:** Manually refreshing certificates (new team member, expired certs, etc).

---

## Performance Metrics

### Build Times (M1 Mac)
| Stage | Time |
|-------|------|
| Tests | ~60s |
| Sync certificates | ~10s |
| Build (fresh) | ~120s |
| Build (cached) | ~45s |
| Upload to TestFlight | ~30s |
| **Total (fresh)** | **~8 min** |
| **Total (cached)** | **~4-5 min** |

### Optimizations Applied
- ✅ Shared derived data (`DerivedData/` reused)
- ✅ SPM caching (`spm_cache/` prevents re-download)
- ✅ Skipped plugin validation (faster build start)
- ✅ CI optimization (`setup_ci` for CI machines)

### Cold vs Warm Start
- **First run:** ~45s startup (Xcode indexing)
- **Subsequent runs:** <5s startup (cached data)

---

## Environment Variables

### Required
```env
ASC_KEY_ID              # App Store Connect Key ID
ASC_ISSUER_ID           # App Store Connect Issuer ID
ASC_KEY_PATH            # Absolute path to .p8 file
MATCH_PASSWORD          # Certificate encryption password
```

### Optional
```env
FIREBASE_APP_ID         # Firebase app ID (for alpha lane)
FIREBASE_GROUPS         # Firebase tester groups (default: internal-testers)
SLACK_WEBHOOK           # Slack notifications (optional)
```

### CI/CD (GitHub Actions)
Use GitHub Secrets instead of .env:
```yaml
Settings → Secrets and variables → Actions:
  ASC_KEY_ID
  ASC_ISSUER_ID
  ASC_KEY_PATH
  MATCH_PASSWORD
```

---

## FAQs

**Q: Do I need to commit my API key (.p8)?**
A: No. Keep it private. Only commit `.env.default` as a template.

**Q: Can I use password authentication instead of API key?**
A: Not recommended. API key is more secure and works with CI/CD better.

**Q: How often do certificates expire?**
A: Signing certs: 3 years. Provisioning profiles: 1 year. match handles renewal.

**Q: What if I lose MATCH_PASSWORD?**
A: You can create a new one:
```bash
fastlane match appstore --force
# Set a new passphrase
# Everyone runs `fastlane sync_certs` with new password
```

**Q: Can multiple developers use the same Fastlane setup?**
A: Yes. Just share MATCH_PASSWORD securely (1Password, Vault, etc).

**Q: Does Fastlane work on non-Mac machines?**
A: No. Xcode/iOS development requires macOS.

---

## Getting Help

**Check these first:**
1. GETTING_STARTED.md (setup walkthrough)
2. DISTRIBUTION.md (workflows & lanes)
3. This file (troubleshooting)

**Still stuck?**
- Verify .env is loaded: `env | grep ASC`
- Check Fastfile syntax: `ruby -c fastlane/Fastfile`
- Run with verbose: `fastlane beta --verbose`
- Check Fastlane docs: https://docs.fastlane.tools/

---

**Date:** January 26, 2026 | **Version:** 1.0
