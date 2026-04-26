# UFree - Weekly Availability Scheduler

**Status:** ✅ Production Ready | **Version:** 6.5.0 | **Tests:** 195+ | **Coverage:** 85%+

---

## Documentation Quick Links

| I want to... | Go to... |
|---|---|
| **Setup & Standards** | `AGENTS.md` |
| **Architecture** | This file → Architecture |
| **Troubleshooting** | `TROUBLESHOOTING_RUNBOOK.md` |
| **Testing & QA** | `TESTING_GUIDE.md` |
| **History** | `SPRINT_HISTORY.md` |

---

## The Frictionless Handshake (Social Strategy)

UFree uses a privacy-first connection model called **The Frictionless Handshake**:
1.  **Just-In-Time Discovery**: Securely hash your contacts locally to find friends already on the app without exposing raw numbers.
2.  **The In-Person Handshake**: Instantly connect by scanning a friend's personal QR code.
3.  **Mutual Consent**: No schedule data is shared until both parties explicitly accept the connection request.
4.  **Trust Indicators**: Reassuring badges ("✓ In your contacts") help verify identities before connecting.

---

## Core Architecture

**Data Flow (Offline-First):**
```
UI → ViewModel → CompositeRepository → SwiftData [instant]
                       ↓ (background)
                    Firestore [sync, non-blocking]
```

**Key Layers:**
- **Domain**: Pure business logic and models (`DayAvailability`, `UserSchedule`).
- **Data**: Repositories handling SwiftData (local) and Firestore (cloud) sync.
- **Presentation**: ViewModels marked with `@MainActor` with rapid-tap protection.
- **UI**: 100% SwiftUI with consistent haptic feedback.

---

## Quick Reference: Features

- ✅ **Offline-First**: Instant local updates with background cloud sync.
- ✅ **Privacy Discovery**: Hash-based contact matching + QR scanning.
- ✅ **Handshake Protocol**: Mutual consent enforced via real-time listeners.
- ✅ **Nudge Feature**: Real-time engagement with haptic feedback.
- ✅ **Availability Heatmap**: Visual summary of "Who's free on..." any given day.
- ✅ **Universal Links**: Deep linking to notifications and profiles.

---

## Technical Highlights

- **@MainActor Isolation**: Guaranteed thread safety for UI updates.
- **AsyncStream**: Reactive state management without the overhead of Combine.
- **HapticManager**: Unified tactile feedback across all primary interactions.
- **Zero Warnings**: Clean build with 195+ automated unit tests.

---

**Last Updated:** April 26, 2026 | **Sprint:** 6.5 | **Status:** ✅ Production Ready
