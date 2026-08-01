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
- [x] **UI Callbacks**: Audit all `observeIncomingRequests` implementations to ensure data processing and UI updates are explicitly isolated to the `@MainActor`.
- [x] **Background Tasks**: Verify that intensive operations (like contact hashing) are performed on background threads but report results back to the main thread.

## 4. APNs Roadmap & Quota Resilience

This section outlines the strategy for implementing background notifications and maintaining service stability during viral spikes or quota exhaustion.

### Phase 1: APNs Implementation (Sprint 6.1)
- [x] **FCM Bridge Implementation**: Update `AppDelegate` to handle remote registration and broadcast tokens.
- [x] **The Hybrid Listener Strategy**: Refactor `NotificationViewModel` to detach Firestore listeners the moment the app enters the background.
- [x] **Security-First Payloads**: Ensure push payloads use generic messages (e.g., "👋 Someone sent you a Nudge!") to maintain the privacy-first architecture.
- [x] **Contextual Permissions**: Only trigger the APNs permission prompt after a successful friend handshake or sending a first Nudge.

### Phase 2: Quota Resilience (Bonus Improvements)
- [x] **Friend Discovery Quota Exhaustion**:
    - *Risk*: Intensive contact-sync reads (50k/day free tier) could be exhausted.
    - *Backup*: If Firestore rejects reads due to quota, gracefully disable Contact Sync and fall back to "The In-Person Handshake" (QR codes and Universal Links).
- [x] **Batch Nudging Overload Protection**:
    - *Risk*: Parallel nudges to 10+ friends could trigger Cloud Function or write limits.
    - *Backup*: Harden `FriendsScheduleViewModel` with rate-limiting, tactile warnings via `HapticManager`, and clear success/failure reporting with optimistic state rollbacks.

## 5. Test Suite Optimization & Determinism (Sprint 7.0)

To ensure rapid development cycles and 100% CI reliability, the test suite was overhauled to eliminate non-deterministic waits and fill critical architecture gaps.

### Key Improvements:
- **Zero Task.sleep Strategy**: Eliminated 3.5s+ of hardcoded delays by introducing injectable schedulers and awaitable ViewModel tasks.
- **TaskScheduler Utility**: Abstracted `asyncAfter` into a protocol-based system.
- **Data Sync Validation**: Added `CompositeAvailabilityRepositoryTests` to verify the Write-Through/Read-Back pattern.
- **Privacy Hashing Verification**: Comprehensive coverage for `CryptoUtils.phoneNumberHashes` across E.164 and local formats.
- **Quota Resilience Testing**: Explicitly tested Firestore error code 8 (Quota Exhausted) handling in `MyScheduleViewModel`.

## 6. Test Suite Consistency & Documentation (Sprint 8.0)

- **Helper Consolidation**: Unified scattered test helpers into `UFreeTests/Helpers/` with subdirectory for notification builders and assertions.
- **Memory Leak Tracking**: Adopted `trackForMemoryLeaks()` across all ViewModel tests (`FriendsViewModelTests`, `NotificationViewModelTests`, `StatusBannerViewModelTests`, `DayFilterViewModelTests`).
- **Dead Code Removal**: Removed unused `XCTestCase+TestHelpers.swift` (`anyNSError`) and `HTTPClientStub.swift`.
- **Comment Consistency**: Stripped explicit Arrange-Act-Assert label comments in favor of natural AAA structure.
- **setUp() Normalization**: Standardized all `setUp()` methods to synchronous form.
- **Documentation Refresh**: Updated `AGENTS.md`, `TESTING_GUIDE.md`, `README.md`, and `IMPROVEMENTS.md` with accurate test counts (230+), scheme names, and helper organization.

## 7. MVP Dyad Retention Loop (Sprint 9.0)

Product-loop hardening for launch readiness (not more social features):

- [x] Heatmap counts partial free windows; unset days are Unknown
- [x] Who’s Free default home; share-first Friends; pair checklist
- [x] Day-scoped nudge + I’m in / Maybe / Busy replies
- [x] Retention analytics funnel (+ weekend digest CF code kept undeployed — Spark/no billing)
- [ ] Founder-seeded TestFlight dyads prove uncoached weekend loop

**Deferred until dyad retention:** Group Chat, Shared Calendars, EventKit.

---
*Note: This plan was updated on 2026-08-01 for the MVP workflow execution sprint.*
