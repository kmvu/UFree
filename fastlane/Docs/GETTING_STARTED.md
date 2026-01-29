# Getting Started with Fastlane

**One-time setup to eliminate password prompts and get building**

---

## Quick Start (20 minutes)

```bash
# 1. Install dependencies
bundle install

# 2. Generate API key (see step 1 below)
# Download .p8 file → fastlane/Keys/

# 3. Create .env with credentials (see step 2 below)
cp fastlane/.env.default fastlane/.env
# Edit with your API key credentials

# 4. Verify setup
fastlane tests        # Should run without prompts
fastlane sync_certs   # Should sync without prompts
fastlane beta         # Should build & upload without prompts
```

If you get password prompts → Follow step 1 below.

---

## Step 1: Generate App Store Connect API Key

**Why?** Eliminates Apple ID password prompts entirely. More secure.

### 1.1 Create API Key
1. Go to https://appstoreconnect.apple.com/access/api
2. Click "Integrations" → "Generate a Key"
3. Give it a name (e.g., "Fastlane UFree")
4. Set Access Level to "Admin"
5. Click "Generate"

### 1.2 Download & Save
1. Click the key you just created
2. Download the `.p8` file
3. Save to `fastlane/Keys/AuthKey_XXXXXXXXXX.p8`

**Important:** Keep this file secure. Never commit to Git.

### 1.3 Note Your Credentials
You'll need two pieces of info:
- **Key ID:** Shown in the key list (e.g., `87PFYWC45Y`)
- **Issuer ID:** Shown at top of page (e.g., `b69096cf-7844-40b1...`)

---

## Step 2: Create .env File

**What:** File containing your API key credentials

**Where:** `fastlane/.env` (do NOT commit)

### 2.1 Copy Template
```bash
cp fastlane/.env.default fastlane/.env
```

### 2.2 Fill in Values
Edit `fastlane/.env`:
```env
# App Store Connect API Key
ASC_KEY_ID=YOUR_KEY_ID
ASC_ISSUER_ID=YOUR_ISSUER_ID
ASC_KEY_PATH=/Users/YourName/Documents/Development/.../fastlane/Keys/AuthKey_XXXXXXXXXX.p8

# Match password (certificate encryption)
MATCH_PASSWORD=your_secure_password

# Optional: Firebase
FIREBASE_APP_ID=1:639000000000:ios:a1b2c3d4e5f6g7h8i9j0
FIREBASE_GROUPS=internal-testers
```

**Note:** `ASC_KEY_PATH` must be ABSOLUTE (use full path, not `./fastlane/Keys/`)

### 2.3 Verify Protection
```bash
# Confirm .env is protected
grep "\.env" fastlane/.gitignore
# Should show: .env

# Confirm .p8 file is protected
grep "\.p8" fastlane/.gitignore
# Should show: *.p8 or Keys/
```

If `.env` or `.p8` not protected, add them to `.gitignore` manually.

---

## Step 3: Update Appfile

**Current issue:** `apple_id()` and `itunes_connect_id()` trigger credential prompts.

**Fix:** Remove these lines from `fastlane/Appfile`

### Before:
```ruby
app_identifier("com.khangvu.UFree")
apple_id("khang.vu.studio91@gmail.com")  # ← REMOVE
team_id("SNUXAG727V")
itc_team_id("SNUXAG727V")
itunes_connect_id("kmvu91@gmail.com")    # ← REMOVE
```

### After:
```ruby
app_identifier("com.khangvu.UFree")
team_id("SNUXAG727V")
itc_team_id("SNUXAG727V")

# API key authentication used instead (see .env)
```

---

## Step 4: Verify Setup Works

### 4.1 Test Certificate Sync
```bash
fastlane sync_certs
```

**Expected output:**
```
[✓] Certificates already exist
[✓] Profiles already exist
[✓] No prompts for password
```

**If you get prompted:** Check `ASC_KEY_PATH` is absolute and file exists.

### 4.2 Test Unit Tests
```bash
fastlane tests
```

Should run 206+ tests without prompts.

### 4.3 Test Full Distribution
```bash
fastlane beta
```

Should:
- ✅ Run 206+ tests
- ✅ Sync certificates
- ✅ Build IPA
- ✅ Upload to TestFlight
- ❌ No password prompts anywhere

---

## Security Checklist

Before committing to Git:

```bash
# 1. Verify .env is NOT tracked
git status | grep -i ".env"
# Should be empty

# 2. Verify .p8 files are NOT tracked
git status | grep -i ".p8"
# Should be empty

# 3. Verify no secrets in staged files
git diff --cached fastlane/ | grep -i "password\|token\|key"
# Should be empty (except AuthKey in comments)

# 4. Verify Appfile has no credentials
grep -E "apple_id\(|itunes_connect" fastlane/Appfile
# Should be empty or commented
```

---

## File Checklist

### Never Commit ❌
- `fastlane/.env` (credentials)
- `fastlane/Keys/*.p8` (API key file)
- `fastlane/.fastlane_user` (session)
- `fastlane/builds/` (artifacts)
- `fastlane/test_results/` (output)

### Always Commit ✅
- `fastlane/Fastfile` (automation code)
- `fastlane/Appfile` (app config)
- `fastlane/Matchfile` (certificate config)
- `fastlane/.env.default` (template)
- `fastlane/.gitignore` (protection rules)
- `fastlane/Docs/` (documentation)

---

## Troubleshooting

### "Certificate not found"
```bash
# Verify .env and API key are correct
fastlane sync_certs
```

### "Git repo error" (Bitbucket)
Ensure match certificate repository exists and you have access:
```bash
git clone git@bitbucket.org:ufree-certificates/ios-certs.git
```

### "Passphrase invalid"
Check `MATCH_PASSWORD` in `.env` matches what you set during `fastlane match init`.

### ".env file not found"
```bash
# Create it from template
cp fastlane/.env.default fastlane/.env
# Fill in your credentials
```

---

## Next Steps

1. ✅ Follow steps 1-4 above (20 minutes)
2. ✅ Run `fastlane sync_certs` (verify no prompts)
3. ✅ Run `fastlane beta` (full distribution)
4. 📖 Read **DISTRIBUTION.md** for detailed workflows
5. 📖 Read **REFERENCE.md** for commands & troubleshooting

---

## Common Questions

**Q: Where do I get the MATCH_PASSWORD?**
A: You create it when you first run `fastlane match appstore`. It's just a passphrase you choose to encrypt certificates.

**Q: Can I share the .p8 file?**
A: No. Keep it private like a password. Only share MATCH_PASSWORD.

**Q: What if I lose the .p8 file?**
A: Download it again from App Store Connect (you can have multiple keys).

**Q: Do I need the API key for local development?**
A: Yes. It eliminates prompts and is required for CI/CD.

---

**Date:** January 29, 2026 | **Version:** 1.0 | **Status:** Tested & Working
