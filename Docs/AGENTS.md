# UFree working conventions

This is the concise, repository-specific checklist for contributors and coding assistants. Read the [engineering guide](ENGINEERING_GUIDE.md) for architecture and setup, the [testing guide](TESTING_GUIDE.md) for validation, and the [operations guide](OPERATIONS_GUIDE.md) for releases.

## Change discipline

- Keep changes focused on the requested behavior.
- Do not commit credentials, Firebase configuration, private keys, local `.env` files, or build artifacts.
- Preserve the existing SwiftUI, async/await, `@MainActor`, dependency-injection, and repository-protocol patterns.
- Add or update tests for behavior changes; documentation-only changes do not require test runs.

## Code and test conventions

- Use `CamelCase` for types and `camelCase` for properties and functions.
- Keep UI-facing view models on `@MainActor`.
- Use `@Published` state for view models observed by SwiftUI.
- Guard async user actions against rapid repeated taps.
- Name tests `test_[method]_[expectedBehavior]()`.
- View-model test setup should call `trackForMemoryLeaks()`; shared helpers belong in `UFreeTests/Helpers/`.

## Validation

```bash
npm --prefix firebase-tests test   # Firestore rules (needs Java 21+)
bundle exec fastlane tests         # iOS unit suite (iPhone 17 Pro)
bundle exec fastlane ui_tests      # UI happy path (UI_TESTING_MODE)
# Emulators need Java 21+ — script uses .jdk/ when PATH has no java:
./Scripts/run_integration_tests.sh
swiftlint lint                     # baseline; CI fails on error-severity only
```

CI runs **Firestore Rules**, **Unit Tests**, **UI Tests**, and **SwiftLint** on every push/PR to `main`, plus **Emulator Integration** on main pushes and on PRs touching rules, data-layer, or integration-test paths; the TestFlight deploy gate needs all five green on a main push. Exact jobs, triggers, and toolchain pins live in the [engineering guide CI/CD map](ENGINEERING_GUIDE.md#cicd-map). Run the smallest relevant test first when practical. Rules or discovery/handshake changes must keep the emulator suite green. Follow the manual smoke checks in [TESTING_GUIDE.md](TESTING_GUIDE.md) when changing social, authentication, deep-link, or release behavior.

## Security

- Production identity is Sign in with Apple; DEBUG User 1/2/3 remain anonymous for Simulator.
- Never log raw phone numbers. App Check debug tokens are local-only — register them in Firebase Console, do not commit them.
- Account deletion must wipe Firestore + Auth; keep rules tests green when changing delete permissions.

Never commit:

- `.env` files or passwords
- `fastlane/Keys/*.p8` or other API keys
- private SSH material
- `GoogleService-Info.plist`

Treat secret names and CI configuration in `fastlane/Fastfile` and `.github/workflows/` as implementation details that must be reviewed whenever automation changes.
