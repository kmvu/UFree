# UFree troubleshooting runbook

Use the smallest safe fix first. Do not remove test gates, force-refresh signing material, or delete caches unless the symptom calls for it.

## Quick triage

| Symptom | First action | If unresolved |
|---|---|---|
| Bundler or Ruby fails | Check `ruby --version`, then run `bundle install` | Verify the Ruby version and OpenSSL installation |
| Tests fail or hang | Run the failing test in Xcode or `bundle exec fastlane tests` | Inspect the first Xcode failure; do not rely on a timeout alone |
| Simulator is missing | List devices with `xcrun simctl list devices available` | Choose an installed simulator or update the Fastlane device setting |
| Fastlane needs credentials | Check that untracked `fastlane/.env` values and key path are present | Verify App Store Connect key IDs and the certificate-repository SSH access |
| Signing or profile fails | Run `bundle exec fastlane sync_certs` | Confirm bundle ID and Match configuration before using `match --force` |
| Mac Designed for iPad: *integrity could not be verified* / `0xe8008015` | Use **Debug** (Automatic + Apple Development). Do not run that destination with the App Store Match profile | Release stays Manual/`match AppStore` for TestFlight only |
| TestFlight upload fails | Run `bundle exec fastlane beta --verbose` | Check App Store Connect status, signing, and the returned upload error |
| Friend request or QR connection fails | Deploy current Firestore rules and indexes | Inspect the Firestore permission or index error |
| A request never appears | Deploy indexes and check active user sessions | Confirm the `friendRequests` query/index and Firestore rules |
| Crash reports are missing | Confirm a release build and uploaded dSYMs | Check the Crashlytics console after processing time |

## Setup and Ruby

The project expects Ruby 3.3. On Apple Silicon, an OpenSSL error commonly means Ruby was built without the Homebrew OpenSSL path:

```bash
brew install openssl@3 libyaml
rvm install 3.3.0 --disable-binary \
  --with-openssl-dir="$(brew --prefix openssl@3)" \
  --with-libyaml-dir="$(brew --prefix libyaml)"
ruby -ropenssl -e 'puts OpenSSL::OPENSSL_VERSION'
```

Then run:

```bash
bundle install
```

## Tests and builds

```bash
bundle exec fastlane tests
xcodebuild -list -project UFree.xcodeproj
xcrun simctl list devices available
```

The test lane expects the `UFreeUnitTests` scheme and an iPhone 17 Pro simulator. If a test hangs, stop the process, run the smallest failing test, and inspect asynchronous tasks or mocked streams before retrying the full suite.

## Signing and TestFlight

Verify local credentials without printing their values:

```bash
test -f fastlane/.env && echo "fastlane .env exists"
test -f "$ASC_KEY_PATH" && echo "App Store Connect key exists"
bundle exec fastlane sync_certs
```

Use `bundle exec fastlane beta --verbose` for an upload failure. `beta` uses `export_method: "app-store"` and manual profile mapping. The GitHub deployment workflow is manual and supplies its own secrets; see the [operations guide](OPERATIONS_GUIDE.md).

Only use `bundle exec fastlane match appstore --force` when a signing owner has confirmed that renewal is needed. It can change shared signing material.

## Firebase and social flows

Deploy the current Firestore access controls before validating friend connections:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

If a friend request fails with a permission error, inspect `firestore.rules`. If the request write succeeds but a recipient never sees it, inspect `firestore.indexes.json` and the Firestore console’s index link. The current pilot supports in-app updates while the app is active; it does not deploy server-side Functions for background push.

### Find by Phone says “No user found” for a DEBUG test user

Usually the peer signed in with **User N** and a profile doc exists, but decoding used to fail when `friendIds` / `hashedPhoneNumbers` were omitted on first write. Current `UserProfile` decodes those as empty arrays. Re-login both DEBUG users after updating, then search with `+15550000001` (or formatted `+1 555-000-0001`).

### DEBUG User 1 / 2 / 3 login fails

DEBUG personas use **anonymous Auth** (not Sign in with Apple / Phone Auth), then attach display name + phone hashes. They should not show Phone Auth / APNs / verification-ID errors. Production login is Sign in with Apple.

1. Confirm `GoogleService-Info.plist` is present and `FirebaseApp.configure()` succeeds.
2. Confirm the device/simulator has network access to Firebase.
3. If an old Phone Auth error still appears, do a clean rebuild — older DEBUG builds still called `verifyPhoneNumber`.

## Escalation checklist

When asking for help, include:

1. The exact command or user action.
2. The first relevant error, not only the final summary.
3. Whether this is local, CI, TestFlight, or a Firebase environment.
4. Whether the problem affects one user or two connected users.
5. What was already tried.
