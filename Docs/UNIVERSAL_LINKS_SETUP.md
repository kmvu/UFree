# Universal Links Setup Guide

**Status:** ✅ Implementation Ready | **iOS Target:** 14.0+ | **Feature:** Deep linking from notifications/emails

---

## Overview

Universal Links enable iOS to open app content directly from URLs. Users tap a notification or link → app opens to specific content (e.g., notification detail).

**Key Benefits:**
- ✅ No SMS codes, web fallback required
- ✅ Works from notifications, emails, web pages
- ✅ Seamless UX (app opens, no Safari detour)
- ✅ Analytics tracking via App Search Console

---

## Implementation Status

### Code Changes ✅

**RootView.swift - Deep Link Handler:**
```swift
.onOpenURL { url in
    handleUniversalLink(url)
}

// DeepLink enum parses URLs:
// https://ufree.app/notification/{senderId}
// https://ufree.app/profile/{userId}
```

**NotificationViewModel.swift:**
- Added `@Published var highlightedSenderId: String?`
- Allows deep link to highlight specific notification

### Files Modified

- `UFree/Features/Root/RootView.swift` - Added `.onOpenURL` + `DeepLink` parser
- `UFree/Features/Notifications/NotificationViewModel.swift` - Added `highlightedSenderId`

---

## Setup Steps (One-Time)

### 1. Create AASA File (Your Server)

Save as: `/.well-known/apple-app-site-association` (no file extension)

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "com.apple.developer.team.TEAMID.com.khangvu.UFree",
        "paths": ["/notification/*", "/profile/*"]
      }
    ]
  }
}
```

**Replace:**
- `TEAMID` - From Apple Developer account (e.g., `SNUXAG727V`)
- `/notification/*` - Deep link paths your app handles

### 2. Host AASA File

```bash
# Your domain must be HTTPS
https://ufree.app/.well-known/apple-app-site-association

# Test it works:
curl -I https://ufree.app/.well-known/apple-app-site-association
# Should return: 200 OK, Content-Type: application/json
```

**IMPORTANT:** No redirects. File must be directly accessible (no trailing slash).

### 3. Update Info.plist

Add Associated Domains (Xcode UI or XML):

**Via Xcode:**
1. Select UFree target → Signing & Capabilities
2. Click "+ Capability"
3. Add "Associated Domains"
4. Add domain: `applinks:ufree.app`

**Via XML (Info.plist):**
```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSExceptionDomains</key>
  <dict>
    <key>ufree.app</key>
    <dict>
      <key>NSIncludesSubdomains</key>
      <true/>
      <key>NSExceptionAllowsInsecureHTTPLoads</key>
      <false/>
    </dict>
  </dict>
</dict>

<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:ufree.app</string>
</array>
```

### 4. Update Entitlements

File: `UFree/UFree.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN">
<plist version="1.0">
<dict>
  <key>com.apple.developer.associated-domains</key>
  <array>
    <string>applinks:ufree.app</string>
  </array>
  <!-- Other entitlements... -->
</dict>
</plist>
```

**Xcode Auto-Generate:** Building after adding "Associated Domains" capability auto-generates this.

---

## Testing Deep Links

### Local Testing (Without AASA)

```swift
// Simulate in Xcode console:
let url = URL(string: "https://ufree.app/notification/user123")!
UIApplication.shared.open(url)
```

### Physical Device Testing (With AASA)

1. Deploy AASA file to `https://ufree.app/.well-known/apple-app-site-association`
2. Build & run on device
3. Wait 24-48 hours (Apple caches AASA)
4. Test via:
   - Notes app: Create a note with link → Tap it
   - Safari: Navigate to link → Tap "Open in App"
   - Notification: Send Firebase notification with link

### Verify AASA Linkage

```bash
# Check Apple's linkage validation
# https://developer.apple.com/app-search/manage-apps/

# Or test locally:
curl -H "User-Agent: iOS/14.0" https://ufree.app/.well-known/apple-app-site-association
```

---

## Deep Link Paths

### Current Paths

| Path | Handler | Example |
|------|---------|---------|
| `/notification/{userId}` | Highlight notification from user | `/notification/abc123` |
| `/profile/{userId}` | Show friend profile (future) | `/profile/abc123` |

### Adding New Paths

1. **Update AASA file:**
   ```json
   "paths": ["/notification/*", "/profile/*", "/new-feature/*"]
   ```

2. **Update DeepLink enum (RootView.swift):**
   ```swift
   enum DeepLink {
       case newFeature(param: String)
       
       static func parse(_ url: URL) -> DeepLink {
           // Add case:
           case "new-feature":
               return .newFeature(param: parameter)
       }
   }
   ```

3. **Update handler (MainAppView):**
   ```swift
   case .newFeature(let param):
       // Handle navigation
   ```

---

## Firestore & Notifications

### Send Deep Link in Notification

```swift
// When creating notification document in Firestore:
let notification = [
    "senderId": userId,
    "recipientId": recipientId,
    "type": "nudge",
    "deepLinkUrl": "https://ufree.app/notification/\(userId)"
]
```

### Firebase Cloud Messaging (Future)

```json
{
  "message": {
    "token": "device_token_here",
    "notification": {
      "title": "New Nudge!",
      "body": "Alex nudged you",
      "click_action": "https://ufree.app/notification/user123"
    }
  }
}
```

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Deep link not opening app | AASA file not accessible | Verify `https://ufree.app/.well-known/apple-app-site-association` returns 200 |
| App opens but doesn't navigate | DeepLink parsing error | Check URL format matches enum cases |
| 24-48 hour delay | Apple caching | Normal. Device will validate AASA on first visit, then cache. |
| "Not verified" in App Search Console | Team ID mismatch | Ensure `TEAMID` in AASA matches Apple Developer account |

---

## Security Considerations

- ✅ AASA file signed by Apple (verified during install)
- ✅ Only URLs in AASA paths are opened in-app (others use Safari fallback)
- ✅ No sensitive data in URLs (use `senderId`, not tokens)
- ✅ Validate incoming URLs in DeepLink parser

**Best Practice:**
```swift
// Validate URL format before parsing
guard url.scheme == "https",
      url.host == "ufree.app" else {
    return .unknown
}
```

---

## Monitoring

### In Firebase Analytics

Track deep link opens:
```swift
case .notification(let senderId):
    AnalyticsManager.log(.deepLinkOpened, parameters: [
        "linkType": "notification",
        "senderId": senderId
    ])
```

### In App Search Console

- Monitor impression CTR for your domain
- Track which paths are most used
- Optimize based on user behavior

---

## Related Docs

- **SMOKE_TEST_CHECKLIST.md** - Scenario 6 covers deep link testing
- **README.md** - Feature list now includes Universal Links
- **AGENTS.md** - Deep link handling pattern

---

**Last Updated:** January 29, 2026 | **Status:** ✅ Ready for Implementation
