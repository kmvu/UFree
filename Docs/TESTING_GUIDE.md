# UFree Testing Guide

**Status:** ✅ Production Ready | **Tests:** 519 | **Coverage:** 85.78% of the `UFree.app` target | **Quality:** Zero-Sleep Deterministic

---

## 1. 🤖 Automated Unit Tests (CI/CD)

**519 tests, zero Firebase dependency**. Tests use `MockAuthRepository` + in-memory SwiftData. All ViewModel tests include `trackForMemoryLeaks()` in `setUp()`.

### Deterministic Async Testing
We use a **Zero-Sleep Protocol**:
- **Injectable Schedulers**: Use `TaskScheduler` to inject `ImmediateTaskScheduler` in tests for instant completion of delayed actions.
- **Awaitable Tasks**: ViewModels return `@discardableResult Task` objects so tests can `await` their completion precisely.
- **Deterministic Stream Polling**: Use `Task.yield()` loops in tests to await `AsyncStream` emissions without fixed delays.

**Run all unit tests from terminal (Fast - No Simulator):**
```bash
xcodebuild test \
  -scheme UFreeUnitTests \
  -project UFree.xcodeproj \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E '(PASS|FAIL|passed|failed|error)'
```

**Via fastlane (Recommended - No Simulator):**
```bash
fastlane tests
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

- **`ViewHost`** (`UFreeTests/Helpers/ViewHost.swift`) renders a view in a visible window and forces layout passes. Use `renderAwaitingUpdates` when the view has `.task` or `.onAppear` work whose result should appear in a second body pass.
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
2. **Add Firebase test phone numbers** (Firebase Console > Authentication > Phone):
   - `+1 555-000-0001`, `+1 555-000-0002`, `+1 555-000-0003` (All code: `123456`)
3. **Use Developer Tools** in `LoginView` (DEBUG builds only):
   - Run the app on two simulators (or simulator + device).
   - Tap "User 1", "User 2", or "User 3" to bypass SMS auth and login instantly.

---

## 3. 🔥 30-Minute Smoke Test (Core Flows)

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

## 5. 👥 Dyad Smoke (MVP Launch Gate)

Run with two TestFlight (or DEBUG dual-simulator) users who already know each other (no coaching mid-flow).

**Cost note:** Stay on Spark. Do not deploy Cloud Functions. Expect **in-app inbox** updates while the app is open; background push and weekend digest cron are unavailable until Blaze is accepted.

1. A invites B via Share Link or QR (Friends tab shows My Code first).
2. B accepts (Friends or Notification Center).
3. Both mark weekend free (prompt or Schedule taps).
4. Who’s Free shows each other as available (partial free counts).
5. A sends a day-scoped nudge; B replies I’m in.
6. A sees the reply reward in Notification Center (keep both apps foregrounded for Spark).
7. Both reopen the following Friday without founder ping (or with a light founder SMS if needed).

**Ready bar:** ≥50% of seeded dyads complete steps 1–6 in one weekend and reopen next Friday.

See also: `Docs/TESTFLIGHT_DYAD_LAUNCH.md`

---

## 6. ✅ Sign-Off Checklist

- [ ] All unit tests pass (`UFreeUnitTests` scheme).
- [ ] Friend requests sync across accounts under 3s.
- [ ] Notification badges clear correctly on read.
- [ ] QR code scanning works between devices.
- [ ] Rapid-tap protection prevents duplicate nudges.
- [ ] Cold start preserves user authentication.
- [ ] App remains stable in Airplane mode.
- [ ] Dyad smoke passes for 2–3 seeded pairs.

---

**Last Updated:** August 1, 2026 | **Sprint:** 9.0 | **Status:** ✅ MVP workflow ready for TestFlight dyads