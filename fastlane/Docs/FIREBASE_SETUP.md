# Firebase Setup - Stability & Insights for Testing Phase

**Two essential telemetry layers: Crashlytics for stability, Analytics for insights.**

---

## The Firebase Strategy

### Crashlytics: "See What Breaks"
Without crash reporting: Friends say "the app crashed" but you don't know why
With Crashlytics: Instant readable stack traces with line numbers + device context

### Analytics: "See What Works"
Without analytics: You don't know if testers are actually using the app
With Analytics: Real-time data on feature usage and user behavior

Together: A complete picture of whether your app is stable **and** useful.

---

## Part 1: Firebase Crashlytics

### The Problem Crashlytics Solves

- ❌ Friends report "the app crashed" but you don't know why
- ❌ No stack trace to debug
- ❌ Can't see if crashes are device-specific (iPhone 13 vs iPhone 17 Pro)
- ❌ Can't identify if it's a network issue or concurrency bug

**With Crashlytics:**
- ✅ Instant crash notifications in Firebase Console
- ✅ Readable stack traces (dSYMs map memory addresses to code)
- ✅ Filter crashes by device model, iOS version, app version
- ✅ Identify patterns: "All crashes on iPhone 13 with iOS 17.1"
- ✅ Catch race conditions and network resilience bugs in the wild

### What Was Added

#### 1. UFreeApp.swift
```swift
import FirebaseCrashlytics

// In AppDelegate.application(_:didFinishLaunchingWithOptions:)
#if !DEBUG
Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
#endif
```

**Why?**
- Enables collection in Release builds (disables in Debug to avoid noise)
- Automatically captures crashes without additional code

#### 2. Fastfile (beta lane)
```ruby
build_app(
  include_symbols: true,      # Generate dSYM files
  include_bitcode: false      # Required for dSYM upload
)

upload_symbols_to_crashlytics(
  gsp_path: "GoogleService-Info.plist"
)
```

**Why?**
- `include_symbols: true` → Generates debug symbols (dSYM files)
- `upload_symbols_to_crashlytics` → Sends them to Firebase
- Firebase maps crash memory addresses to your actual code lines

#### 3. Xcode Build Phase Script (Manual Setup Required)

You must add a "Run Script" build phase to Xcode:

**Path:** UFree target → Build Phases → + → New Run Script Phase

**Name:** `Upload dSYMs to Firebase Crashlytics`

**Script:**
```bash
"${BUILD_DIR%Build/*}SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
```

**Settings:**
- ✅ Leave "Based on dependency analysis" **UNCHECKED** (runs every archive)
- ✅ Leave shell as `/bin/bash`
- ✅ Place AFTER "Compile Sources" but BEFORE "Link Binary with Libraries"

### How Crashlytics Works

**Local Development (Debug):**
```
fastlane alpha
  ↓
Builds with dSYMs but Crashlytics collection disabled
  ↓
Clean logs, no Firebase noise
```

**TestFlight Distribution (Release):**
```
fastlane beta
  ↓
Build step: Generates dSYMs
  ↓
Upload step: Sends dSYMs to Firebase Crashlytics
  ↓
Build uploaded to TestFlight
  ↓
When friends use the app, crashes auto-upload to Firebase
  ↓
You see them instantly in Firebase Console
```

**When a Friend's App Crashes:**
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

### Crashlytics Verification Steps

**1. Verify Crashlytics is initialized**
```bash
# Run app in simulator (Debug mode)
# Open Console.app → filter by "Crashlytics"
# You should see: "Crashlytics collection is disabled in Debug builds"
# ✅ This is correct (prevents debug noise)
```

**2. Test with Release build**
```bash
xcodebuild archive -scheme UFree -configuration Release

# dSYMs should be in:
# ~/Library/Developer/Xcode/Archives/[date]/UFree.xcarchive/dSYMs/
```

**3. Verify build phase script runs**
```bash
# Build in Xcode
# In build log, you should see:
# "Upload dSYMs to Firebase Crashlytics"
# If missing, add the build phase (see section above)
```

**4. Verify dSYMs upload in Fastfile**
```bash
fastlane beta

# In output, look for:
# "📤 Uploading dSYMs to Firebase Crashlytics..."
# "✅ Build uploaded to TestFlight with Crashlytics reporting enabled"
```

**5. Test crash reporting (Optional)**
Add a test crash button in your debug menu:

```swift
#if DEBUG
Button("Test Crash") {
    fatalError("Crashlytics Test Crash")
}
#endif
```

### Crashlytics in Firebase Console

**1. Enable Crashlytics**
- Go to [Firebase Console](https://console.firebase.google.com)
- Select UFree project
- Left menu → Crashlytics
- If not activated, click "Enable"

**2. View Crashes**
- **Crashes tab** → All crashes from all versions
- **Filter by:** Device, iOS version, app version

**3. Analyze a Crash**
- Click any crash
- See full stack trace with file names and line numbers
- Example:
  ```
  at ScheduleViewModel.fetchAvailability() [ScheduleViewModel.swift:142]
  at TaskGroup.addTask() [Concurrency.swift:78]
  ```

### Real-World Crashlytics Scenarios

**Scenario 1: Network Resilience**
```
Friend on LTE → WiFi transition
  ↓
Firestore write in progress
  ↓
Network switch causes timeout exception
  ↓
App crashes (Race condition in TaskGroup logic)
  ↓
Crashlytics captures:
  - "URLError: The network connection was lost"
  - Stack trace showing concurrent write
  - Device: iPhone 13 on iOS 17.1
  ↓
You see pattern: All crashes on LTE devices → Fix network resilience
```

**Scenario 2: Concurrency Bug**
```
Nudge batching with async/await
  ↓
Friend gets 50 nudges in 2 seconds
  ↓
TaskGroup processes concurrently
  ↓
Shared state access without synchronization
  ↓
App crashes (Swift Concurrency: Race Condition)
  ↓
Crashlytics shows:
  - Exact function and line number
  - Easy to reproduce: Send 50 nudges
  ↓
You add locks/isolation to fix it
```

**Scenario 3: Memory/Performance**
```
Heatmap view rendering
  ↓
10,000 friend locations on map
  ↓
Old devices run out of memory
  ↓
Crashlytics captures:
  - "Memory pressure"
  - Device: iPhone 11
  ↓
You optimize: Cluster pins, pagination, etc.
```

---

## Part 2: Firebase Analytics

### The Problem Analytics Solves

- ❌ You don't know if testers are actually using the app
- ❌ Can't see which features matter (nudge vs heatmap vs search)
- ❌ No data to guide next feature priorities
- ❌ "Is batch nudge working?" = Manual asking testers

**With Analytics:**
- ✅ See real usage patterns in Firebase Console
- ✅ Know exactly how many nudges were sent (single vs batch)
- ✅ Understand if phone search is being used
- ✅ Track availability status changes
- ✅ Data-driven decisions for next sprint

### What Was Added

#### 1. AnalyticsManager.swift
```swift
import FirebaseAnalytics

enum AnalyticsEvent {
    case nudgeSent(type: String)
    case friendRequestSent
    case searchPerformed(success: Bool)
    case availabilityUpdated(status: String)
    case heatmapViewed(friendCount: Int)
    case handshakeCompleted(duration: Int)
    case appLaunched
}

struct AnalyticsManager {
    static func log(_ event: AnalyticsEvent) { ... }
    static func setCollectionEnabled(_ enabled: Bool) { ... }
}
```

**Why?**
- Keeps ViewModels decoupled from Firebase SDK
- Centralized event tracking (easy to add/modify)
- Timestamps automatic with each event
- Type-safe event definitions

#### 2. UFreeApp.swift
```swift
import FirebaseAnalytics

// Enable collection in Release builds, disable in Debug
#if !DEBUG
Analytics.setAnalyticsCollectionEnabled(true)
#else
Analytics.setAnalyticsCollectionEnabled(false)
#endif

// Log app launch
AnalyticsManager.log(.appLaunched)
```

**Why?**
- Release/TestFlight: Analytics enabled (real user data)
- Debug: Analytics disabled (clean logs, no test noise)
- Auto-logs every app launch for user engagement metrics

### Key Success Actions to Track

#### 1. Nudge Sent (Core Metric)
```swift
// In your NudgeViewModel
func nudgeUser(_ friend: Friend) async {
    try await nudgeService.send(to: friend)
    AnalyticsManager.logNudgeSent(isBatch: false)
}

func nudgeAllAvailable(for date: Date) async {
    try await nudgeService.sendBatch(...)
    AnalyticsManager.logNudgeSent(isBatch: true)
}
```

**What you'll see:**
- Total nudges sent
- Ratio of single vs batch nudges
- Daily trends (Are nudges increasing?)

#### 2. Batch Nudge (Heatmap Feature Validation)
```swift
// In your HeatmapViewModel
func sendBatchNudge(recipients: [Friend]) async {
    try await nudgeService.sendBatch(recipients)
    AnalyticsManager.logBatchNudge(recipientCount: recipients.count)
}
```

**What you'll see:**
- How many batch nudges were sent
- Average recipients per batch
- If heatmap feature is being used at all

#### 3. Phone Search Success (Blind-Index Validation)
```swift
// In your SearchViewModel
func searchForFriend(_ phoneNumber: String) async {
    let found = await repository.findFriend(phoneNumber)
    AnalyticsManager.logPhoneSearchSuccess()
    return found
}
```

**What you'll see:**
- Total searches performed
- Success vs failure ratio
- User adoption of blind-index feature

#### 4. Availability Updates
```swift
// In your StatusViewModel
func updateStatus(_ newStatus: String) async {
    try await statusService.update(newStatus)
    AnalyticsManager.log(.availabilityUpdated(status: newStatus))
}
```

**What you'll see:**
- Status change frequency
- Which statuses are most popular (free vs busy vs offline)
- Engagement with availability feature

#### 5. Handshake Completion
```swift
// In your HandshakeViewModel
func completeHandshake(with friend: Friend, duration: TimeInterval) async {
    try await handshakeService.finalize(friend)
    AnalyticsManager.log(.handshakeCompleted(duration: Int(duration)))
}
```

**What you'll see:**
- Success rate of handshakes
- Average duration from request to completion
- If real-time sync is working

### Analytics in Firebase Console

**1. View Events**
- Go to [Firebase Console](https://console.firebase.google.com)
- Select UFree project
- Left menu → Analytics
- **Events tab** → See all tracked events

**2. Create Custom Dashboard**
- **Dashboard tab** → Create New Dashboard
- Add cards for:
  - "nudge_performed" (single vs batch split)
  - "phone_search" (found_match ratio)
  - "status_change" (status distribution)
  - "batch_nudge_sent" (adoption metric)

**3. View User Journeys**
- **Realtime** tab → See live events as testers use the app
- **Users** tab → See user demographics (device, OS version)
- **Cohorts** tab → Compare behavior patterns

**4. Filter Events**
- Click any event
- Filter by: Date range, user property, event parameter

### Testing Analytics During Development

**1. View Events in Console**
1. Run app on device/simulator
2. Trigger a nudge: `AnalyticsManager.logNudgeSent(isBatch: false)`
3. Go to Firebase Console → Analytics → Realtime
4. You should see the event appear within 5 seconds

**2. Verify Collection is Working**
```swift
// In your DebugView or Settings
Button("Test Analytics Event") {
    AnalyticsManager.log(.nudgeSent(type: "test"))
}
```

Run in Release mode, trigger button, check Firebase Console → Realtime.

### Common Analytics Implementation Patterns

**Pattern 1: Log After Success**
```swift
// Don't log until action is confirmed
func nudgeUser(_ friend: Friend) async {
    do {
        try await nudgeService.send(to: friend)
        AnalyticsManager.logNudgeSent(isBatch: false)
    } catch {
        print("Failed to send nudge: \(error)")
    }
}
```

**Pattern 2: Log with Context**
```swift
// Include relevant metadata
func updateStatus(_ status: String) async {
    let oldStatus = currentStatus
    try await updateService.setStatus(status)
    AnalyticsManager.log(.availabilityUpdated(status: status))
}
```

**Pattern 3: Log Completion Duration**
```swift
// Track how long actions take
let startTime = Date()
// ... perform handshake ...
let duration = Date().timeIntervalSince(startTime)
AnalyticsManager.log(.handshakeCompleted(duration: Int(duration)))
```

### What NOT to Track (Privacy & Security)

**Never track:**
- ❌ User names or phone numbers (privacy)
- ❌ Full addresses or exact locations (privacy)
- ❌ Payment info or authentication tokens (security)
- ❌ Device identifiers (IDFA) without consent (privacy)
- ❌ Health/medical information (compliance)

**Safe to track:**
- ✅ Feature usage (nudge sent, search performed)
- ✅ User counts (batch size, recipient count)
- ✅ Durations (handshake time)
- ✅ Success/failure (search found match or not)
- ✅ Status categories ("free", "busy", "offline")

### Real-World Analytics Scenarios

**Scenario 1: Validate Batch Nudge Feature**
```
Day 1: Deploy to TestFlight
  ↓
Firebase → Analytics → Realtime → Monitor "batch_nudge_sent"
  ↓
Friend opens app, sends batch nudge to 5 people
  ↓
You see event: batch_nudge_sent { recipient_count: 5 }
  ↓
"Batch nudge feature is working! ✅"
```

**Scenario 2: Measure Phone Search Adoption**
```
Deploy with phone search feature
  ↓
Monitor "phone_search" event in Firebase
  ↓
After 1 week of testing:
  - phone_search: 45 events
  - found_match: 40 success, 5 failures (89% success rate)
  ↓
"People ARE using blind-index search!"
```

**Scenario 3: Track Engagement Over Time**
```
Monday: nudge_performed { nudge_type: "batch" } × 12 events
Tuesday: nudge_performed { nudge_type: "batch" } × 18 events
Wednesday: nudge_performed { nudge_type: "batch" } × 25 events
  ↓
Graph shows increasing nudge sends
  ↓
"Engagement is growing. App is becoming useful! 🚀"
```

---

## Combined Troubleshooting

### Crashlytics Issues

| Issue | Fix |
|-------|-----|
| "dSYMs not found" | Ensure `include_symbols: true` in Fastfile |
| "Upload failed" | Check GoogleService-Info.plist exists in repo root |
| Build phase script not running | Verify "Based on dependency analysis" is **unchecked** |
| Crashes not appearing | Wait 5-10 minutes; reload Firebase Console; check app version |
| Script shows warning | OK if dSYMs upload succeeds (SDK not found on first check) |

### Analytics Issues

| Issue | Fix |
|-------|-----|
| "Events not appearing" | Wait 5-10 min; check internet; ensure Release build |
| "See only app_launched" | Call AnalyticsManager.log() in ViewModels |
| "Too many debug events" | Check UFreeApp.swift has `#if !DEBUG` |
| "Missing parameters" | Verify parameter types (string, int, double, long) |
| "Can't find Realtime" | Ensure you're in right Firebase project |

---

## Files Modified/Created

| File | Change | Purpose |
|------|--------|---------|
| `UFree/UFreeApp.swift` | Added Crashlytics + Analytics imports | Enable both services |
| `UFree/Core/Utilities/AnalyticsManager.swift` | Created | Centralized event tracking |
| `fastlane/Fastfile` | Added dSYM + upload logic | Automate crash symbol upload |
| `Scripts/upload_dsyms.sh` | Created | Build phase script template |
| `GoogleService-Info.plist` | Already exists | Connects to Firebase |

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
# After building, dSYMs stored at:
~/Library/Developer/Xcode/Archives/[date]/UFree.xcarchive/dSYMs/

# Verify they exist:
ls -la ~/Library/Developer/Xcode/Archives/*/UFree.xcarchive/dSYMs/
```

### Check if Analytics is working
```bash
# 1. Run app in Release mode
fastlane beta

# 2. Trigger an action (nudge, search, status update)
# AnalyticsManager.log() call fires

# 3. Check Firebase Console
# https://console.firebase.google.com → Analytics → Realtime
# Should see event within 5 seconds
```

---

## Next Steps

1. ✅ **Code is ready** - Crashlytics and Analytics initialized
2. 🔧 **Manual Xcode step** - Add Crashlytics build phase script (5 minutes)
3. 🔧 **Wire Analytics** - Add AnalyticsManager.log() calls to ViewModels (10 minutes)
4. 🚀 **Deploy** - Run `fastlane beta` to TestFlight
5. 📊 **Monitor** - Watch Firebase Console for crashes and user behavior

---

**Date:** January 8, 2026 | **Version:** 1.0 (Crashlytics + Analytics integrated, Testing Phase complete)
