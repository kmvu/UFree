# UFree sprint history

This is a compact record of completed milestones. It explains how the project arrived at the current product; for current behavior and operating instructions, use the [documentation hub](README.md).

| Sprint | Milestone | Lasting outcome |
|---|---|---|
| 1 | Core availability | Domain models, schedule editing, and initial test foundation |
| 2 | Local persistence | SwiftData storage and normalized availability records |
| 2.5 | Authentication and navigation | Firebase authentication, root flow, and app navigation |
| 3 | Cloud synchronization | Offline-first composite repository with local writes and background Firestore sync |
| 4 | Friend discovery | Hashed contact matching, private phone lookup, QR connections, and mutual requests |
| 5–5.1 | Notification center and nudges | In-app notifications, friend-request actions, nudges, and rapid-tap protection |
| 6–6.5 | Production foundations | Universal links, analytics, Crashlytics integration, availability heatmap, and batch nudging |
| 7–8 | Reliability and test maturity | Deterministic async testing, test helpers, concurrency hardening, and broader rendering coverage |
| 9 | Dyad retention loop | Pair-first onboarding, partial availability truth, day-specific nudge replies, and TestFlight pilot focus |

## Key decisions that still apply

- **Offline first:** record availability locally before synchronizing it with Firestore.
- **Private by default:** friend visibility starts only after a mutual connection.
- **Testable boundaries:** repository protocols and injected dependencies make Firebase-independent tests possible.
- **Reliable interaction:** user-triggered async work must prevent accidental duplicate actions.
- **Pilot before expansion:** prove repeat weekend use with friend pairs before adding group chat, shared calendars, or calendar import.

## Historical notes

- Push registration and Cloud Function code were explored, but Functions are intentionally not deployed in the present Spark-tier TestFlight pilot.
- Earlier documentation included detailed implementation snapshots, old test counts, and setup instructions. Those living instructions now reside in the engineering, testing, and operations guides to prevent history from becoming a second source of truth.

**Last reviewed:** August 1, 2026
