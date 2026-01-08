# match: Hands-Off Certificate Management

**Why match solves your distribution headaches**

---

## The Problem match Solves

Without match:
- Manually download .p12 certificates from Apple Developer Portal
- Manually manage provisioning profiles
- Share certificates across machines (insecure, error-prone)
- Certificates expire without warning
- "Unknown provisioning profile" errors on new machines
- Copy-paste provisioning profile UUIDs

With match:
- ✅ Certificates stored in private GitHub repo (encrypted)
- ✅ Auto-sync across machines (one password: MATCH_PASSWORD)
- ✅ Auto-renew expiring certificates
- ✅ CI/CD ready (GitHub Actions just needs MATCH_PASSWORD)
- ✅ Team collaboration without sharing secrets
- ✅ Zero manual downloads or copy-paste

---

## One-Time Setup (5 minutes)

### Step 1: Create Private GitHub Repo
```bash
# On GitHub:
# 1. Create new private repository (e.g., UFree-Certificates)
# 2. Copy the repo URL
```

### Step 2: Initialize match
```bash
cd /path/to/UFree
fastlane match init
```

You'll see:
```
[?] Select storage: 1
[?] Git Repo URL: https://github.com/yourusername/UFree-Certificates
[?] Branch: main (press Enter)
```

This creates a `Matchfile` in your `fastlane/` directory.

### Step 3: Generate App Store Signing Certificates
```bash
fastlane match appstore
```

You'll be prompted:
```
[?] Apple ID: khang@example.com
[?] Password: (your Apple ID password)
[?] Set a Passphrase for the Certificates Repo: 
```

This passphrase becomes your MATCH_PASSWORD. Save it securely.

**What happens:**
1. match logs into your Apple Developer Account
2. Creates signing certificates + provisioning profiles
3. Encrypts them with MATCH_PASSWORD
4. Commits to private GitHub repo
5. Prints them to your local machine (~/.match/)

### Step 4: Add MATCH_PASSWORD to .env
```bash
echo "MATCH_PASSWORD=your_passphrase_here" >> fastlane/.env
```

---

## Daily Use: Running fastlane beta

```bash
fastlane beta
```

What happens behind the scenes:
1. ✅ Runs tests (validation gate)
2. ✅ match decrypts certificates from GitHub (uses MATCH_PASSWORD)
3. ✅ Auto-increments build number
4. ✅ Builds IPA with correct signing
5. ✅ Uploads to TestFlight

**No manual certificate downloads. No provisioning profile errors. Just works.**

---

## On a New Machine (Your Teammate)

Your teammate just cloned the repo. How does their machine get the certificates?

```bash
# 1. Install Fastlane
cd /path/to/UFree
sudo gem install fastlane

# 2. Set MATCH_PASSWORD (they ask you for it securely)
export MATCH_PASSWORD=the_passphrase_you_saved

# 3. Run beta
fastlane beta
```

That's it. match automatically:
- Clones the encrypted GitHub repo
- Decrypts certificates with MATCH_PASSWORD
- Installs provisioning profiles to Xcode
- Builds and uploads to TestFlight

No emailing .p12 files. No sharing passwords in Slack. Just one password they get securely once.

---

## How It Works (Under the Hood)

**Local files (never committed):**
```
~/.match/
├── appstore_com.khangvu.UFree.ipa
├── appstore_com.khangvu.UFree.p12
└── appstore_UFree.mobileprovision
```

**Private GitHub repo (encrypted):**
```
https://github.com/yourusername/UFree-Certificates/
├── certs/
│   └── distribution/
│       └── ...encrypted.p12
└── profiles/
    └── appstore/
        └── ...encrypted.mobileprovision
```

**Encryption:**
- AES-256-CBC (industry standard)
- Passphrase: MATCH_PASSWORD
- GitHub repo is private (double protection)

---

## Certificate Expiration: Automatic Renewal

Apple signing certificates expire every 3 years. Provisioning profiles expire yearly.

With match:
```bash
fastlane match appstore --force
```

This force-refreshes certificates:
1. Creates new signing certificates on Apple Developer Portal
2. Creates new provisioning profiles
3. Encrypts and pushes to GitHub
4. Everyone pulls with `fastlane sync_certs`

Without match:
1. ❌ Manual download from portal
2. ❌ Notify team to re-download
3. ❌ Xcode signing errors until everyone updates
4. ❌ Some machines miss the update

---

## Best Practices

**DO:**
- ✅ Save MATCH_PASSWORD securely (password manager, team vault)
- ✅ Use `--force` only when intentionally renewing certificates
- ✅ Commit `Matchfile` to git (it's not a secret)
- ✅ Add MATCH_PASSWORD to CI/CD environment variables
- ✅ Run `fastlane sync_certs` regularly on CI (before every build)

**DON'T:**
- ❌ Commit MATCH_PASSWORD to git
- ❌ Commit encrypted certificates to UFree repo (GitHub repo for match is separate)
- ❌ Share MATCH_PASSWORD in Slack or email (use 1Password, Vault, or verbal)
- ❌ Manually download certificates from portal (let match manage them)
- ❌ Try to use expired certificates (run `--force` to refresh)

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `Git Repo Error` | Verify private repo exists and you have access |
| `Invalid Passphrase` | Check MATCH_PASSWORD in .env is correct |
| `Certificate not found` | Run `fastlane match appstore --force` to regenerate |
| `Connection timeout` | Check internet, GitHub API status |
| `Permission denied` | Verify GitHub token/SSH key works: `git clone <repo_url>` |

---

## Integration with beta Lane

In `fastlane/Fastfile`:
```ruby
lane :beta do
  tests  # Validation gate
  
  match(
    type: "appstore",
    readonly: is_ci,
    skip_confirmation: is_ci
  )
  
  increment_build_number(build_number: latest_testflight_build_number + 1)
  build_app(scheme: "UFree")
  upload_to_testflight
end
```

**Why `readonly: is_ci`?**
- Local machine: `readonly: false` (allows updates if certificates expire)
- CI machine: `readonly: true` (only uses existing certificates, doesn't modify them)

---

## match for CI/CD (GitHub Actions Example)

```yaml
# .github/workflows/testflight.yml
name: TestFlight Distribution

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Install Fastlane
        run: sudo gem install fastlane
      
      - name: Build and Upload to TestFlight
        env:
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
          APPLE_ID: ${{ secrets.APPLE_ID }}
          APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
        run: fastlane beta
```

Every push to `main`:
1. ✅ Tests run (all 206+ must pass)
2. ✅ match syncs certificates from GitHub (using MATCH_PASSWORD secret)
3. ✅ Builds IPA
4. ✅ Uploads to TestFlight

**No manual intervention. No certificate errors. No secrets in code.**

---

## Next Steps

1. Create private GitHub repo (e.g., `UFree-Certificates`)
2. Run `fastlane match init`
3. Run `fastlane match appstore`
4. Add MATCH_PASSWORD to `fastlane/.env`
5. Test: `fastlane beta`
6. Celebrate: No more certificate headaches

---

**Recommended Reading:**
- [Fastlane match docs](https://docs.fastlane.tools/actions/match/)
- [Apple Code Signing Guide](https://developer.apple.com/support/code-signing/)

**Date:** January 8, 2026
