# Fastlane Documentation Index

**Complete guide to UFree's build automation, distribution, and certificates**

---

## 🚀 Get Started (5 minutes)

**New to Fastlane?** Start here:

1. Read **[GETTING_STARTED.md](./GETTING_STARTED.md)** (20 min setup)
   - Generate API key on App Store Connect
   - Create `.env` file with credentials
   - Verify setup works (no prompts)

2. Run your first commands:
   ```bash
   fastlane tests      # Validate 206+ tests
   fastlane beta       # Build & upload to TestFlight
   ```

---

## 📖 Documentation (3 Files)

### [GETTING_STARTED.md](./GETTING_STARTED.md) — Initial Setup
**Time:** 20 minutes

What you'll do:
- ✅ Generate App Store Connect API key
- ✅ Create `.env` file with credentials
- ✅ Update Appfile (remove prompts)
- ✅ Verify setup (run sync_certs, tests, beta)
- ✅ Security checklist (protect secrets)

**Read this first.** Everything else assumes this is done.

---

### [DISTRIBUTION.md](./DISTRIBUTION.md) — All Workflows
**Time:** Quick reference (5-10 min reads)

What's covered:
- **3 Main Lanes:** tests, alpha (Firebase), beta (TestFlight)
- **Certificate Management:** How match works, when to refresh
- **TestFlight Workflow:** Build, upload, notify testers
- **Firebase Integration:** Crashlytics crashes, Analytics events
- **Performance:** 9x faster builds (cold: 45s → <5s)
- **Caching:** Derived data, SPM packages

**Read this when:** You want to understand workflows or find out how something works.

---

### [REFERENCE.md](./REFERENCE.md) — Quick Lookup & Troubleshooting
**Time:** Instant reference

What's covered:
- **Commands:** All fastlane commands with flags
- **Configuration:** Fastfile, Appfile, Matchfile, .env reference
- **File Structure:** What to commit, what to ignore
- **Troubleshooting:** Solutions for 20+ common issues
- **Lanes in Detail:** Code for each lane
- **Performance Metrics:** Build times, optimizations
- **FAQs:** Quick answers to common questions

**Read this when:** Something breaks or you need a quick answer.

---

## 🎯 Common Workflows

### I want to test on my device now
```bash
fastlane alpha
```
→ See **[DISTRIBUTION.md → fastlane alpha](./DISTRIBUTION.md#fastlane-alpha)**

### I want to submit to TestFlight
```bash
fastlane beta
```
→ See **[DISTRIBUTION.md → fastlane beta](./DISTRIBUTION.md#fastlane-beta)**

### I'm getting password prompts
→ See **[REFERENCE.md → Authentication Issues](./REFERENCE.md#authentication-issues)**

### Certificates expired or "not found"
→ See **[REFERENCE.md → Certificate Issues](./REFERENCE.md#certificate-issues)**

### Build is too slow
→ See **[REFERENCE.md → Performance Metrics](./REFERENCE.md#performance-metrics)** (already optimized 9x)

### I need to add a new team member
→ See **[DISTRIBUTION.md → Certificate Management](./DISTRIBUTION.md#certificate-management-match)**

### I need to track user crashes
→ See **[DISTRIBUTION.md → Crashlytics](./DISTRIBUTION.md#crashlytics-monitor-crashes)**

---

## ⚡ Quick Reference

### 3 Main Commands
```bash
fastlane tests   # Run 206+ unit tests (~90s)
fastlane alpha   # Build & upload to Firebase (~3 min)
fastlane beta    # Build & upload to TestFlight (~8 min)
```

### Before Committing to Git
```bash
git status | grep -i ".env"           # Should be empty
git diff --cached fastlane/ | grep -i "password"  # Should be empty
```

### If Stuck
1. Check **[REFERENCE.md → Troubleshooting](./REFERENCE.md#troubleshooting)** (20+ solutions)
2. Check **[REFERENCE.md → FAQs](./REFERENCE.md#faqs)** (quick answers)
3. Run with verbose: `fastlane beta --verbose`

---

## 📋 File Checklist

### After Setup
- [ ] `.env` created (never commit)
- [ ] `fastlane/Keys/*.p8` exists (never commit)
- [ ] `fastlane/.gitignore` includes `.env` and `*.p8`
- [ ] `fastlane/Appfile` cleaned (no apple_id/itunes_connect)
- [ ] Run `fastlane tests` → All pass ✅
- [ ] Run `fastlane sync_certs` → No prompts ✅

### Never Commit
- `.env` (credentials)
- `fastlane/Keys/*.p8` (API key)
- `fastlane/builds/`, `fastlane/test_results/` (artifacts)

### Always Commit
- `fastlane/Fastfile`, `fastlane/Appfile`, `fastlane/Matchfile` (code)
- `fastlane/.env.default` (template)
- `fastlane/.gitignore` (rules)
- `fastlane/Docs/` (documentation)

---

## 🎓 Learning Path

**Day 1: Setup**
1. Read **GETTING_STARTED.md** (20 min)
2. Complete setup steps 1-4
3. Run `fastlane tests` (verify no prompts)

**Day 2: First Build**
1. Run `fastlane alpha` (build for Firebase)
2. Install on device from Firebase link
3. Read **[DISTRIBUTION.md → fastlane alpha](./DISTRIBUTION.md#fastlane-alpha)** to understand what happened

**Day 3: TestFlight**
1. Run `fastlane beta` (full workflow)
2. Read **[DISTRIBUTION.md → fastlane beta](./DISTRIBUTION.md#fastlane-beta)** to understand what happened
3. Wait for TestFlight processing
4. Approve build in TestFlight → Send to external testers

**Day 4: Monitoring**
1. Read **[DISTRIBUTION.md → Firebase Setup](./DISTRIBUTION.md#firebase-setup)**
2. Install beta on device
3. Monitor crashes in Crashlytics
4. Monitor user behavior in Analytics

---

## ❓ Need Help?

### Setup Issues
→ **[GETTING_STARTED.md](./GETTING_STARTED.md)**

### How something works
→ **[DISTRIBUTION.md](./DISTRIBUTION.md)**

### Something broke / Quick lookup
→ **[REFERENCE.md](./REFERENCE.md)**

### Not here?
- Check Fastlane docs: https://docs.fastlane.tools/
- Check Apple docs: https://developer.apple.com/support/code-signing/

---

**Version:** 2.0 (3-doc consolidated) | **Date:** January 26, 2026
