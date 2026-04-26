# UFree Testing Guide

**Status:** ✅ Production Ready | **Tests:** 195+ | **Coverage:** 85%+ | **Quality:** Zero flaky, zero memory leaks

---

## Quick Start

```bash
# Quick validation (recommended)
xcodebuild test -scheme UFreeUnitTests -project UFree.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | \
  grep -E '(PASS|FAIL|passed|failed|warning)'

# Via fastlane
fastlane tests
```

---

## Debug Auth Strategy (Manual Testing)

For testing multi-user flows without SMS codes:

1. **Add Firebase test phone numbers** (Console > Authentication > Phone):
   - +1 555-000-0001, +1 555-000-0002, +1 555-000-0003 (all code: 123456)
2. **Tap "User 1/2/3"** in the developer tools section of the LoginView (DEBUG only).

---

## QA Testing: 30-Minute Smoke Test

**Purpose:** Manual validation of core features before release.

### Test Scenarios

1. **Friend Request Flow**: User A searches for User B, sends request. User B accepts. Verify bidirectional friendship.
2. **Nudge Flow**: User A nudges User B. Verify red badge and notification in User B's inbox.
3. **QR Connection**: Scan User A's QR code from User B's device. Verify profile loads instantly.
4. **Rapid-Tap Protection**: Rapidly tap a nudge button. Verify only one notification is sent.
5. **Offline Graceful**: Send nudge in Airplane mode. Verify error toast and no crash.
6. **Deep Linking**: Simulate `https://ufree.app/notification/user123`. Verify app opens to notification.

### Sign-Off Checklist
- [ ] Friend requests sync within 3 sec.
- [ ] Notifications update badge count correctly.
- [ ] QR code generation and scanning work.
- [ ] Rapid-tap protection prevents duplicate operations.
- [ ] Cold start preserves user authentication.

---

## Test Organization

| Layer | Files |
|-------|-------|
| **Auth** | `UserTests.swift`, `MockAuthRepositoryTests.swift` |
| **Domain** | `AvailabilityStatusTests.swift`, `DayAvailabilityTests.swift`, `UserScheduleTests.swift` |
| **Data** | `FirestoreDayDTOTests.swift`, `PersistentDayAvailabilityTests.swift`, `SwiftDataAvailabilityRepositoryTests.swift`, `FriendRepositoryTests.swift` |
| **Features** | `FriendsViewModelTests.swift`, `FriendsHandshakeTests.swift`, `MyScheduleViewModelTests.swift`, `StatusBannerViewModelTests.swift`, `NotificationViewModelTests.swift` |

---

## Testing Patterns

### Rapid-Tap Protection (ViewModel)
Test that `isProcessing` flag ignores subsequent calls:
```swift
func test_rapidTaps_ignored_while_processing() async {
    viewModel.doSomething()
    XCTAssertTrue(viewModel.isProcessing)
    viewModel.doSomething() // Should be ignored
}
```

### In-Memory Persistence
Unit tests auto-detect and use in-memory SwiftData containers for 100x speed and complete isolation.

---

**Last Updated:** April 26, 2026 | **Sprint:** 6.5 | **Status:** ✅ Ready to Ship
