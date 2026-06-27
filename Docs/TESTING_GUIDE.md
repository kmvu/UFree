# UFree Testing Guide

**Status:** ✅ Production Ready | **Tests:** 245+ | **Coverage:** 85%+ | **Quality:** Zero flaky, zero memory leaks

---

## 1. 🤖 Automated Unit Tests (CI/CD)

This is your fastest validation layer — **245+ tests, zero Firebase dependency**. Tests auto-detect environment and use `MockAuthRepository` + in-memory SwiftData.

**Run all unit tests from terminal:**
```bash
xcodebuild test \
  -scheme UFreeUnitTests \
  -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E '(PASS|FAIL|passed|failed|error)'
```

**Via fastlane (recommended):**
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

**Last Updated:** June 27, 2026 | **Sprint:** 6.5 | **Status:** ✅ Ready to Ship
