# Strengthening UFree: Concurrency and Architectural Reliability Protocols

This document outlines the strategic plan for hardening the UFree iOS application's concurrency handling, testing protocols, and architectural reliability, as derived from the "Hardening UFree iOS Concurrency and Testing Protocols" audit.

## 1. Rapid-Tap Protection (isProcessing Guard)

All interactive components must prevent rapid-tap edge cases to avoid duplicate network requests or inconsistent UI states.

### Audit Checklist:
- [ ] **FriendsViewModel**: 
    - `findFriendsInContacts()`: Prevent multiple simultaneous contact-hashing background tasks.
    - `acceptFriendRequest()` / `declineFriendRequest()`: Guard against multiple taps on the deep-link bottom sheet.
- [ ] **QR Scanner UI**:
    - `processScannedCode()`: Prevent firing multiple friend request handshakes if a code is detected multiple times in rapid succession.
- [ ] **NotificationCenterView**:
    - `markAsRead()`: Ensure single-action processing for individual and batch operations.

### Standard Implementation:
```swift
@MainActor
func handleAction() async {
    guard !isProcessing else { return }
    isProcessing = true
    defer { isProcessing = false }
    
    // Perform async work
}
```

## 2. Concurrency & Parallel Execution Testing

The codebase utilizes parallel execution for performance (e.g., Batch Nudging). These must be covered by rigorous unit tests.

### Test Requirements:
- [ ] **Batch Nudging Race Conditions**:
    - Write tests in `FriendsScheduleViewModelTests` that trigger parallel nudges to 10+ friends simultaneously and assert UI stability.
- [ ] **Firebase Rate-Limit Simulation**:
    - Simulate `NotificationRepository` errors (e.g., status 429) during batch operations and verify that the ViewModel correctly identifies which nudges failed.
- [ ] **State Rollbacks**:
    - Ensure that if a network request fails, the local UI state (optimistic updates) is reverted to the previous known-good state without flickering.

## 3. Thread Safety & @MainActor Isolation

With the heavy use of `AsyncStream` for real-time listeners, we must guarantee thread safety.

### Protocols:
- [ ] **UI Callbacks**: Audit all `observeIncomingRequests` implementations to ensure data processing and UI updates are explicitly isolated to the `@MainActor`.
- [ ] **Background Tasks**: Verify that intensive operations (like contact hashing) are performed on background threads but report results back to the main thread.

## 4. APNs Roadmap (Background Reliability)

Currently, real-time listeners only function when the app is foregrounded. This creates an "Active-App Inconvenience."

### Next Steps:
- [ ] **Decouple Listeners**: Refactor `NotificationRepository` to allow for a hybrid approach (Foreground Listeners + Background Push Notifications).
- [ ] **Deep-Link Integration**: Ensure that clicking a push notification correctly triggers the deep-link flow for friend requests even if the app was terminated.
- [ ] **Infrastructure Setup**: Prepare the `AppDelegate` or `AppScene` for APNs registration (to be implemented in a future sprint).

---
*Note: This plan was generated on 2026-04-27 based on the UFree Architectural Audit.*
