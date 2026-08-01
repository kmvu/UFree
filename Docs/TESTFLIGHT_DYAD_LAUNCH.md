# TestFlight Dyad Launch Checklist

**Goal:** Prove UFree is a weekend hangout radar people reopen — before App Store spray.

## Locked decisions

- Audience: close friends, weekends
- Auth: anonymous + phone-hash OK for TestFlight
- North star: weekly active dyads with ≥1 nudge reply
- Defer: Group Chat, Shared Calendars, public discovery

## Pre-flight (founder, free)

Before recruiting real pairs, prove the loop on Spark with DEBUG dual-sim:

1. Deploy rules/indexes only (already done if console shows current rules):  
   `firebase deploy --only firestore:rules,firestore:indexes`
2. Run UFree on **two iOS Simulators** (DEBUG).
3. LoginView → Developer Tools → **User 1** / **User 2** (Firebase test phones; no SMS cost).
4. Walk the uncoached path below with both apps **foregrounded** (no CF push on Spark).
5. Confirm Notification Center shows day-scoped nudge + I’m in reply both ways.

Only then ship TestFlight and seed real dyads.

## Seed plan

1. Recruit **2–3 real friend pairs** (people who already hang out).
2. Install TestFlight builds on both devices (`fastlane beta` — Apple/TestFlight only; no Firebase Blaze).
3. Do **not** coach mid-flow — only give the one-liner: “Invite each other, mark weekend free, nudge a day.”
4. Expand to **5–10 person clusters** only after the first pairs complete the loop.

## Uncoached success path

Invite → mutual accept → mark free → see each other on Who’s Free → day-scoped nudge → I’m in reply → reopen next Friday.

## Success bar

- ≥50% of seeded dyads complete the path in one weekend
- ≥50% reopen the following Friday without founder ping
- Do **not** open public App Store until that bar is hit

## Founder ops log

| Pair | Invited | Connected | Free marked | Nudge + reply | Friday reopen | Notes |
|------|---------|-----------|-------------|---------------|---------------|-------|
| 1 | | | | | | |
| 2 | | | | | | |
| 3 | | | | | | |

## Deploy reminders (cost-safe)

**Stay on Spark (no billing) for TestFlight dyads.** Cloud Functions require Blaze even if usage would be tiny — do **not** deploy `functions/` until you deliberately accept a billing account.

```bash
# Safe on free tier:
firebase deploy --only firestore:rules,firestore:indexes
fastlane beta
```

| Feature | Without Cloud Functions (current) |
|---------|-----------------------------------|
| In-app friend request / nudge / reply | Works via Firestore listeners |
| Push when app is backgrounded/killed | **Not available** until CF + Blaze |
| Thu/Fri weekend digest cron | **Not available** — use founder ping or in-app weekend CTA instead |

Code for `sendPushNotification` / `sendWeekendDigest` can stay in `functions/index.js` as a future option; leave undeployed.
