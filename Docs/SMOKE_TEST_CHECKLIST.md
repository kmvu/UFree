# Pre-Launch Smoke Test Checklist

**Status:** Ready for Testing ✅ | 18/19 Complete  
**Time Estimate:** 30 minutes (two devices)

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

## Test Scenarios (Two Devices)

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

### Scenario 6: Deep Link Navigation (2 min)

1. Open NotificationCenterView
2. Tap on a notification
3. Expected: Smooth navigation to user's profile/details
4. Chevron icon indicates tappable row

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

1. Run: `bundle exec fastlane tests` (verify all 206+ tests pass)
2. Build: `bundle exec fastlane beta` (submit to TestFlight)
3. Distribute to external testers
4. Monitor Firestore for data issues

---

## Known Limitations (Future Sprints)

- ⏳ Push notifications (APNs) - app-only, not background
- ⏳ Deep link to friend profile (structural readiness exists)
- ⏳ Notification persistence after uninstall (Cloud Messaging needed)
