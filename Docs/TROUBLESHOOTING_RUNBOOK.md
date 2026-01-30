# UFree Troubleshooting Runbook

**Quick diagnosis and fixes for common issues across development, testing, build, and deployment**

---

## Quick Diagnosis Flow

```
Is your issue...?

├─ 🔧 Environment/Setup
│  └─ SETUP ISSUES (Section 1)
├─ 🧪 Testing
│  └─ TEST ISSUES (Section 2)
├─ 🔨 Building
│  └─ BUILD ISSUES (Section 3)
├─ 📦 Distribution
│  └─ DEPLOYMENT ISSUES (Section 4)
├─ 🔐 Certificates & Auth
│  └─ CERTIFICATE ISSUES (Section 5)
├─ 🚀 Performance
│  └─ PERFORMANCE ISSUES (Section 6)
└─ 🔔 Firebase & Monitoring
   └─ FIREBASE ISSUES (Section 7)
```

---

## 1. SETUP ISSUES

### Symptom: "gem install bundler fails with OpenSSL is not available"

**Environment:** macOS with Apple Silicon (M3)

**Root Cause:** RVM looking for OpenSSL in `/usr/local` (Intel path) but it's installed in `/opt/homebrew` (ARM64 path)

**Fix:**
```bash
# 1. Clean up
rvm uninstall 3.3.0
rvm cleanup all

# 2. Install dependencies to Homebrew (ARM64)
brew install openssl@3 libyaml

# 3. Force compilation from source with explicit paths
rvm install 3.3.0 \
  --disable-binary \
  --with-openssl-dir=$(brew --prefix openssl@3) \
  --with-libyaml-dir=$(brew --prefix libyaml)

# 4. Verify
ruby -ropenssl -e 'puts OpenSSL::OPENSSL_VERSION'
```

**Expected:** `OpenSSL 3.x.x ...`

---

### Symptom: "bundle install fails"

**Check:**
```bash
# 1. Verify Ruby version
ruby --version  # Should be 3.3.0+

# 2. Verify bundler
bundler --version

# 3. Check Gemfile exists
ls Gemfile

# 4. Try clean install
rm Gemfile.lock
bundle install
```

**If still failing:**
- Run M3 setup above (Section 1)
- Verify internet connectivity

---

### Symptom: ".env file not found" during fastlane run

**Fix:**
```bash
# Create from template
cp fastlane/.env.default fastlane/.env

# Edit with your credentials
nano fastlane/.env  # or vim, VS Code, etc
```

**Verify:**
```bash
# Check file exists
ls -la fastlane/.env

# Check it's loaded
env | grep ASC_KEY_ID  # Should show your key
```

---

### Symptom: "ASC_KEY_PATH file does not exist"

**Cause:** Using relative path or wrong path

**Fix:**
```bash
# 1. Verify .p8 file location
ls -la fastlane/Keys/AuthKey_*.p8

# 2. Get full absolute path
pwd  # Current directory
# Then construct: /Users/YourName/Documents/Development/.../fastlane/Keys/AuthKey_XXXXX.p8

# 3. Update fastlane/.env with ABSOLUTE path
nano fastlane/.env
# ASC_KEY_PATH=/Users/YourName/Documents/Development/.../fastlane/Keys/AuthKey_XXXXX.p8

# 4. Verify
cat fastlane/.env | grep ASC_KEY_PATH
```

---

## 2. TEST ISSUES

### Symptom: "Tests hang or timeout"

**Root Cause:** Xcode indexing heavy project on cold start (Firebase packages)

**Fix:**
```bash
# 1. Kill any stuck xcodebuild processes
killall xcodebuild

# 2. Run tests again (might take 45s first time, <5s after)
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | \
  grep -E '(passed|failed|PASS|FAIL)'

# 3. If still hanging, check free disk space
df -h | grep -E "(Disk|mounted)"
```

**Expected:** Tests finish in ~90 seconds

---

### Symptom: "No simulator specified" error

**Fix:**
```bash
# Always include destination flag
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# List available simulators
xcrun simctl list devices available
```

---

### Symptom: "Provisioning profile error during test"

**Issue:** Using `-scheme UFree` instead of `-scheme UFreeUnitTests`

**Fix:**
```bash
# ✅ CORRECT
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# ❌ WRONG
xcodebuild test -scheme UFree -project UFree.xcodeproj ...
```

---

### Symptom: "Test suite never finishes" (hangs forever)

**Cause:** Usually async test waiting for something that never completes

**Fix:**
```bash
# 1. Press Ctrl+C to kill
# 2. Check for infinite loops or blocked networking in recent changes
# 3. Run specific test to isolate
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing UFreeTests/YourTestClass/test_specific_test

# 4. Add timeout to async tests
func testWithTimeout() async {
    let task = Task {
        await someAsyncWork()
    }
    
    let result = try await withTimeoutError(seconds: 5) {
        await task.value
    }
}
```

---

## 3. BUILD ISSUES

### Symptom: "Xcode project not found"

**Fix:**
```bash
# Verify project exists
ls -la UFree.xcodeproj

# Verify scheme exists
xcodebuild -list -project UFree.xcodeproj | grep "UFree"
```

---

### Symptom: "Unsupported export_method: app-store-connect"

**Root Cause:** Using Xcode terminology instead of Fastlane terminology

**Fix:**
```ruby
# ❌ WRONG (Xcode term)
export_method: "app-store-connect"

# ✅ CORRECT (Fastlane term)
export_method: "app-store"
```

See: `Docs/INFRASTRUCTURE_SETUP.md → Fastlane "Golden" Configuration`

---

### Symptom: "No provisioning profile provided"

**Root Cause:** Xcode trying to auto-sign but export_options don't match

**Fix:**
```ruby
# In fastlane/Fastfile, add to export_options:
export_options: {
  signingStyle: "manual",           # ← CRITICAL
  provisioningProfiles: profile_mapping
}

# Also verify build_app has correct export_method
export_method: "app-store"           # ← CRITICAL
```

See: `Docs/INFRASTRUCTURE_SETUP.md → Fastlane "Golden" Configuration`

---

### Symptom: "Build takes 45+ seconds to start"

**Root Cause:** Xcode re-indexing Firebase packages

**Fix:** Already applied. Verify in Fastfile:
```ruby
run_tests(
  derived_data_path: "./fastlane/builds/DerivedData",  # ← Shared cache
  xcargs: "-skipPackagePluginValidation -clonedSourcePackagesDirPath ./fastlane/spm_cache"
)

build_app(
  derived_data_path: "./fastlane/builds/DerivedData",  # ← Must be same
  xcargs: "-skipPackagePluginValidation -clonedSourcePackagesDirPath ./fastlane/spm_cache"
)
```

**Expected:** <5s startup after first run

---

### Symptom: "Derived data needs to be rebuilt"

**Fix:**
```bash
# Clear and let Fastlane rebuild
rm -rf fastlane/builds/DerivedData/
fastlane beta  # Will rebuild from scratch
```

---

## 4. DEPLOYMENT ISSUES

### Symptom: "fastlane beta hangs at '[13:41]'"

**Root Cause:** match waiting for user action (credential prompt)

**Fix:**
```bash
# 1. Press Ctrl+C to stop
# 2. Verify credentials in .env
cat fastlane/.env | grep -E "(ASC_|MATCH_)"

# 3. Verify .env is actually loaded
env | grep ASC_KEY_ID  # Should show a value

# 4. Try again
fastlane beta
```

---

### Symptom: "Build appears in TestFlight but marked as 'Invalid Binary'"

**Root Cause:** Usually code signing issue or incorrect settings

**Fix:**
1. Check Xcode logs for specific error
2. Run `fastlane sync_certs` to refresh
3. Increment build number manually and retry:
   ```bash
   fastlane increment_build_number
   fastlane beta
   ```

---

### Symptom: "Firebase upload fails during fastlane beta"

**Root Cause:** Firebase App ID or distribution group missing

**Fix:**
```bash
# 1. Verify Firebase env vars
cat fastlane/.env | grep FIREBASE

# 2. Should be:
FIREBASE_APP_ID=1:639000000000:ios:a1b2c3d4e5f6g7h8i9j0
FIREBASE_GROUPS=internal-testers

# 3. If missing, add them and retry
fastlane beta
```

---

### Symptom: "TestFlight upload times out"

**Root Cause:** Large app or network issues

**Fix:**
```bash
# Run with verbose to see progress
fastlane beta --verbose

# Check network
ping -c 5 appstoreconnect.apple.com

# If network is good, retry
fastlane beta
```

---

## 5. CERTIFICATE ISSUES

### Symptom: "Certificate not found"

**Fix:**
```bash
# 1. Sync from encrypted repo
fastlane sync_certs

# 2. Force refresh if not found
fastlane match appstore --force

# 3. Verify .env has MATCH_PASSWORD
cat fastlane/.env | grep MATCH_PASSWORD
```

---

### Symptom: "Unknown provisioning profile"

**Root Cause:** Profile exists but not synced locally

**Fix:**
```bash
# 1. Force refresh all certificates
fastlane match appstore --force

# 2. Rebuild
fastlane beta
```

---

### Symptom: "Invalid passphrase for match"

**Root Cause:** MATCH_PASSWORD wrong or expired

**Fix:**
```bash
# 1. Find original password (check password manager, vault)
# 2. Update fastlane/.env:
MATCH_PASSWORD=correct_password

# 3. Verify
fastlane sync_certs
```

---

### Symptom: "Bundle ID mismatch" or "App ID not found"

**Root Cause:** Xcode project Bundle ID ≠ Apple Developer Portal ID

**Fix:**
```bash
# 1. Check current Bundle ID in Xcode
# Xcode > UFree target > Signing & Capabilities > Bundle Identifier

# 2. Verify it matches Appfile
cat fastlane/Appfile | grep app_identifier

# 3. If different, update Appfile
nano fastlane/Appfile
# app_identifier("com.khangvu.UFree")

# 4. Verify on Apple Developer Portal
# https://developer.apple.com/account/resources/identifiers/list

# 5. Try again
fastlane beta
```

---

### Symptom: "Git repo error" during match

**Root Cause:** Cannot access certificate repository (Bitbucket)

**Fix:**
```bash
# 1. Test Git access
git clone git@bitbucket.org:ufree-certificates/ios-certs.git

# 2. If it fails, check SSH keys
ssh -T git@bitbucket.org

# 3. If SSH key issue, regenerate
ssh-keygen -t ed25519 -C "your_email@example.com"
# Then add to Bitbucket → Personal Settings → SSH Keys
```

---

## 6. PERFORMANCE ISSUES

### Symptom: "Builds consistently slow (>10 min)"

**Verify optimizations are applied:**
```bash
# Check Fastfile has these
grep -E "(derived_data_path|clonedSourcePackagesDirPath)" fastlane/Fastfile

# If missing, add:
# run_tests and build_app should both have:
# - derived_data_path: "./fastlane/builds/DerivedData"
# - xcargs: "-skipPackagePluginValidation -clonedSourcePackagesDirPath ./fastlane/spm_cache"
```

**Expected times:**
- First run: ~8 minutes
- Subsequent: ~4-5 minutes

---

### Symptom: "Simulator slower than expected"

**Cause:** Simulator performing full simulation

**Fix:**
```bash
# 1. Use iPhone 17 Pro (most common, fastest)
xcodebuild ... -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# 2. Close other apps
killall Simulator

# 3. Erase and reset simulator
xcrun simctl erase iPhone\ 17\ Pro

# 4. Restart
xcrun simctl boot iPhone\ 17\ Pro
```

---

## 7. FIREBASE ISSUES

### Symptom: "Crashes not appearing in Crashlytics"

**Root Cause:** dSYM upload failed or Firebase not initialized

**Fix:**
```bash
# 1. Verify dSYM upload in Xcode
# Target → Build Phases → "Upload dSYMs to Firebase Crashlytics"

# 2. Check GoogleService-Info.plist exists
ls -la GoogleService-Info.plist

# 3. Rebuild and upload explicitly
fastlane beta

# 4. Crash app on TestFlight device
# Then wait 5-10 minutes

# 5. Check Firebase Console
# https://console.firebase.google.com → Crashlytics
```

---

### Symptom: "Analytics events not showing"

**Root Cause:** Not logging events from code

**Fix:**
```swift
// In ViewModels, add logging:
import FirebaseAnalytics

class NudgeViewModel: ObservableObject {
    func sendNudge() async {
        // ... do work ...
        AnalyticsManager.logNudgeSent(isBatch: false)  // ← Add this
    }
}
```

**Also verify:**
- Release build (Debug disables analytics)
- Wait 5-10 minutes (Firebase batches)
- Check Firebase Console → Analytics → Realtime

---

### Symptom: "Firebase initialization fails"

**Root Cause:** GoogleService-Info.plist missing or misconfigured

**Fix:**
```bash
# 1. Verify file exists
ls -la GoogleService-Info.plist

# 2. Verify it's included in Xcode target
# Xcode > UFree target > Build Phases > Copy Bundle Resources
# Should include GoogleService-Info.plist

# 3. Download latest from Firebase Console
# https://console.firebase.google.com → Project Settings → Download GoogleService-Info.plist

# 4. Rebuild
fastlane beta
```

---

## 8. GENERAL WORKFLOWS

### "I need to understand what happened"

Check these files in order:
1. **Setup issues:** `Docs/INFRASTRUCTURE_SETUP.md`
2. **Code & testing:** `Docs/AGENTS.md`
3. **Fastlane workflows:** `fastlane/Docs/DISTRIBUTION.md`
4. **This file:** `Docs/TROUBLESHOOTING_RUNBOOK.md`

---

### "Something broke and I don't know where to start"

1. **Identify the layer:**
   - Setup/Ruby → Section 1
   - Tests → Section 2
   - Xcode/Building → Section 3
   - Fastlane/Distribution → Section 4
   - Certificates → Section 5
   - Performance → Section 6
   - Firebase → Section 7

2. **Find your symptom** in the section

3. **Follow the fix** step-by-step

4. **Still stuck?** → Run with verbose:
   ```bash
   fastlane beta --verbose
   ```

---

### "I want to skip tests and build anyway"

**Not recommended,** but if you must:
```bash
# Edit fastlane/Fastfile
nano fastlane/Fastfile

# Find beta lane, comment out tests call:
lane :beta do
  # tests  # ← Comment this out
  
  api_key = setup_api_key
  # ... rest of lane
end

# Then run
fastlane beta
```

---

### "I need to force refresh everything"

```bash
# 1. Clean Xcode cache
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf fastlane/builds/DerivedData/

# 2. Refresh certificates
fastlane match appstore --force

# 3. Clear Fastlane cache
rm -rf fastlane/builds/
rm -rf fastlane/test_results/

# 4. Full rebuild
fastlane beta
```

---

## Quick Reference Table

| Symptom | Section | Quick Fix |
|---------|---------|-----------|
| OpenSSL not available | 1 | M3 Magic Install (ruby + homebrew) |
| bundle install fails | 1 | Verify Ruby 3.3.0 + OpenSSL |
| Tests timeout | 2 | Kill xcodebuild, retry |
| No simulator | 2 | Add `-destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |
| No provisioning profile | 3 | Add `signingStyle: "manual"` to export_options |
| Export method unsupported | 3 | Use `"app-store"` not `"app-store-connect"` |
| Build slow | 3/6 | Verify derived_data_path and SPM caching |
| fastlane hangs | 4 | Ctrl+C, verify .env loaded, retry |
| TestFlight invalid | 4 | Refresh certs, retry |
| Cert not found | 5 | `fastlane match appstore --force` |
| Invalid passphrase | 5 | Update MATCH_PASSWORD in .env |
| Git repo error | 5 | Test SSH key, check Bitbucket access |
| Crashes not showing | 7 | Verify dSYM upload, wait 5-10 min |
| Analytics empty | 7 | Add AnalyticsManager.log() calls |

---

**Last Updated:** January 30, 2026 | **Sprint:** 6.1 | **Status:** ✅ Production Ready
