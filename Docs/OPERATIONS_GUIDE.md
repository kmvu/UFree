# UFree operations guide

## Purpose

Use this guide to release a build, operate the TestFlight pilot, and understand the boundary between what is configured today and what is planned. It is written for the founder or release owner; engineering detail lives in the [engineering guide](ENGINEERING_GUIDE.md).

## Operating model

| Activity | Current path | Owner |
|---|---|---|
| Automated quality check | GitHub Actions: Firestore rules tests (ubuntu) + `bundle exec fastlane tests` (macos) on pushes/PRs to `main` | Engineering |
| Internal device build | `bundle exec fastlane alpha` | Engineering / QA |
| TestFlight upload | Manual GitHub Actions workflow or `bundle exec fastlane beta` | Release owner |
| Firestore rules and indexes | `firebase deploy --only firestore:rules,firestore:indexes` (must ship with app builds that expect the Phase 1 privacy model) | Engineering |
| Hosting / universal links | Firebase Hosting configuration in `firebase.json` | Engineering |

## Release commands

Run commands from the repository root. Use `bundle exec` so the checked-in Fastlane version is used.

```bash
bundle exec fastlane tests        # unit-test validation
bundle exec fastlane alpha        # internal Firebase App Distribution build
bundle exec fastlane beta         # TestFlight upload
bundle exec fastlane sync_certs   # refresh or create signing material when needed
```

`beta` runs tests by default, synchronizes signing material, increments the build number, builds an App Store IPA, uploads Crashlytics symbols, and uploads to TestFlight. The current GitHub deployment workflow sets `SKIP_TESTS=true`, so it relies on the separate main-branch quality workflow rather than rerunning tests during deployment. Treat a green main-branch test run as a release prerequisite.

## TestFlight release checklist

1. Confirm the intended commit is on `main` and its quality workflow passed.
2. Complete the [manual smoke test](TESTING_GUIDE.md#manual-release-smoke-test), including two-user flows when social behavior changed.
3. Verify the marketing version in Xcode if it needs to change; Fastlane only increments the build number.
4. Trigger **Deploy to TestFlight** in GitHub Actions, or run `bundle exec fastlane beta` with the required local credentials.
5. Wait for Apple to process the build, then complete any TestFlight approval and tester-group actions in App Store Connect.
6. Monitor Crashlytics and the pilot feedback after distribution.

Do not promise that a TestFlight upload immediately reaches external testers: Apple processing and any App Store Connect approval remain manual steps.

## TestFlight dyad pilot

### Before recruiting people

1. Deploy Firestore rules and indexes (required after Phase 1 privacy changes — old open-read rules break the product promise):

   ```bash
   firebase deploy --only firestore:rules,firestore:indexes
   ```

   Confirm `npm --prefix firebase-tests test` is green before deploying.

2. Validate the flow on two debug simulators using the debug test-user controls.
3. Keep both apps foregrounded for the in-app notification/reply experience.
4. Build and distribute through TestFlight only after the uncoached flow works.

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

## Firebase deployment boundary

The current `firebase.json` config deploys Firestore rules, indexes, and Hosting. It does **not** configure a Functions source. The repository has `functions/index.js` containing push-notification and weekend-digest code, but it is not part of the current deployment path.

For the Spark-tier pilot:

- Deploying Firestore rules and indexes is supported.
- In-app friend requests, nudges, and replies work through Firestore listeners when the app is active.
- Background/killed-app push and the scheduled weekend digest are unavailable.
- Do not deploy Functions or enable billing until the team deliberately accepts the required Firebase plan and adds a reviewed Functions deployment configuration.

## Monitoring and incident response

- **Crashes:** Firebase Crashlytics for release builds.
- **Product behavior:** Firebase Analytics events for onboarding, connection, availability, nudge/reply, and reopening milestones.
- **Build, signing, or Firebase failures:** [Troubleshooting runbook](TROUBLESHOOTING_RUNBOOK.md).

## Security and access

Keep credentials in secret stores, not in the repository. The deployment workflow requires App Store Connect credentials, Match password, SSH access to the certificate repository, and a base64-encoded Firebase plist. Review the exact environment variable names in `fastlane/Fastfile` and `.github/workflows/deploy.yml` whenever those workflows change.
