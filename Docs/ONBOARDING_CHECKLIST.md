# Onboarding checklist

Use this once when setting up a new machine for UFree development.

## Tooling

- [ ] **Xcode 26.6** (match CI / `xcodebuild -version`) with an **iOS 18+** Simulator
- [ ] **Ruby** from tracked [`.ruby-version`](../.ruby-version) (`3.3.0`)
- [ ] `bundle install` from the repo root (Fastlane + gems)
- [ ] **Java 21** for Firebase emulators (Temurin / Homebrew `openjdk@21`)
- [ ] Node 22+ for `firebase-tests` (`npm --prefix firebase-tests ci`)

## Firebase / secrets (local only — never commit)

- [ ] Place `GoogleService-Info.plist` at the repo root (or path expected by the Xcode target)
- [ ] Confirm [`.firebaserc`](../.firebaserc) points at the team project (`ufree-313a2`)
- [ ] Copy [`fastlane/.env.example`](../fastlane/.env.example) → `fastlane/.env` and fill secret **values** locally when doing release work
- [ ] Register App Check debug tokens in Firebase Console if needed (do not commit tokens)

## Verify

```bash
npm --prefix firebase-tests test
bundle exec fastlane tests
./Scripts/count_tests.sh
```

Optional emulator integration (needs Java 21 + Auth/Firestore emulators):

```bash
./Scripts/run_integration_tests.sh
```

See [ENGINEERING_GUIDE.md](ENGINEERING_GUIDE.md) for architecture and [TESTING_GUIDE.md](TESTING_GUIDE.md) for focused commands.
