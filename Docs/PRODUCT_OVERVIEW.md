# UFree product overview

## In one sentence

UFree helps close friends turn “Are you free?” into a simple plan by showing when they are available and making it easy to nudge each other about a specific day.

## The problem we are solving

Making casual plans often fails because people do not know who is free, asking feels repetitive, and a message can be forgotten. UFree is not a public social network or a calendar replacement. It is a private, lightweight coordination tool for people who already know each other.

## How the product works

1. **Connect with a friend.** A person can share a link or QR code, search by phone number, or optionally match contacts. A connection is only created after the recipient accepts.
2. **Mark availability.** People choose whether they are free all day or for part of a day. Leaving a day unset means “unknown,” not “busy.”
3. **See who is free.** The “Who’s Free?” view shows connected friends with an available window for the selected day.
4. **Make a small ask.** A person sends a nudge for that day. The recipient can answer **I’m in**, **Maybe**, or **Busy**.
5. **Return next weekend.** The product is successful when friends reopen it without being coached to repeat the loop.

## Privacy promises

- UFree is designed for people who already know each other, not public discovery.
- Connection requests require mutual consent before schedule information is shared.
- Contact matching uses phone hashes rather than uploading a raw contact list for browsing.
- Phone search is designed as a private lookup, not a public directory.
- Notification and link behavior should reveal only the minimum useful context.

## Current TestFlight pilot

The project is validating one behavior: whether real friend pairs use UFree to make weekend plans and come back the following week.

**Pilot audience:** 2–3 friend pairs who already spend time together  
**First instruction:** “Invite each other, mark the weekend free, and nudge a day.”  
**Uncoached success path:** connect → mark free → see each other → nudge → reply → reopen next Friday  

**Post-accept quest (in-app):** After Accept, a short “Connected” toast branches to the next mission — weekend free prompt if needed, otherwise Who’s Free with a dismissible mission chip (“see when you’re both free / nudge a day”). The same path runs from the notification inbox and Add Friends.

### Decision rule

Do not broaden to a public App Store launch until at least half of seeded pairs:

- complete the core path during one weekend, and
- reopen the following Friday without a founder reminder.

Use the [operations guide](OPERATIONS_GUIDE.md#testflight-dyad-pilot) for the recruitment log, release steps, and practical limitations.

## What is in scope now

- Personal availability for a week, including partial-day windows
- Friend connections through a mutual handshake
- Day-specific nudges and replies
- In-app, real-time updates while participants are active
- Product analytics for onboarding, first connection, first availability mark, nudges, replies, and reopening

## Explicitly deferred

These are not current pilot commitments:

- Group chat
- Shared calendars
- Calendar import (EventKit)
- Public discovery
- Background push notifications and scheduled weekend reminders

The repository contains Cloud Functions for push and a weekend digest, but Firebase Functions are not wired into the current Firebase configuration and are intentionally not deployed for the Spark-tier pilot. That means the pilot relies on in-app updates while both participants have the app open.

## What stakeholders should review

| Question | Where to look |
|---|---|
| What is UFree trying to prove? | This document |
| How do we run the pilot or publish a TestFlight build? | [Operations guide](OPERATIONS_GUIDE.md) |
| What quality checks happen before a release? | [Testing guide](TESTING_GUIDE.md) |
| How is the app built? | [Engineering guide](ENGINEERING_GUIDE.md) |
