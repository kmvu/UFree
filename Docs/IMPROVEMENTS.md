# Strengthening UFree: Concurrency and Architectural Reliability Protocols

This document outlines the strategic plan for hardening the UFree iOS application's concurrency handling, testing protocols, and architectural reliability, as derived from the "Hardening UFree iOS Concurrency and Testing Protocols" audit.

## 1. Rapid-Tap Protection (isProcessing Guard)

All interactive components must prevent rapid-tap edge cases to avoid duplicate network requests or inconsistent UI states.

### Audit Checklist:
- [x] **FriendsViewModel**: 
    - `findFriendsInContacts()`: Prevent multiple simultaneous contact-hashing background tasks.
    - `acceptFriendRequest()` / `declineFriendRequest()`: Guard against multiple taps on the deep-link bottom sheet.
- [x] **QR Scanner UI**:
    - `handleScannedCode()`: Prevent firing multiple friend request handshakes if a code is detected multiple times in rapid succession.
- [x] **NotificationCenterView**:
    - `markRead()`: Ensure single-action processing for individual operations.

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
- [x] **Batch Nudging Race Conditions**:
    - Write tests in `FriendsScheduleViewModelBatchNudgeTests` that trigger parallel nudges to 10+ friends simultaneously and assert UI stability.
- [x] **Firebase Rate-Limit Simulation**:
    - Simulate `NotificationRepository` errors (e.g., status 429) during batch operations and verify that the ViewModel correctly identifies which nudges failed.
- [x] **State Rollbacks**:
    - Ensure that if a network request fails, the local UI state (optimistic updates) is reverted to the previous known-good state without flickering.

## 3. Thread Safety & @MainActor Isolation

With the heavy use of `AsyncStream` for real-time listeners, we must guarantee thread safety.

### Protocols:
- [ ] **UI Callbacks**: Audit all `observeIncomingRequests` implementations to ensure data processing and UI updates are explicitly isolated to the `@MainActor`.
- [ ] **Background Tasks**: Verify that intensive operations (like contact hashing) are performed on background threads but report results back to the main thread.

## 4. APNs Roadmap & Quota Resilience

This section outlines the strategy for implementing background notifications and maintaining service stability during viral spikes or quota exhaustion.

### Phase 1: APNs Implementation (Sprint 6.1)
- [x] **FCM Bridge Implementation**: Update `AppDelegate` to handle remote registration and broadcast tokens.
- [x] **The Hybrid Listener Strategy**: Refactor `NotificationViewModel` to detach Firestore listeners the moment the app enters the background.
- [ ] **Security-First Payloads**: Ensure push payloads use generic messages (e.g., "👋 Someone sent you a Nudge!") to maintain the privacy-first architecture.
- [x] **Contextual Permissions**: Only trigger the APNs permission prompt after a successful friend handshake or sending a first Nudge.

### Phase 2: Quota Resilience (Bonus Improvements)
- [ ] **Friend Discovery Quota Exhaustion**:
    - *Risk*: Intensive contact-sync reads (50k/day free tier) could be exhausted.
    - *Backup*: If Firestore rejects reads due to quota, gracefully disable Contact Sync and fall back to "The In-Person Handshake" (QR codes and Universal Links).
- [ ] **Batch Nudging Overload Protection**:
    - *Risk*: Parallel nudges to 10+ friends could trigger Cloud Function or write limits.
    - *Backup*: Harden `FriendsScheduleViewModel` with rate-limiting, tactile warnings via `HapticManager`, and clear success/failure reporting with optimistic state rollbacks.

---
*Note: This plan was generated on 2026-04-27 based on the UFree Architectural Audit.*
