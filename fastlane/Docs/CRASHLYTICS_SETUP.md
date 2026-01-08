# Firebase Crashlytics Setup - Real-World Testing Insights

**Silent sentry for crash monitoring: See exactly what breaks on friends' devices.**

---

## The Problem Crashlytics Solves

Without crash reporting:
- ❌ Friends report "the app crashed" but you don't know why
- ❌ No stack trace to debug
- ❌ Can't see if crashes are device-specific (iPhone 13 vs iPhone 17 Pro)
- ❌ Can't identify if it's a network issue or concurrency bug

With Crashlytics:
- ✅ Instant crash notifications in Firebase Console
- ✅ Readable stack traces (dSYMs map memory addresses to code)
- ✅ Filter crashes by device model, iOS version, app version
- ✅ Identify patterns: "All crashes on iPhone 13 with iOS 17.1"
- ✅ Catch race conditions and network resilience bugs in the wild

---

## What Was Added (Sprint 6.1+)

### 1. UFreeApp.swift
```swift
import FirebaseCrashlytics

// In AppDelegate.application(_:didFinishLaunchingWithOptions:)
#if !DEBUG
Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
#endif
```

**Why?**
- Imports Crashlytics framework
- Enables collection in Release builds (disables in Debug to avoid test noise)
- Automatically captures crashes without additional code

### 2. Fastfile (beta lane)
```ruby
# In build_app step
build_app(
  include_symbols: true,      # Generate dSYM files
  include_bitcode: false      # Required for dSYM upload
)

# After build_app
upload_symbols_to_crashlytics(
  gsp_path: "GoogleService-Info.plist"
)
```

**Why?**
- `include_symbols: true` → Generates debug symbols (dSYM files)
- `upload_symbols_to_crashlytics` → Sends them to Firebase
- Firebase maps crash memory addresses to your actual code lines

### 3. Xcode Build Phase Script (Manual Setup)
In Xcode, you must add a "Run Script" build phase:

**Path:** UFree target → Build Phases → + → New Run Script Phase

**Name:** `Upload dSYMs to Firebase Crashlytics`

**Script:**
```bash
"${BUILD_DIR%Build/*}SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
```

**Settings:**
- ✅ Leave "Based on dependency analysis" **UNCHECKED** (runs every archive)
- ✅ Leave shell as `/bin/bash`

**Placement:** Add it AFTER "Compile Sources" but BEFORE "Link Binary with Libraries"

---

## How It Works

### 1. Local Development (Debug)
```
fastlane alpha
  ↓
Builds with dSYMs but Crashlytics collection disabled
  ↓
If crashes occur, they're only in device console
  ↓
Clean logs, no Firebase noise
```

### 2. TestFlight Distribution (Release)
```
fastlane beta
  ↓
Build step: Generates dSYMs
  ↓
Upload step: Sends dSYMs to Firebase Crashlytics
  ↓
Build uploaded to TestFlight
  ↓
When testers use the app, crashes auto-upload to Firebase
  ↓
You see them instantly in Firebase Console
```

### 3. What Happens When a Friend's App Crashes
```
Friend's device (Release build with Crashlytics enabled)
  ↓
App crashes (e.g., race condition in Nudge batching)
  ↓
Crashlytics captures:
  - Stack trace (which functions called which)
  - Device model (iPhone 13)
  - iOS version (17.1)
  - App version (1.0 build 23)
  - Network status (WiFi/LTE/none)
  ↓
Device sends to Firebase (next app launch if offline)
  ↓
You see in Firebase Console → Crashlytics → All Crashes
  ↓
Click crash → View full stack trace with line numbers + code
```

---

## Verification Steps

### 1. Verify Crashlytics is initialized
```bash
# Run your app in simulator (Debug mode)
# Open Console.app → filter by "Crashlytics"
# You should see: "Crashlytics collection is disabled in Debug builds"
# ✅ This is correct (prevents debug noise)
```

### 2. Test with Release build
```bash
# Build for App Store (creates dSYMs)
xcodebuild archive -scheme UFree -configuration Release

# dSYMs should be in:
# ~/Library/Developer/Xcode/Archives/[date]/UFree.xcarchive/dSYMs/
```

### 3. Verify build phase script runs
```bash
# Build the project in Xcode
# In build log, you should see:
# "Upload dSYMs to Firebase Crashlytics"
# If missing, add the build phase (see section above)
```

### 4. Verify dSYMs upload in Fastfile
```bash
# Run beta lane locally (requires TestFlight credentials)
fastlane beta

# In the output, look for:
# "📤 Uploading dSYMs to Firebase Crashlytics..."
# "✅ Build uploaded to TestFlight with Crashlytics reporting enabled"
```

### 5. Test crash reporting (Optional)
Add a test crash button in your debug menu:

```swift
#if DEBUG
Button("Test Crash") {
    fatalError("Crashlytics Test Crash")
}
#endif
```

Run in Release mode, trigger crash, and check Firebase Console within 5 minutes.

---

## Firebase Console Setup

### 1. Enable Crashlytics
- Go to [Firebase Console](https://console.firebase.google.com)
- Select your UFree project
- Left menu → Crashlytics
- If not activated, click "Create issue" or "Enable"

### 2. View Crashes
- **Crashes tab** → All crashes from all versions
- **Filter by:**
  - Device: iPhone 13, iPhone 17 Pro, etc.
  - iOS version: 17.0, 17.1, etc.
  - App version: 1.0, 1.1, etc.

### 3. Analyze a Crash
- Click any crash
- See full stack trace with file names and line numbers
- Example:
  ```
  at ScheduleViewModel.fetchAvailability() [ScheduleViewModel.swift:142]
  at TaskGroup.addTask() [Concurrency.swift:78]
  ```

---

## Real-World Testing Scenarios

### Scenario 1: Network Resilience
```
Friend on LTE → WiFi transition
  ↓
Firestore write in progress
  ↓
Network switch causes timeout exception
  ↓
Race condition in TaskGroup logic (not caught in simulator)
  ↓
App crashes
  ↓
Crashlytics captures:
  - "URLError: The network connection was lost"
  - Stack trace showing concurrent write
  - Device: iPhone 13 on iOS 17.1
  ↓
You see pattern: All crashes on LTE devices
```

### Scenario 2: Concurrency Bug
```
Nudge batching with async/await
  ↓
Friend gets 50 nudges in 2 seconds
  ↓
TaskGroup processes all concurrently
  ↓
Shared state access without synchronization
  ↓
Data race detected (Release mode only)
  ↓
App crashes
  ↓
Crashlytics shows:
  - "Swift Concurrency: Race Condition"
  - Exact function and line number
  - Easily reproduced with test: Send 50 nudges
```

### Scenario 3: Memory/Performance
```
Heatmap view rendering
  ↓
10,000 friend locations on map
  ↓
Friends' old devices run out of memory
  ↓
App gets terminated (not a traditional crash)
  ↓
Crashlytics captures:
  - "Memory pressure"
  - Device: iPhone 11 (older hardware)
  ↓
You optimize heatmap: Cluster pins, pagination, etc.
```

---

## Disabling/Enabling Collection

### Disable Crashlytics (if needed)
```swift
Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
```

### Enable only for TestFlight
The current setup already does this:
```swift
#if !DEBUG
Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
#endif
```

This means:
- ✅ Debug builds: Disabled (clean logs)
- ✅ Release/TestFlight: Enabled (crash reporting)

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "dSYMs not found" in console | Ensure `include_symbols: true` in Fastfile `build_app` |
| "Upload failed" message | Check GoogleService-Info.plist exists in repo root |
| Build phase script not running | Verify script is in correct build phase and "Based on dependency analysis" is **unchecked** |
| Crashes not appearing in Firebase | Wait 5-10 minutes; reload Firebase Console; check app version matches |
| Build phase script shows warning | This is OK if dSYMs upload still succeeds (just indicates Firebase SDK not found on first check) |

---

## Files Modified/Created

| File | Change | Purpose |
|------|--------|---------|
| `UFree/UFreeApp.swift` | Added `FirebaseCrashlytics` import + init | Enable crash reporting |
| `fastlane/Fastfile` | Added `include_symbols` + `upload_symbols_to_crashlytics` | Automate dSYM upload |
| `Scripts/upload_dsyms.sh` | Created | Build phase script template |
| `GoogleService-Info.plist` | Already exists | Connects to Firebase |

---

## Next Steps

1. ✅ **Code is ready** - UFreeApp.swift and Fastfile already updated
2. 🔧 **Manual Xcode step** - Add build phase script (see "Xcode Build Phase Script" above)
3. 🚀 **Test** - Run `fastlane beta` and verify dSYMs upload
4. 👥 **Distribute to testers** - TestFlight builds now have Crashlytics enabled
5. 📊 **Monitor** - Check Firebase Console for crashes as friends test the app

---

## Quick Reference

### Check if Crashlytics is working
```bash
# 1. Build for Archive (Release mode)
xcodebuild archive -scheme UFree -configuration Release

# 2. Run beta lane
fastlane beta

# 3. Check Firebase Console
# https://console.firebase.google.com → Crashlytics
```

### View dSYMs on your machine
```bash
# After building, dSYMs are stored at:
~/Library/Developer/Xcode/Archives/[date]/UFree.xcarchive/dSYMs/

# Verify they exist:
ls -la ~/Library/Developer/Xcode/Archives/*/UFree.xcarchive/dSYMs/
```

---

**Date:** January 8, 2026 | **Version:** 1.0 (Crashlytics integrated, ready for real-world testing)
