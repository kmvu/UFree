# Pre-Launch Smoke Test Checklist

**Status:** Ready for Testing ✅ | **Time:** 30 minutes (two devices or simulators)

---

## Quick Summary

| Feature | Status | Notes |
|---------|--------|-------|
| Send/Receive/Accept friend requests | ✅ | Atomic batch write in Firestore |
| Nudge action + haptics | ✅ | Rapid-tap protected, < 2 sec delivery |
| Notification center + badge | ✅ | Real-time listener, shows count |
| Mark as read + styling | ✅ | Background changes, badge decreases |
| Deep link navigation | ✅ | Tap notification shows chevron, ready for implementation |
| Cold start (login persist) | ✅ | Firebase local session cache |
| Offline graceful degradation | ✅ | Error handling, no crashes |

---

## Setup (One-Time, 5 min)

1. Add Firebase test phone numbers (Console > Authentication > Phone):
   - +1 555-000-0001 (code: 123456)
   - +1 555-000-0002 (code: 123456)
   - +1 555-000-0003 (code: 123456)

2. Run app in DEBUG mode:
   - LoginView shows "DEVELOPER TOOLS" overlay with User 1/2/3 buttons
   - Each button logs in instantly (no SMS required)

---

## Test Scenarios (Two Simulators or Devices)

### Scenario 1: Friend Request Flow (5 min)

**User A → Sends Request:**
1. Search for User B by phone
2. Tap "Add Friend" → `sendFriendRequest()` fires
3. Check Firestore: `friendRequests/{requestId}` with `status="pending"`

**User B → Receives & Accepts:**
1. Open app → Real-time listener shows incoming request
2. Tap "Accept" → Atomic batch write:
   - Request marked "accepted"
   - Both users' `friendIds` arrays updated
3. Verify both appear in each other's friend list immediately

**Expected:** Both users see friendship within 2 seconds, no refresh needed.

---

### Scenario 2: Nudge Flow (5 min)

**User A → Sends Nudge:**
1. Open FriendsScheduleView
2. Tap "Nudge" on User B
3. Feel haptic feedback (3 light pulses)
4. Check Firestore: `users/{UserB}/notifications/{noteId}` created

**User B → Receives Nudge:**
1. Red badge appears on bell icon with count
2. Tap bell → NotificationCenterView shows nudge
3. Message: "[User A] nudged you! 👋" (orange hand icon)
4. Notification auto-marks as read when view appears
5. Badge count decreases

**Expected:** Nudge appears within 2 seconds, haptics consistent.

---

### Scenario 3: Rapid-Tap Protection (3 min)

**Test:** Send nudge, then tap 5+ more times during flight
- Expected: Only 1 notification in Firestore
- Badge shows 1, not 6
- No duplicates created

---

### Scenario 4: Cold Start (3 min)

1. Log in, add friend, send nudge
2. Close app completely (swipe from app switcher)
3. Reopen
4. Expected: User logged in, friends visible, nudge still in notification center
5. No data lost

---

### Scenario 5: Offline Graceful (3 min)

1. Enable airplane mode
2. Try to send nudge
3. Expected: Error toast, app doesn't crash
4. Turn airplane mode off, retry → Succeeds

---

### Scenario 6: Universal Links / Deep Linking (2 min)

**Prerequisites:** AASA file deployed to `https://ufree.app/.well-known/apple-app-site-association`

**Test 1: Simulate Deep Link (Local)**
1. Xcode: Simulate URL in console:
   ```swift
   let url = URL(string: "https://ufree.app/notification/user123")!
   UIApplication.shared.open(url)
   ```
2. Expected: App opens, `NotificationViewModel.highlightedSenderId` = "user123"
3. Can highlight the notification in UI

**Test 2: Physical Device (24-48 hrs after AASA deployed)**
1. Open Notes app → Type link: `https://ufree.app/notification/abc123`
2. Tap link
3. Expected: App opens (not Safari), notification highlighted
4. Repeat with `https://ufree.app/profile/xyz789`

---

## Firestore Structure Verification

Before testing, verify these collections exist:

```
users/{userId}
  └── notifications/{noteId}
        ├── recipientId: string
        ├── senderId: string
        ├── senderName: string
        ├── type: "nudge" | "friendRequest"
        ├── date: timestamp
        └── isRead: boolean

friendRequests/{requestId}
  ├── fromId: string
  ├── fromName: string
  ├── toId: string
  ├── status: "pending" | "accepted" | "declined"
  └── timestamp: timestamp

users/{userId}
  └── friendIds: [array of user IDs]
```

---

## Common Issues & Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| Friend request not appearing | Real-time listener not started | Check `listenToRequests()` called in `onAppear` |
| Nudge appears but no badge | Badge binding issue | Force-refresh notification center |
| Offline crashes | Network error not caught | Enable Firestore offline persistence in AppDelegate |
| Duplicate nudges sent | Rapid-tap not guarded | Verify `guard !isNudging` in ViewModel |

---

## Sign-Off Checklist

- [ ] Send request appears in Firestore within 2 sec
- [ ] Recipient sees request within 3 sec
- [ ] Accept creates bidirectional friendship atomically
- [ ] Nudge creates notification in recipient's collection
- [ ] Notification badge updates correctly
- [ ] Cold start preserves all data
- [ ] Offline doesn't crash
- [ ] Rapid-tap protection works
- [ ] Deep link navigation works (or ready for next sprint)

---

## After Smoke Test Passes

1. `fastlane tests` - Verify all 206+ tests pass
2. `fastlane beta` - Submit to TestFlight
3. Distribute link to external testers
4. Monitor Firebase Crashlytics + Analytics

---

**Last Updated:** January 29, 2026 | **Status:** Ready for Smoke Testing
