# UFree engineering guide

## Purpose

This guide explains the current technical shape of the app and the minimum setup needed to contribute safely. For short repository-specific rules, see [AGENTS.md](AGENTS.md). For release and TestFlight work, see the [operations guide](OPERATIONS_GUIDE.md).

## Architecture

UFree is a SwiftUI iOS application built around domain models, repository protocols, and view models. The app is offline-first:

```text
SwiftUI view → View model → Composite repository → SwiftData (immediate)
                                              └→ Firestore (background sync)
```

| Area | Location | Responsibility |
|---|---|---|
| Domain | `UFree/Core/Domain/` | Models, availability rules, and repository protocols |
| Data | `UFree/Core/Data/` | Firebase, SwiftData, contact, and mock repository implementations |
| App features | `UFree/Features/` | Root flow, schedule, friends, notifications, onboarding, and settings |
| Use cases | `UFree/Core/Architecture/UseCases/` | Feature-specific presentation and UI code |
| Shared utilities | `UFree/Core/Utilities/` | Analytics, crypto, haptics, onboarding state, and task scheduling |
| Tests | `UFreeTests/` | Unit, integration-style repository, and SwiftUI rendering tests |

### Key technical choices

- **SwiftUI and async/await:** UI work stays on `@MainActor`; asynchronous work uses Swift concurrency.
- **Protocol-based repositories:** production Firebase/SwiftData implementations can be replaced with mocks in tests.
- **Offline-first availability:** the composite repository writes locally first and synchronizes remotely without blocking the UI.
- **Real-time social updates:** Firestore listeners feed notifications and friend state into view models.
- **Deterministic tests:** injectable scheduling and awaitable tasks avoid timing-based sleeps.

## Local setup

Work through this once on a new machine (never commit the secrets):

- [ ] **Xcode 26.6** (pinned in CI/deploy; match local `xcodebuild -version`) with an **iOS 18+** Simulator (Fastlane targets **iPhone 17 Pro**)
- [ ] **Ruby** from tracked [`.ruby-version`](../.ruby-version) (`3.3.0`), then `bundle install` from the repo root
- [ ] **Java 21** for Firebase emulators (Temurin / Homebrew `openjdk@21`; scripts fall back to the repo-local `.jdk/`)
- [ ] **Node 22+** for Firestore rules tests (`npm --prefix firebase-tests ci`)
- [ ] `GoogleService-Info.plist` at the repo root (local only)
- [ ] [`.firebaserc`](../.firebaserc) pointing at the team project (`ufree-313a2`)
- [ ] For release work only: copy [`fastlane/.env.example`](../fastlane/.env.example) → `fastlane/.env` and fill values locally
- [ ] Register App Check debug tokens in Firebase Console when using Simulator (do not commit tokens)
- [ ] Keep the tracked `Package.resolved` under the Xcode workspace (do not delete it)

Verify the machine:

```bash
npm --prefix firebase-tests test    # Firestore rules (needs Java 21+)
bundle exec fastlane tests          # unit suite (iPhone 17 Pro + coverage)
bundle exec fastlane ui_tests       # UI happy path (UI_TESTING_MODE)
./Scripts/run_integration_tests.sh  # optional: Auth+Firestore emulator suite
```

See the [testing guide](TESTING_GUIDE.md) for focused test commands and what each suite covers.

### CI/CD map

This table is the canonical description of what runs when; other guides link here instead of restating jobs and triggers.

| Workflow | Jobs | When |
|---|---|---|
| `ci.yml` (Quality Check) | `firestore-rules` (ubuntu) · `unit-tests` (macos-26, Xcode 26.6) · `ui-tests` (macos-26, `UI_TESTING_MODE`) · `lint` (SwiftLint baseline) · `emulator-integration` (Auth+Firestore emulators; **main pushes** always, **PRs** when rules/data/integration paths change) | Push / PR to `main` |
| `deploy.yml` (TestFlight) | Requires green **push** `ci.yml` on the same SHA with named jobs Firestore Rules, Unit Tests, UI Tests, SwiftLint, Emulator Integration; `main` only; runs `fastlane beta` (tests always on) | Manual dispatch |
| `firebase-deploy.yml` | Rules tests → `firebase deploy --only firestore:rules,firestore:indexes,hosting` | Push to `main` when rules/indexes/`public/` change |

There is no `alpha` / Firebase App Distribution lane. TestFlight is the only distribution path.

Emulator ports (see `firebase.json`): Auth `127.0.0.1:9099`, Firestore `127.0.0.1:8080`. Integration scheme sets `UFREE_INTEGRATION_TESTS=1` so the app host points SDKs at those emulators.

### Signing and release credentials

Release work uses the untracked `fastlane/.env`, an App Store Connect `.p8` key, `MATCH_PASSWORD`, and certificate-repository SSH access. The canonical never-commit list is in [AGENTS.md](AGENTS.md#security); the CI secret names are in the [operations guide](OPERATIONS_GUIDE.md#security-and-access).

## Code conventions

Naming, `@MainActor`, rapid-tap guards, and test conventions live in [AGENTS.md](AGENTS.md#code-and-test-conventions). Additions that need context:

- Use SwiftUI; do not introduce UIKit unless the platform requires it.
- Prefer constructor injection and repository protocols for behavior that needs testing.
- Preserve local state or roll it back clearly when remote work fails.

## Adaptive layout

Adapt by **size class / available width**, not device idiom (`UFree/Core/UI/Adaptive/`):

- Compact → `TabView` + phone layouts; regular → `NavigationSplitView` + grids/matrices (Schedule, Who’s Free).
- Cap Schedule detail with `AdaptiveLayout.scheduleContentMaxWidth` so status/week cards don’t stretch edge-to-edge on iPad/Mac.
- Regular presentations use popovers and readable form width; compact uses sheets.
- Landscape: shorten chrome when `verticalSizeClass == .compact`. Gate camera/QR with `QRScannerCapability`.
- Mac today is Designed for iPad only (`SUPPORTS_MAC_DESIGNED_FOR_IPAD` in Debug); Catalyst is deferred and would reuse the same layouts. For a three-account iPhone + iPad + Mac loop, see [TESTING_GUIDE.md](TESTING_GUIDE.md#three-platform-real-time-loop-iphone--ipad--mac). Debug uses Automatic + Apple Development so My Mac can install; Release keeps Manual/`match AppStore` for TestFlight.
- Product CTAs: use `UFreePrimaryButtonStyle` / `UFreeSecondaryButtonStyle` / `UFreeCompactButtonStyle` and `UFreeType` (`Core/UI/Theme/`) for consistent padding, radius, and typography. Leave day chips / status banner on their own control language.

## First-hangout coach and post-connect flow

How the app guides a new pair from “connected” to a first real plan:

- A soft banner on Who’s Free opens an opt-in checklist sheet (`PairOnboardingBannerView` / `PairOnboardingChecklistView`). An empty Who’s Free shows the intention hero (`WhoIsFreeEmptyHeroView`) plus the banner — never a second checklist.
- **Not now** closes the sheet; **Don’t show again** persists via `OnboardingProgressStore.dismissPairChecklistPermanently()`.
- First invite and first free-day completions get a light haptic + toast, with no auto-presented sheet.
- Accepting a request (inbox or Add Friends) fires `FriendsViewModel.onAcceptCompleted` → `RootViewModel.handlePostAccept`.
- A first connection runs `celebrateFirstConnection` (named toast + haptic), then branches: Schedule + weekend CTA when the user still needs a free day, otherwise Who’s Free with `PostConnectMissionChipView` (the `OnboardingProgressStore` post-connect coach). Subsequent accepts always land on Who’s Free with a named toast.
- The mission chip clears on dismiss or on the first nudge. The friends list is observed, so the inviter celebrates without a manual refresh.

## Firebase, links, and observability

- Firestore rules and indexes are configured through `firebase.json`; the collection layout and access rules are diagrammed in [FIRESTORE_SCHEMA.md](FIRESTORE_SCHEMA.md).
- **Privacy model (Phase 1):** user profiles and availability are readable only by the owner and accepted friends. Phone/QR discovery uses get-only collections `publicProfiles/{uid}` and `phoneDirectory/{hash}` (list queries are denied). Friend-request docs use deterministic ids `{fromId}_{toId}`; peer `friendIds` self-add requires an accepted request in the same batch.
- **Identity (Phase 2):** production login is **Sign in with Apple**. Existing anonymous pilot sessions are linked via `link(with:)` so UIDs/friends are preserved. DEBUG simulator personas (User 1/2/3) still use anonymous Auth. Phone is an optional discovery hash only (first-writer-wins; OTP is a later phase).
- **Account deletion:** Settings → Delete Account re-authenticates with Apple, wipes the user's Firestore tree (availability, notifications, own friendRequests, phoneDirectory claims, publicProfiles, users doc), **removes this UID from peers’ `friendIds`**, deletes the Auth user, and clears local SwiftData / onboarding prefs. Rules allow owner/participant deletes and peer self-remove from `friendIds`.
- **App Check:** client uses App Attest (DeviceCheck fallback) in Release; DEBUG/Simulator use the App Check debug provider. Register the Xcode console debug token under Firebase Console → App Check → Manage debug tokens before enabling enforcement for Firestore.
- **Rules tests:** `firebase-tests/` runs against the local Firestore emulator. From the repo root (Java 21+ required locally):

  ```bash
  npm --prefix firebase-tests ci
  npm --prefix firebase-tests test
  ```

  CI runs the same suite on every pull request via the **Firestore Rules** job. Merges that touch rules/indexes/hosting also run `firebase-deploy.yml` after those tests pass.
- Firebase Hosting serves the Apple App Site Association file for `ufree.app`.
- Deep links support notification and profile paths; keep app entitlements, hosting configuration, and parser behavior aligned when changing them.
- Release builds enable Analytics and Crashlytics; debug builds disable analytics to avoid development noise. The event catalog lives in [ANALYTICS_EVENTS.md](ANALYTICS_EVENTS.md).
- **Push:** Firebase Messaging / APNs are not linked. Treat background push as unavailable until Phase 7 (Blaze). Foreground in-app inbox via Firestore listeners only.

## Where to make common changes

| Change | Start in |
|---|---|
| Availability behavior | `Core/Domain/`, `Core/Data/`, and `Core/Architecture/UseCases/UpdateMyStatus/` |
| Friend connection or discovery | `Core/Domain/Social/`, `Core/Data/Repositories/`, and `Core/Architecture/UseCases/FindFriends/` |
| Feed or nudge behavior | `Features/FriendsSchedule/` and `Features/Notifications/` |
| App lifecycle or navigation | `Features/Root/` and `UFreeApp.swift` |
| Firestore access | `firestore.rules` and `firestore.indexes.json` |
| Build or TestFlight automation | `fastlane/Fastfile` and `.github/workflows/` |

## Before opening a pull request

1. Run the smallest relevant tests, then the full suite for behavior changes.
2. Run the manual smoke checks if the change affects a social, authentication, deep-link, or release flow.
3. Do not include secrets, generated build artifacts, or local Firebase configuration.
4. Update the relevant current guide only when the product behavior, setup, or operating process changes.
