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

### Prerequisites

- macOS with **Xcode 26.6** (pinned in CI/deploy; match local `xcodebuild -version`)
- Ruby from tracked `.ruby-version` (`3.3.0`)
- Bundler and the project gems
- Firebase configuration file for local app builds
- Tracked `Package.resolved` under the Xcode workspace (do not delete it)

```bash
bundle install
bundle exec fastlane tests
```

The Fastlane test lane targets the `UFreeUnitTests` scheme on an **iPhone 17 Pro** simulator with code coverage enabled. See [Testing guide](TESTING_GUIDE.md) for focused test commands.

### CI / CD map

| Workflow | Jobs | When |
|---|---|---|
| `ci.yml` (Quality Check) | `firestore-rules` (ubuntu) · `unit-tests` (macos-26, Xcode 26.6) · `lint` (SwiftLint baseline) | Push / PR to `main` |
| `deploy.yml` (TestFlight) | Requires green `ci.yml` on the same SHA; `main` only; runs `fastlane beta` (tests always on) | Manual dispatch |
| `firebase-deploy.yml` | Rules tests → `firebase deploy --only firestore:rules,firestore:indexes,hosting` | Push to `main` when rules/indexes/`public/` change |

There is no `alpha` / Firebase App Distribution lane. TestFlight is the only distribution path.

### Signing and release credentials

Release work needs secrets that must never be committed:

- `fastlane/.env`
- App Store Connect `.p8` API key
- `MATCH_PASSWORD`
- any private SSH key
- `GoogleService-Info.plist`

Use the untracked local environment file expected by `fastlane/Fastfile`; do not put credentials in documentation, source code, or Git. The release workflow also expects GitHub secrets for the App Store Connect key, Match password, SSH certificate-repository access, and Firebase plist.

## Code conventions

- Use SwiftUI; do not introduce UIKit unless the platform requires it.
- Keep UI-facing view models on `@MainActor`.
- Prefer constructor injection and repository protocols for behavior that needs testing.
- Protect user actions that trigger async work from rapid repeats.
- Preserve local state or roll it back clearly when remote work fails.
- Use descriptive `CamelCase` type names and `camelCase` members.
- Follow the test naming and helper guidance in [AGENTS.md](AGENTS.md).

## Adaptive layout

Adapt by **size class / available width**, not device idiom (`UFree/Core/UI/Adaptive/`):

- Compact → `TabView` + phone layouts; regular → `NavigationSplitView` + grids/matrices (Schedule, Who’s Free).
- Cap Schedule detail with `AdaptiveLayout.scheduleContentMaxWidth` so status/week cards don’t stretch edge-to-edge on iPad/Mac.
- Regular presentations use popovers and readable form width; compact uses sheets.
- Landscape: shorten chrome when `verticalSizeClass == .compact`. Gate camera/QR with `QRScannerCapability`.
- Mac today is Designed for iPad only (`SUPPORTS_MAC_DESIGNED_FOR_IPAD` in Debug); Catalyst is deferred and would reuse the same layouts. For a three-account iPhone + iPad + Mac loop, see [TESTING_GUIDE.md](TESTING_GUIDE.md#three-platform-real-time-loop-iphone--ipad--mac). Debug uses Automatic + Apple Development so My Mac can install; Release keeps Manual/`match AppStore` for TestFlight.
- First-hangout coach: soft banner on Who’s Free → opt-in checklist sheet (`PairOnboardingBannerView` / `PairOnboardingChecklistView`). Empty Who’s Free uses intention hero (`WhoIsFreeEmptyHeroView`) plus banner — not a second checklist. **Not now** closes the sheet; **Don’t show again** persists via `OnboardingProgressStore.dismissPairChecklistPermanently()`. First invite / free-day completions get a light haptic + toast (no auto-sheet). Accept (inbox or Add Friends) fires `FriendsViewModel.onAcceptCompleted` → `RootViewModel.handlePostAccept`. First connection uses `celebrateFirstConnection` (named toast + haptic): Schedule + weekend CTA when a free day is still needed; otherwise Who’s Free with `PostConnectMissionChipView` (`OnboardingProgressStore` post-connect coach). Subsequent accepts go to Who’s Free with a named toast. Mission chip clears on dismiss or first nudge. Friends list is observed so the inviter can celebrate without a manual pull.
- Product CTAs: use `UFreePrimaryButtonStyle` / `UFreeSecondaryButtonStyle` / `UFreeCompactButtonStyle` and `UFreeType` (`Core/UI/Theme/`) for consistent padding, radius, and typography. Leave day chips / status banner on their own control language.

## Firebase, links, and observability

- Firestore rules and indexes are configured through `firebase.json`.
- **Privacy model (Phase 1):** user profiles and availability are readable only by the owner and accepted friends. Phone/QR discovery uses get-only collections `publicProfiles/{uid}` and `phoneDirectory/{hash}` (list queries are denied). Friend-request docs use deterministic ids `{fromId}_{toId}`; peer `friendIds` self-add requires an accepted request in the same batch.
- **Identity (Phase 2):** production login is **Sign in with Apple**. Existing anonymous pilot sessions are linked via `link(with:)` so UIDs/friends are preserved. DEBUG simulator personas (User 1/2/3) still use anonymous Auth. Phone is an optional discovery hash only (first-writer-wins; OTP is a later phase).
- **Account deletion:** Settings → Delete Account re-authenticates with Apple, wipes the user's Firestore tree (availability, notifications, own friendRequests, phoneDirectory claims, publicProfiles, users doc), deletes the Auth user, and clears local SwiftData / onboarding prefs. Rules allow owner/participant deletes.
- **App Check:** client uses App Attest (DeviceCheck fallback) in Release; DEBUG/Simulator use the App Check debug provider. Register the Xcode console debug token under Firebase Console → App Check → Manage debug tokens before enabling enforcement for Firestore.
- **Rules tests:** `firebase-tests/` runs against the local Firestore emulator. From the repo root (Java 21+ required locally):

  ```bash
  npm --prefix firebase-tests ci
  npm --prefix firebase-tests test
  ```

  CI runs the same suite on every pull request via the **Firestore Rules** job. Merges that touch rules/indexes/hosting also run `firebase-deploy.yml` after those tests pass.
- Firebase Hosting serves the Apple App Site Association file for `ufree.app`.
- Deep links support notification and profile paths; keep app entitlements, hosting configuration, and parser behavior aligned when changing them.
- Release builds enable Analytics and Crashlytics; debug builds disable analytics to avoid development noise.
- Push-registration code exists in the app, but the server-side Functions implementation is not currently configured for deployment. Treat background push as unavailable for the current pilot.

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
