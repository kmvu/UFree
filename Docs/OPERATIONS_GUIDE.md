# UFree operations guide

## Purpose

Use this guide to release a build, operate the TestFlight pilot, and understand the boundary between what is configured today and what is planned. It is written for the founder or release owner; engineering detail lives in the [engineering guide](ENGINEERING_GUIDE.md).

## Operating model

| Activity | Current path | Owner |
|---|---|---|
| Automated quality check | GitHub Actions **Quality Check** (`ci.yml`): Firestore Rules + Unit Tests + SwiftLint on pushes/PRs to `main`; **Emulator Integration** on `main` pushes | Engineering |
| TestFlight upload | Manual **Deploy to TestFlight** (`deploy.yml`) on `main` only, after a **green main-push** Quality Check on that SHA (must include Emulator Integration — PR-only green is not enough) | Release owner |
| Firestore rules, indexes, hosting | Auto on `main` when those paths change (`firebase-deploy.yml`); or local `firebase deploy --only …` | Engineering |
| App Check enforcement | Firebase Console → App Check → Firestore (enforce after debug tokens are registered for simulators) | Engineering |

Internal Firebase App Distribution (`fastlane alpha`) was removed. TestFlight is the only internal distribution path.

## Release gate (TestFlight)

Deploy cannot skip quality. The flow is:

1. Land the commit on `main` (a push, not only a PR merge SHA that never ran integration).
2. Wait for **Quality Check** on that exact SHA from a **`push` event** to finish green: **Firestore Rules**, **Unit Tests**, **UI Tests**, **SwiftLint**, and **Emulator Integration**. PR-only green cannot unlock TestFlight.
3. Trigger **Deploy to TestFlight** (workflow_dispatch, `main` only). The workflow refuses to ship if there is no successful main-push CI that name-checks all five jobs, required secrets are absent, or the ref is not `main`.
4. `fastlane beta` runs the unit suite again, then signs, builds, and uploads to TestFlight.

Pinned toolchain: **Xcode 26.6** on `macos-26`, simulator **iPhone 17 Pro**, Ruby from tracked `.ruby-version` (`3.3.0`).

## Founder launch checklist (Spark)

Complete before recruiting TestFlight pairs:

1. **Rules / indexes live** — merge to `main` so `firebase-deploy.yml` runs, or `npm --prefix firebase-tests test` then `firebase deploy --only firestore:rules,firestore:indexes`.
2. **Sign in with Apple** — enable the capability in Apple Developer for the App ID; enable the Apple provider in Firebase Console → Authentication.
3. **App Check** — register each Simulator/DEBUG token (Xcode console) under Firebase Console → App Check → Manage debug tokens, then **Enforce** App Check for **Firestore**. Device/TestFlight builds use App Attest.
4. **Push stays off** — no APNs / FCM until Phase 7 (Blaze). In-app inbox works only while the app is foregrounded.
5. Smoke two DEBUG simulators (User 1 / 2), then one SiwA device build; confirm Settings → Delete Account.

## Release commands

Run commands from the repository root. Use `bundle exec` so the checked-in Fastlane version is used.

```bash
bundle exec fastlane tests        # unit-test validation (iPhone 17 Pro + coverage)
bundle exec fastlane beta         # TestFlight upload (always runs tests first)
bundle exec fastlane sync_certs   # refresh or create signing material when needed
```

## TestFlight release checklist

1. Confirm the intended commit is on `main` and **Quality Check** passed for that SHA on a **main push** (Emulator Integration included — not a PR-only run).
2. Complete the [manual smoke test](TESTING_GUIDE.md#manual-release-smoke-test), including two-user flows when social behavior changed.
3. Verify the marketing version in Xcode if it needs to change; Fastlane only increments the build number.
4. Trigger **Deploy to TestFlight** in GitHub Actions, or run `bundle exec fastlane beta` with the required local credentials.
5. Wait for Apple to process the build, then complete any TestFlight approval and tester-group actions in App Store Connect.
6. Monitor Crashlytics and the pilot feedback after distribution.

Do not promise that a TestFlight upload immediately reaches external testers: Apple processing and any App Store Connect approval remain manual steps.

## TestFlight dyad pilot

### Before recruiting people

1. Deploy Firestore rules and indexes (required after Phase 1 privacy changes — old open-read rules break the product promise). Prefer merging to `main` so `firebase-deploy.yml` runs after rules tests; or deploy manually:

   ```bash
   npm --prefix firebase-tests test
   firebase deploy --only firestore:rules,firestore:indexes
   ```

2. Enable Sign in with Apple in Apple Developer + Firebase Auth, and App Check (App Attest). For Simulator/DEBUG builds, copy the App Check debug token from the Xcode console into Firebase Console → App Check → Manage debug tokens **before** turning on Firestore enforcement. See [Founder launch checklist](#founder-launch-checklist-spark).

3. Validate the flow on two debug simulators using the debug test-user controls (User 1 / 2 / 3 — anonymous Auth; SiwA is the device/TestFlight path). Keep both apps foregrounded — background push is Phase 7.
4. Build and distribute through TestFlight only after the uncoached flow works.
5. Confirm Settings → Delete Account completes on a SiwA account (re-auth sheet → cloud wipe including peers’ friendIds → signed out).

### Recruiting and measuring

- Start with 2–3 friend pairs who already spend time together.
- Give one instruction: “Invite each other, mark the weekend free, and nudge a day.”
- Do not coach them through the product after that instruction.
- Expand to 5–10-person clusters only after initial pairs complete the loop.

| Pair | Connected | Both marked free | Nudge and reply | Reopened Friday | Notes |
|---|---|---|---|---|---|
| 1 | | | | | |
| 2 | | | | | |
| 3 | | | | | |

The pilot passes only when at least half of seeded pairs complete the core loop in one weekend and reopen the following Friday without a founder reminder. Full product context and the decision boundary are in the [product overview](PRODUCT_OVERVIEW.md).

## Firebase deployment (rules / indexes / hosting)

Spark-tier only: `firebase-deploy.yml` deploys `firestore:rules`, `firestore:indexes`, and `hosting` (AASA). It does **not** deploy Cloud Functions.

### CI secret setup

1. Locally: `firebase login:ci` (Firebase CLI signed in as a project owner/editor).
2. Copy the printed token into GitHub → Settings → Secrets and variables → Actions as **`FIREBASE_TOKEN`**.
3. Project id used by the workflow: `ufree-313a2` (same as local `.firebaserc`).

On every push to `main` that touches `firestore.rules`, `firestore.indexes.json`, `public/`, or `firebase.json`, the workflow runs `firebase-tests` then deploys. Manual re-run: workflow_dispatch on **Deploy Firebase Rules & Hosting**.

### Rollback

1. `git revert` the bad commit on `main` (or restore the last known-good rules/indexes/hosting files) and push.
2. [`.github/workflows/firebase-deploy.yml`](../.github/workflows/firebase-deploy.yml) re-runs on the reverted paths and restores production.
3. If CI cannot run, deploy the known-good tree manually: `firebase deploy --only firestore:rules,firestore:indexes,hosting`.

## Firebase deployment boundary

The current `firebase.json` config deploys Firestore rules, indexes, and Hosting. It does **not** configure a Functions source. The repository has `functions/index.js` containing push-notification and weekend-digest code, but it is not part of the current deployment path.

For the Spark-tier pilot:

- Deploying Firestore rules and indexes is supported.
- In-app friend requests, nudges, and replies work through Firestore listeners when the app is active (foreground-only).
- **Background / killed-app push and FCM are deferred to Phase 7** (Blaze + Functions). The app does not link Firebase Messaging or register for APNs on Spark.
- Do not deploy Functions or enable billing until the team deliberately accepts the required Firebase plan and adds a reviewed Functions deployment configuration.

## Monitoring and incident response

- **Crashes:** Firebase Crashlytics for release builds.
- **Product behavior:** Firebase Analytics events for onboarding, connection, availability, nudge/reply, and reopening milestones.
- **Build, signing, or Firebase failures:** [Troubleshooting runbook](TROUBLESHOOTING_RUNBOOK.md).

## Security and access

Keep credentials in secret stores, not in the repository.

| Secret | Used by |
|---|---|
| `GOOGLE_SERVICE_INFO_PLIST` | `ci.yml`, `deploy.yml` (base64 plist) |
| `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT` (or legacy `ASC_KEY`) | `deploy.yml` / Fastlane |
| `MATCH_PASSWORD`, `SSH_PRIVATE_KEY` | Match certs (Bitbucket) |
| `FIREBASE_TOKEN` | `firebase-deploy.yml` |

Review exact names in `fastlane/Fastfile` and `.github/workflows/` whenever automation changes.
