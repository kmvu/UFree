# UFree Testing Guide

**Status:** ✅ Production Ready | **Tests:** 250+ | **Coverage:** 88%+ | **Quality:** 100% Deterministic | **Performance:** ~3.5s saved

---

## 1. 🤖 Automated Unit Tests (CI/CD)

This is your fastest validation layer — **250+ tests, zero Firebase dependency**. Tests are **100% deterministic** (no `Task.sleep`) and use `MockAuthRepository` + in-memory SwiftData.

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

---

## 2. 📱 Manual Multi-User Testing (Firebase Test Users)

For testing social flows that require two real accounts without real SMS codes:

1. **Add Firebase test phone numbers** (Firebase Console > Authentication > Phone):
   - `+1 555-000-0001`, `+1 555-000-0002`, `+1 555-000-0003` (All code: `123456`)
2. **Use Developer Tools** in `LoginView` (DEBUG builds only):
   - Run the app on two simulators (or simulator + device).
   - Tap "User 1", "User 2", or "User 3" to bypass SMS auth and login instantly.

---

## 3. 🔥 30-Minute Smoke Test (Core Flows)

Run these manually before any release to validate end-to-end stability.

| # | Scenario | Steps | Expected Result |
|---|---|---|---|
| 1 | **Friend Request Flow** | User A searches User B by phone → sends request. User B accepts. | Both see each other in friend list within ~3s. |
| 2 | **Nudge Flow** | User A taps wave icon on User B's card in Friends Schedule tab. | User B sees red badge and nudge in Notification Center. |
| 3 | **Batch Nudge** | Select day with 2+ free friends → tap "Nudge all X friends". | Success toast shows count. Each friend receives notification. |
| 4 | **QR Connection** | Open QR code on B. Scan from A. | A sees B's profile instantly with friend request button. |
| 5 | **Rapid-Tap Guard** | Rapidly tap any nudge or request button. | Only **one** request sent; button disables while processing. |
| 6 | **Offline Mode** | Airplane mode → try to send nudge. | Error toast shown. No crash. |
| 7 | **Heatmap Badges** | Check Friends Schedule day filters. | Badge counts correctly reflect number of "free" friends. |
| 8 | **Deep Linking** | Visit `https://ufree.app/profile/{userId}` in Safari. | App opens to specific user's card. |
| 9 | **Cold Start** | Force-quit app → reopen. | User stays logged in. Local data loads from SwiftData cache. |
| 10 | **Notification Bell** | Tap bell after receiving nudge. | Inbox opens; unread count resets to 0. |

---

## 4. 📂 Test Organization

| Layer | Primary Test Files |
|---|---|
| **Auth** | `RootViewModelTests.swift`, `MockAuthRepositoryTests.swift` |
| **Domain** | `AvailabilityStatusTests.swift`, `DayAvailabilityTests.swift`, `UserScheduleTests.swift` |
| **Data** | `FirestoreDayDTOTests.swift`, `SwiftDataAvailabilityRepositoryTests.swift`, `FriendRepositoryTests.swift` |
| **Features** | `FriendsViewModelTests.swift`, `FriendsHandshakeTests.swift`, `MyScheduleViewModelTests.swift`, `FriendsScheduleViewModelTests.swift`, `NotificationViewModelTests.swift` |
| **Hardening** | `FriendsScheduleViewModelBatchNudgeTests.swift` (Concurrency/Race Conditions) |

---

## 5. ✅ Sign-Off Checklist

- [ ] All unit tests pass (`UFreeUnitTests` scheme).
- [ ] Friend requests sync across accounts under 3s.
- [ ] Notification badges clear correctly on read.
- [ ] QR code scanning works between devices.
- [ ] Rapid-tap protection prevents duplicate nudges.
- [ ] Cold start preserves user authentication.
- [ ] App remains stable in Airplane mode.

---

**Last Updated:** June 28, 2026 | **Sprint:** 7.0 | **Status:** ✅ Ready to Ship
