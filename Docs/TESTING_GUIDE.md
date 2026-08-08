# UFree testing guide

Use this guide for automated validation, two-person checks, and release sign-off. For the purpose and success criteria of the TestFlight pilot, read the [product overview](PRODUCT_OVERVIEW.md); for release steps, use the [operations guide](OPERATIONS_GUIDE.md).

**Current inventory:** 534 test methods are present under `UFreeTests/`. Coverage must be measured from a fresh result bundle; do not treat an old percentage as a release gate.

---

## 1. 🤖 Automated Unit Tests (CI/CD)

Tests use mocks and in-memory SwiftData for deterministic coverage without requiring a live Firebase project. View-model tests should use the shared memory-leak tracking helper.

### Deterministic Async Testing
We use a **Zero-Sleep Protocol**:
- **Injectable Schedulers**: Use `TaskScheduler` to inject `ImmediateTaskScheduler` in tests for instant completion of delayed actions.
- **Awaitable Tasks**: ViewModels return `@discardableResult Task` objects so tests can `await` their completion precisely.
- **Deterministic Stream Polling**: Use `Task.yield()` loops in tests to await `AsyncStream` emissions without fixed delays.

**Run all unit tests from terminal:**
```bash
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

**Via Fastlane (recommended):**
```bash
bundle exec fastlane tests
```

**Via Xcode:**
Press `⌘ + U` with the `UFreeUnitTests` scheme selected.

### Measuring Coverage

The `UFreeUnitTests` scheme measures coverage for the **`UFree.app` target only**. The test bundle itself is deliberately excluded, because including it inflates the blended number without telling you anything about production code.

```bash
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -resultBundlePath /tmp/UFreeCoverage.xcresult
xcrun xccov view --report --only-targets /tmp/UFreeCoverage.xcresult
```

For a per-file breakdown, add `--files-for-target UFree.app`.

### Testing SwiftUI Views

Most of the app's line count lives in view bodies, and SwiftUI is lazy: constructing a view value runs no `body` code at all. Views are therefore covered by attaching them to a real `UIWindow` and forcing layout, via two helpers:

- **`ViewHost`** (`UFreeTests/Helpers/ViewHost.swift`) renders a view in a visible window and forces layout passes. Use `renderAwaitingUpdates` when the view has `.task` or `.onAppear` work whose result should appear in a second body pass. For size-class branches, pass `ViewHost.regularPadSize` or `ViewHost.compactLandscapeSize` and override `.environment(\.horizontalSizeClass, …)` (and vertical size class when needed).
- **`TestScene`** (`UFreeTests/Helpers/TestScene.swift`) assembles the whole mock-backed ViewModel graph the way `RootView` does, because views read across each other — `MyScheduleView` reaches into `rootViewModel.friendsScheduleViewModel`, for instance.

Two things to know when writing these tests:

- **Prefer injecting a ViewModel over simulating a tap.** State that a view owns as `@StateObject` is otherwise only reachable through its buttons. `FriendsView` and `StatusBannerView` each expose an `init` taking a pre-built ViewModel for exactly this reason, which is how the status banner's expanded drawer gets covered.
- **Seed repositories before building a ViewModel that listens.** `NotificationViewModel` starts a listener in `init` and starts another whenever the scene activates — which hosting a view does. Assigning state onto the ViewModel after `init` races with the listener `init` already started, and either can win. `TestScene(notifications:)` exists for this.

Prefer `MainAppView` over `RootView` when testing the authenticated state: it takes every dependency by injection, whereas `RootView.init` constructs live Firebase repositories itself.

---

## 2. 📱 Manual Multi-User Testing (Firebase Test Users)

For testing social flows that require two real accounts without real SMS codes:

1. **Deploy Firestore rules + indexes** (required for invites / QR / accept):
   ```bash
   firebase deploy --only firestore:rules,firestore:indexes
   ```
   Without `friendRequests` rules, every invite fails with a permission error dialog.
2. **Use Developer Tools** in `LoginView` (DEBUG builds only):
   - Run the app on two simulators (or simulator + device).
   - Tap **User 1**, **User 2**, or **User 3**. Each uses anonymous Firebase Auth (same as Get Started) and saves a fixed phone hash (`+15550000001`…`03`) so you can Find by Phone across devices.
   - No Firebase Console “Phone numbers for testing” setup is required for these buttons.

### Three-platform real-time loop (iPhone + iPad + Mac)

Use this when you want **three different people** interacting at once. Mac runs as **Designed for iPad** (Debug already has `SUPPORTS_MAC_DESIGNED_FOR_IPAD = YES`). Mac Catalyst is deferred; see [ENGINEERING_GUIDE.md](ENGINEERING_GUIDE.md) Adaptive layout.

| Platform | Destination | DEBUG account |
|---|---|---|
| iPhone | Physical device or iPhone simulator | User 1 |
| iPad | Physical device or iPad simulator | User 2 |
| Mac | **My Mac (Designed for iPad)** | User 3 |

**Setup**

1. Complete the Firebase test-user prep above (rules/indexes + phone numbers).
2. In Xcode, select the `UFree` scheme (Debug).
3. Run three destinations, one at a time or with multiple run destinations if configured:
   - iPhone → tap **User 1**
   - iPad → tap **User 2**
   - Mac → destination **My Mac (Designed for iPad)** → tap **User 3**
4. One install = one auth session. Do not expect multiple Mac accounts from a single Mac window.

**Connect without relying on Mac camera**

Mac QR **scan** is soft-gated when no usable camera is available. Prefer:

- Phone search: User A finds User B by `+1555000000X`, or
- Invite / profile link: share `https://ufree.app/profile/{userId}`, or
- Show QR on Mac, scan from iPhone/iPad (scan direction toward a device with a camera).

Accept friend requests on each side until all three are connected (or the dyads you care about).

**Interact in real time**

1. Keep all three apps **foregrounded**. Background push is unavailable in the current pilot; in-app listeners need an active session.
2. Mark free days on My Schedule on each account.
3. Confirm **Who’s Free?** updates across devices.
4. Send a day-scoped nudge from one account; reply from another via the in-app notification center (bell).
5. On Mac/iPad regular width, expect sidebar + week matrix (same adaptive path as iPad).

**Quick checklist**

- [ ] User 1 / 2 / 3 each logged in on a different platform.
- [ ] At least one friend edge between each pair you intend to test (or a full triangle).
- [ ] Schedule changes appear on the other devices without relaunch.
- [ ] Nudge + reply works with all three apps open.
- [ ] Mac does not block the loop when QR scan is unavailable.

---

## Manual release smoke test

Run these manually before any release to validate end-to-end stability.

| # | Scenario | Steps | Expected Result |
|---|---|---|---|
| 1 | **Friend Request Flow** | User A searches User B by phone → sends request. User B accepts. | Both see each other in friend list within ~3s. |
| 2 | **Day-scoped Nudge** | Select a day chip → tap wave on User B (or Nudge All). | User B sees “Free {weekday}?” with I’m in / Maybe / Busy actions. |
| 3 | **Nudge Reply** | User B taps I’m in. | User A inbox shows “B is in for {weekday}”; B’s day marked free. |
| 3b | **Batch Nudge** | Select day with 2+ free friends (incl. afternoon-only) → nudge all. | Success toast shows count. Partials are included. |
| 4 | **QR Connection** | Open QR code on B. Scan from A. | A sees B's profile instantly with friend request button. |
| 5 | **Rapid-Tap Guard** | Rapidly tap any nudge or request button. | Only **one** request sent; button disables while processing. |
| 6 | **Offline Mode** | Airplane mode → try to send nudge. | Error toast shown. No crash. |
| 7 | **Heatmap Badges** | Check Friends Schedule day filters. | Badge counts correctly reflect number of "free" friends. |
| 8 | **Deep Linking** | Visit `https://ufree.app/profile/{userId}` in Safari. | App opens to specific user's card. |
| 9 | **Cold Start** | Force-quit app → reopen. | User stays logged in. Local data loads from SwiftData cache. |
| 10 | **Notification Bell** | Tap bell after receiving nudge. | Inbox opens; unread count resets to 0. |
| 11 | **Large screen** | Run on iPad (or iPhone landscape). | Sidebar on regular width; Who’s Free uses a week matrix; status banner doesn’t crowd the schedule. |

---

## 4. 📂 Test Organization

### Test Files by Layer

| Layer | Primary Test Files |
|---|---|
| **Auth** | `RootViewModelTests.swift`, `RootViewModelAuthPhaseTests.swift`, `MockAuthRepositoryTests.swift`, `UserTests.swift` |
| **Domain** | `AvailabilityStatusTests.swift`, `DayAvailabilityTests.swift`, `UserScheduleTests.swift`, `UpdateMyStatusUseCaseTests.swift` |
| **Data** | `FirestoreDayDTOTests.swift`, `SwiftDataAvailabilityRepositoryTests.swift`, `PersistentDayAvailabilityTests.swift`, `FriendRepositoryTests.swift`, `FirebaseAvailabilityRepositoryTests.swift`, `CompositeAvailabilityRepositoryTests.swift` |
| **Features** | `FriendsViewModelTests.swift`, `FriendsHandshakeTests.swift`, `MyScheduleViewModelTests.swift`, `MyScheduleViewModelLoadTests.swift`, `FriendsScheduleViewModelTests.swift`, `NotificationViewModelTests.swift`, `NotificationCenterViewTests.swift`, `DayFilterViewModelTests.swift`, `StatusBannerViewModelTests.swift` |
| **Hardening** | `FriendsScheduleViewModelBatchNudgeTests.swift` (Concurrency/Race Conditions) |
| **Utilities** | `CryptoUtilsTests.swift`, `CryptoUtilsPhoneHashesTests.swift`, `Color+HexTests.swift` |

### Shared Test Helpers (`UFreeTests/Helpers/`)

| Helper | Purpose |
|---|---|
| `XCTestCase+MemoryLeakTracking` | `trackForMemoryLeaks()` called in `setUp()` of all ViewModel tests |
| `TestContainerFactory` | Creates in-memory `ModelContainer` for SwiftData tests |
| `Helpers/Notifications/TestNotificationBuilder` | Factory for `AppNotification` instances with sensible defaults |
| `Helpers/Notifications/NotificationTestAssertions` | Assertion helpers for friend request and nudge messages |

---

## 5. 👥 Two-Person Pilot Smoke

Run this with two TestFlight users or two debug simulators before recruiting pilot participants:

1. A shares a link or QR code; B sends or accepts the connection request.
2. Both mark a weekend day free.
3. Confirm **Who’s Free?** shows the other person, including partial availability.
4. A sends a day-specific nudge; B replies **I’m in**.
5. Confirm A sees the reply in the in-app notification center.

For the actual recruiting, success threshold, and foreground-only limitation, use [Operations guide → TestFlight dyad pilot](OPERATIONS_GUIDE.md#testflight-dyad-pilot).

---

## 6. ✅ Sign-Off Checklist

- [ ] All unit tests pass (`UFreeUnitTests` scheme).
- [ ] Friend requests sync across accounts under 3s.
- [ ] Notification badges clear correctly on read.
- [ ] QR code scanning works between devices.
- [ ] Rapid-tap protection prevents duplicate nudges.
- [ ] Cold start preserves user authentication.
- [ ] App remains stable in Airplane mode.
- [ ] Two-person pilot smoke passes when a social flow changed.
- [ ] Three-platform loop (iPhone + iPad + Mac Designed for iPad) when cross-device social behavior changed.
- [ ] Large-screen smoke (row 11) when layout or navigation chrome changed.
- [ ] The TestFlight release checklist in the operations guide is complete.

---

**Last reviewed:** August 8, 2026