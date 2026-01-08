# Fastlane Setup - Concise Guide

**Build validation and distribution automation**

---

## 3 Commands

```bash
fastlane tests   # Run 206+ tests, exit if any fail
fastlane alpha   # Build & upload to Firebase (instant)
fastlane beta    # Build & upload to TestFlight (1-2 days)
```

---

## One-Time Setup (20 minutes)

### 1. Configure Appfile
Edit `fastlane/Appfile` with your actual values:
```ruby
app_identifier("com.khangvu.UFree")
apple_id("your-apple-email@example.com")
team_id("XXXXXXXXXX")  # From developer.apple.com → Membership
itc_team_id("XXXXXXXXXX")
itunes_connect_id("your-apple-email@example.com")
```

### 2. Set Up match for Certificates
Create a **private GitHub repository** (e.g., `UFree-Certificates`) for encrypted certificate storage.

Initialize match:
```bash
fastlane match init
# Select "git" and enter your private repo URL
```

Generate App Store signing certificates:
```bash
fastlane match appstore
# You'll be prompted to set a MATCH_PASSWORD
# Save this password securely - you'll use it on other machines
```

### 3. Configure Environment (.env File)

Create a `.env` file in `fastlane/` directory. This is where you'll store secrets that Fastlane automatically loads:

```bash
cp fastlane/.env.default fastlane/.env
```

Edit `fastlane/.env` with your credentials:
```env
# Apple ID Credentials
FASTLANE_USER="your-apple-email@example.com"
FASTLANE_PASSWORD="your-apple-id-app-specific-password"

# Match Encryption Password (used to encrypt/decrypt certificates)
MATCH_PASSWORD="your-strong-encryption-password"

# Firebase Credentials (if using a CI or non-logged in machine)
FIREBASE_APP_ID=your_app_id
FIREBASE_TOKEN="your-firebase-refresh-token"

# App Store Connect API Key (Optional but recommended)
# Helps avoid 2FA prompts during builds
FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD="your-app-specific-password"

# Team Configuration
APPLE_TEAM_ID=your_team_id
```

**How Fastlane Uses .env:**
- Fastlane automatically looks for `.env` in the `fastlane/` directory when you run commands
- It silently loads all variables before execution
- No more prompts for passwords during `fastlane beta` or certificate syncs

**CRITICAL: Verify .gitignore Protection**

Before saving your .env file, ensure `fastlane/.gitignore` contains:
```
# Environment & Credentials
.env
.env.local
.env.*.local
```

This prevents your credentials from ever being committed to Git. Check:
```bash
cat fastlane/.gitignore | grep "\.env"
```

If `.env` is not listed, add it immediately.

### 3.1 Verify the Setup Works

Test that Fastlane picks up your credentials without prompting:

```bash
fastlane match appstore --readonly
```

If this completes without asking for a password, your automation is fully "hands-off."

**Expected output:**
```
[✓] Certificates already exist
[✓] Profiles already exist
```

No password prompts = ✅ Success

### 4. Firebase CLI (Optional, needed for alpha lane)
```bash
brew install firebase-cli
firebase login
firebase use --add
```

### 5. Verify Everything Works

Run the test suite to ensure all configuration is correct:

```bash
fastlane tests
```

Should pass all 206+ tests.

**What .env gives you:**
- ✅ **No more prompts:** Fastlane reads credentials silently
- ✅ **CI/CD ready:** Same .env variables work in GitHub Actions, Bitrise, etc.
- ✅ **Secure sharing:** Only MATCH_PASSWORD needs sharing (not full credentials)
- ✅ **Hands-off builds:** Your entire workflow is now automated end-to-end

---

## Lanes Explained

| Lane | Purpose | Time | Requirements |
|------|---------|------|--------------|
| **tests** | Validate all tests | ~90s | None |
| **alpha** | Firebase distribution | ~3 min | Firebase app ID, match certs |
| **beta** | TestFlight distribution | ~8 min | App Store Connect, match certs |
| **sync_certs** | Manual cert sync | ~30s | match + GitHub |

---

## Validation Gates

Every build must pass tests first:
- `alpha` calls `tests` → fails if tests fail
- `beta` calls `tests` → fails if tests fail
- Prevents broken code reaching testers

---

## Files

| File | Purpose |
|------|---------|
| `fastlane/Fastfile` | Automation scripts (5 lanes) |
| `fastlane/Appfile` | App & account configuration |
| `fastlane/.env` | Your credentials (never commit) |
| `fastlane/.gitignore` | Protects secrets |

---

## What Gets Protected (Never Committed)

**CRITICAL - These must NEVER be in Git:**
- `fastlane/.env` (your credentials - FASTLANE_USER, FASTLANE_PASSWORD, MATCH_PASSWORD, FIREBASE_TOKEN)
- `fastlane/.fastlane_user` (Xcode session token)
- `fastlane/.fastlane_password` (cached password)
- `AuthKey_*.p8` (Apple API signing key)
- `match_password` (match encryption file)
- `fastlane/builds/` (build artifacts)
- `fastlane/test_results/` (test output)

**Safe to commit:**
- `fastlane/Fastfile` (automation code)
- `fastlane/Appfile` (app configuration)
- `fastlane/.env.default` (template - never fill in real values)
- `fastlane/.gitignore` (protection rules)
- `fastlane/Matchfile` (match configuration)

**Before you push to Git, verify:**
```bash
# Make sure .env is never tracked
git status | grep -i ".env"
# Should return nothing (empty)

# Double-check what's staged
git diff --cached fastlane/ | grep -i "password\|token\|secret"
# Should return nothing (empty)
```

---

## match: Hands-Off Certificate Management

**Why match?**
- Creates certificates once, stores in private Git repo (encrypted)
- Syncs across machines via GitHub (no manual .p12 downloads)
- No more "Certificate expired" surprises
- CI/CD uses MATCH_PASSWORD to decrypt on new machines
- One-time setup eliminates manual certificate headaches forever

**What changed (Sprint 6.1):**
| Before | After |
|--------|-------|
| ❌ Manually download .p12 from Apple | ✅ Private GitHub repo (encrypted) |
| ❌ Manually download provisioning profiles | ✅ Auto-sync across machines |
| ❌ Share credentials via email/Slack | ✅ One MATCH_PASSWORD (secure sharing) |
| ❌ "Certificate not found" on new machines | ✅ Just set MATCH_PASSWORD & run fastlane |
| ❌ Certs expire without warning | ✅ Auto-renewal on expiration |
| ❌ CI/CD requires Apple ID + password | ✅ GitHub secret + zero manual steps |

**Setup (one time):**
```bash
# 1. Create private GitHub repo (e.g., UFree-Certificates)
fastlane match init
# Select "git" and enter your private repo URL

# 2. Generate certificates
fastlane match appstore
# You'll be prompted to set MATCH_PASSWORD
# Save this securely - you'll use it on other machines

# 3. MATCH_PASSWORD is already set in your .env from One-Time Setup step 3
```

**How it works:**

*Your machine:*
```
fastlane beta
  ↓
match appstore (reads Appfile + MATCH_PASSWORD)
  ↓
Decrypts certificates from GitHub (UFree-Certificates)
  ↓
Installs certs + profiles to ~/.match/
  ↓
Builds IPA with correct signing
  ↓
Uploads to TestFlight
```

*Daily use:*
```bash
fastlane beta
# ✅ Certificates synced automatically
# ✅ IPA signed
# ✅ Uploaded to TestFlight
```

*On a teammate's machine:*
```bash
export MATCH_PASSWORD=your_password  # (you give this once)
fastlane beta
# match clones + decrypts from GitHub automatically
# Rest of flow is identical
```

*CI/CD (GitHub Actions):*
```
GitHub secret: MATCH_PASSWORD
  ↓
GitHub Actions runs: fastlane beta
  ↓
match decrypts from GitHub repo
  ↓
Builds + uploads to TestFlight
  ↓
Zero human intervention
```

---

## Distribution Options

**Firebase Alpha (Internal):**
```bash
fastlane alpha
```
- Instant delivery to internal testers
- No Apple review
- Use for your own device testing
- Perfect for rapid iteration

**TestFlight Beta (External):**
```bash
fastlane beta
```
- Requires Apple review (1-2 days)
- For friends/external testers
- Auto-increments build number
- Certificates auto-synced via match

---

## App Store Connect Setup (Required for TestFlight)

1. Create App ID at appstoreconnect.apple.com
2. Set up bundle identifier in Xcode (matches Appfile)
3. match handles provisioning profiles automatically

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Tests timeout | Reset simulator: `xcrun simctl erase all` |
| Firebase upload fails | Run `firebase login` again |
| Build fails (code signing) | Run `fastlane match appstore` to refresh certs |
| match fails (GitHub access) | Check private repo exists, GitHub token works |
| "Unknown provisioning profile" | Run `fastlane sync_certs` manually |

---

## Pair Testing (Validate Before Distribution)

Before using `fastlane alpha` or `fastlane beta`:

1. **Phone Search** - User A finds User B (blind index)
2. **Handshake** - A sends request, B accepts
3. **Heatmap** - Both see "Who's free on..." with counts
4. **Nudge** - A nudges B → B gets real-time notification
5. **Validation** - Check haptics, sync timing, rapid-tap protection

See `TESTING_GUIDE_USER_FRIENDLY.md` for detailed steps.

---

## Performance Targets

| Operation | Expected |
|-----------|----------|
| Tests | ~90 sec |
| Alpha build | ~3 min |
| Beta build | ~8 min |
| match sync | ~30 sec |
| Real-time sync | < 3 sec |
| Phone search | < 2 sec |
| Nudge delivery | < 2 sec |

---

## Secrets & Security

### Local Machine (.env Strategy)

**Your .env file contains:**
```
FASTLANE_USER, FASTLANE_PASSWORD, MATCH_PASSWORD, FIREBASE_TOKEN, FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD
```

**Protection:**
- `fastlane/.gitignore` prevents it from ever being committed
- Keep `.env` in password manager as backup
- Never share in Slack, email, or chat
- Only share MATCH_PASSWORD securely (1Password, Vault, verbal)

### CI/CD Environment (GitHub Actions, Bitrise, etc.)

Instead of `.env`, use GitHub Secrets:
```yaml
# GitHub Actions: Settings → Secrets and variables → Actions
FASTLANE_USER: your_email@apple.com
FASTLANE_PASSWORD: your_app_specific_password
MATCH_PASSWORD: your_match_password
FIREBASE_TOKEN: your_token
FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD: your_app_specific_password
```

When CI/CD runs `fastlane beta`, it pulls these as environment variables automatically (same behavior as local `.env`).

### Private match Repository

- **GitHub (private):** Encrypted certificates + provisioning profiles
- **Encryption:** AES-256-CBC (industry standard)
- **Access:** Only with MATCH_PASSWORD
- **Never commit** encrypted certs to main UFree repo (separate private repo only)

### Security Checklist

Before every push to Git:
- ✅ `.env` is NOT tracked (`git status`)
- ✅ No passwords in staged files (`git diff --cached fastlane/`)
- ✅ `.gitignore` has `.env` listed
- ✅ `Appfile` contains app config only (no secrets)
- ✅ Only `Fastfile` and `Appfile` are committed from `fastlane/`

---

## Quick Reference

```bash
# Validate tests before any build
fastlane tests

# Test on your device (instant)
fastlane alpha

# Submit to TestFlight (Apple review)
fastlane beta

# Get latest build number
fastlane get_testflight_build_number

# Manually sync certs if needed
fastlane sync_certs

# Run tests with detailed report
fastlane test_report
```

---

## Where You Are Now

With the Appfile, Fastfile, .env, and match configured:

**🧪 Quality is Guaranteed**
- Every build runs your 206+ tests first
- Broken code cannot reach testers

**🔐 Handshaking is Automatic**
- Certificates for Nudge & Handshake features are managed securely
- match keeps them encrypted on GitHub
- Auto-renews before expiration

**📦 Distribution is One-Click**
- `fastlane tests` → validate
- `fastlane alpha` → Firebase (instant)
- `fastlane beta` → TestFlight (1-2 days)

**🚫 No Manual Certificate Headaches**
- .env prevents password prompts
- Teammates just set MATCH_PASSWORD once
- CI/CD is ready with GitHub Secrets

## Next: Real-World Testing

1. Run `fastlane tests` (verify all 206+ pass)
2. Run `fastlane alpha` (test on your device with Firebase)
3. **[IMPORTANT] Add Xcode Build Phase Script for Crashlytics** (see step below)
4. Recruit 2-3 pair testers (friends/colleagues)
5. Follow `TESTING_GUIDE_USER_FRIENDLY.md` for validation
6. Run `fastlane beta` to submit to TestFlight
7. Approve build in TestFlight & send to external testers
8. Monitor crashes in Firebase Console → Crashlytics

### Critical: Add Xcode Build Phase Script (5 minutes)

Before running `fastlane beta`, you must add the Crashlytics dSYM upload script to Xcode:

1. Open UFree.xcodeproj in Xcode
2. Select UFree target → Build Phases
3. Click `+` → New Run Script Phase
4. Name it: `Upload dSYMs to Firebase Crashlytics`
5. Paste this script:
   ```bash
   "${BUILD_DIR%Build/*}SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
   ```
6. **IMPORTANT:** Uncheck "Based on dependency analysis" (so it runs every archive)
7. Build Phases order: Script should be AFTER "Compile Sources"

**Why?** Without this, dSYM files won't be uploaded to Firebase, and crash reports will show memory addresses instead of readable code.

**Verify it works:**
```bash
xcodebuild archive -scheme UFree -configuration Release
# Look for "Upload dSYMs to Firebase Crashlytics" in build log
```

See `CRASHLYTICS_SETUP.md` for detailed explanation and troubleshooting.

## Future: CI/CD Automation (When Ready)

With match now integrated and .env configured, you're ready to set up GitHub Actions:
```bash
git push main
  ↓
GitHub Actions triggers fastlane beta automatically
  ↓
Tests run + certificates sync + build + upload to TestFlight
  ↓
Zero manual intervention required
```

For CI/CD integration, see `MATCH_GUIDE.md` for detailed GitHub Actions setup.

---

**Date:** January 8, 2026 | **Version:** 1.3 (match integrated, .env secured, CI/CD ready)
