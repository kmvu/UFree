# UFree product strategy

Problem brief, pilot focus, and a post-launch monetization plan. For the short stakeholder summary, see [Product overview](PRODUCT_OVERVIEW.md).

---

## 1. Product brief

### Purpose

Help people stay connected with **family, friend circles, and anyone they choose** — by making it easy to see when others are free and to nudge a hang **with consent**, not awkward asking.

### Problem statement

Busy people who care about each other still miss hangs — not because they do not want to meet, but because finding mutual free time is awkward, slow, and one-sided.

Asking “when are you free?” creates friction. Waiting for others to propose something creates silence. Calendars are for work. Chat is for conversation. There is no lightweight, consent-based way to see who in my circle is free and gently invite them out.

**One-line promise**

> UFree helps people who already care about each other see when they’re free and nudge a hang — without the scheduling dance.

### Who it is for

| Circle | Pain in their words | What “win” looks like |
|---|---|---|
| **Friends** | “We all want to hang, but nobody knows who’s free this week.” | A weekend plan happens from a nudge |
| **Family** | “I want to visit or check in without burdening them.” | A free window is visible before asking |
| **Chosen people** | “I intend to see them more, but intention never becomes a plan.” | One real hang that would have stayed “sometime soon” |

UFree is for **small, intentional graphs** — not audiences, followers, or strangers.

### Job to be done

When I want time with someone I care about, I want to **know how free they are** and **nudge them within mutual consent**, so we actually connect offline — without feeling pushy or waiting forever.

### Core loop (MVP)

```text
Connect (mutual handshake)
    → Mark free (full day or window)
    → See who’s free
    → Nudge a specific day
    → Reply (I’m in / Maybe / Busy)
    → Hang happens
    → Return next weekend
```

### In scope now

- Mutual friend handshake (QR, link, phone search; contacts optional)
- Personal availability for the week (including partial-day windows)
- “Who’s free?” among connected friends
- Day-specific nudge + reply
- In-app real-time updates while both people are active
- Privacy: no schedule sharing until both accept

### Explicit non-goals (for now)

| Not building yet | Why |
|---|---|
| Public discovery / followers | Wrong graph; breaks trust |
| Group chat or social feed | Dilutes the coordination job |
| Full calendar import / work scheduling | Different product |
| Always-on location | Creepy; not required for free/busy |
| Background push & weekend digests | Cost + complexity; deferred until pilot proves value |
| Viral stranger growth | Product is useless (and wrong) without chosen people |

### Positioning (north star)

```text
Purpose:     Stay connected with people I choose
Pain:        I can’t see how free they are
Behavior:    Consent-based nudge → real hang
Promise:     Less awkward asking, more actual time together
```

**Not:** a social network, a Locket clone, or a calendar.  
**Is:** a private free-time radar for intentional connection.

### Success metrics

| Horizon | Metric | Pass signal |
|---|---|---|
| **First hang** | Seeded pair completes connect → free → nudge → reply | At least one real meetup attributed to UFree |
| **Retention** | Pair reopens the following Friday without a founder reminder | ≥ 50% of seeded pairs |
| **Quality** | “Did this feel pushy?” qualitative check | Majority say no / “felt natural” |
| **Anti-metric** | DAU vanity without hangs | Do not optimize opens alone |

### Pilot decision rule

Do **not** broaden to a public App Store launch until at least half of seeded pairs:

1. complete the core path in one weekend, and  
2. reopen the following Friday without a founder reminder.

Operational details live in [Operations guide](OPERATIONS_GUIDE.md).

### Hypothesis

If people in my circle can see each other’s free windows and send a one-tap nudge, we will plan hangs more often than by chat alone — without feeling pushy.

---

## 2. Monetization plan (after launch)

Monetization should follow **proof of hangs**, not precede it. Charge only when UFree is already the default “who’s free?” tool for a circle — and never gate the core private loop that makes the product valuable.

### Principles

1. **Core loop stays free forever for small circles** — connect, mark free, see friends, nudge, reply.  
2. **Pay for scale, comfort, and power** — not for the right to hang with family.  
3. **No ads in intimate surfaces** — availability and nudges must never feel like a feed for sale.  
4. **Align revenue with infrastructure cost** — push, SMS, and heavy sync are the real bill drivers; premium can fund them.  
5. **Turn on billing only after retention is real** — otherwise you price a habit that does not exist yet.

### Phase model

| Phase | When | Monetization posture |
|---|---|---|
| **0 — Pilot** | Now → first retained pairs | $0. Spark / free tier. Validate hangs. |
| **1 — Soft launch** | Repeat use in several circles | Still free. Optional tip jar / “Support UFree” only if it feels natural. |
| **2 — Sustainability** | Clear retention + Firebase/Apple costs rising | Introduce **UFree Plus** subscription. |
| **3 — Expansion** | Stable Plus base | Add household / circle plans; light B2B only if pulled. |

### What stays free ( forever )

These are the trust contract — do not paywall them:

- Mutual handshake with people you choose  
- Marking your own availability  
- Seeing free/busy for connected friends (reasonable friend-list size)  
- Sending and replying to nudges  
- Basic notification inbox while in-app  

If the free tier cannot complete a hang, the product fails the purpose statement.

### UFree Plus (primary model)

**Shape:** monthly + annual subscription (individual first; household later).

| Plus benefit | Why people pay | Notes |
|---|---|---|
| **Background push + weekend digest** | “Tell me when we’re both free” without opening the app | Funds Blaze / Functions / APNs |
| **Larger circles** | Free: e.g. up to ~20 connections; Plus: higher cap | Keeps free tier intimate; Plus for busy social hubs |
| **Richer availability** | Recurring “usually free Thu evenings”, templates | Power users / parents / organizers |
| **Widgets / home-screen “who’s free”** | Habit surface (Locket-like presence for time) | Strong retention lever |
| **Smart overlap insights** | “3 friends free Saturday afternoon” | Utility, not social vanity |
| **Priority / multi-device sync polish** | Reliability when life depends on it | Keep free “good enough” |

**What not to put behind paywall early**

- Accepting a family member’s invite  
- Sending the first nudge  
- Basic free/busy for a small friend list  

### Secondary models (later, optional)

| Model | Fit | Risk |
|---|---|---|
| **Household / family plan** | One subscription for parents + kids / siblings | Good alignment with purpose; do after individual Plus works |
| **Circle organizer (friend-group lead)** | Extra seats + digest for a named group | Avoid turning into team software UX |
| **Tips / “buy me a coffee”** | Soft launch goodwill | Unreliable; not a business plan |
| **B2B “team social”** | Companies wanting informal hang coordination | Easy to dilute brand; only if inbound demand is strong |
| **Ads** | — | **Avoid** in availability/nudge surfaces |

### Pricing sketch (directional, not final)

Finalize after pilot interviews; use as a planning range only:

| Plan | Rough monthly | Includes |
|---|---|---|
| Free | $0 | Core loop, small circle, in-app updates |
| Plus | ~$2–5 / month (or ~$20–40 / year) | Push, widget, larger circle, templates, insights |
| Family | ~1.5–2× Plus | Up to N household members |

Bias **low price, high trust**. This is intimacy software, not enterprise SaaS.

### When to introduce paid

Turn on Plus only when **most** of these are true:

- [ ] ≥ 50% of pilot pairs retain week-over-week without coaching  
- [ ] Push (or widget) is shipping and clearly valued in interviews  
- [ ] Free-tier Firebase/Apple cost is no longer negligible  
- [ ] You can explain Plus in one sentence without sounding like a lock on friendship  

Until then, stay free and measure hangs.

### Cost ↔ revenue alignment

| Cost driver | Free posture | Paid posture |
|---|---|---|
| Firestore reads (contact sync) | Rate-limit; prefer QR/phone | Higher limits on Plus |
| Cloud Functions + FCM | Off on Spark pilot | On for Plus (push/digest) |
| Phone Auth SMS | Prefer anonymous + hash for pilot; SMS later carefully | May be Plus-assisted or region-limited |
| Support / reliability | Best-effort | Plus gets priority fixes |

### Monetization anti-patterns

- Paywalling the second friend invite  
- Ads next to “Mom is free Sunday”  
- Dark patterns that guilt people into Plus to see family  
- Charging before anyone has hung out because of the app  

### Suggested narrative when Plus launches

> UFree stays free for the people you love. Plus is for richer signals, reminders, and bigger circles — so staying close costs less effort, not more awkwardness.

---

## 3. How this ties back to launch

| Now | Next | Later |
|---|---|---|
| Prove the problem statement with real hangs | Soft-launch free; optional support | Plus when retention + push/widget demand are clear |
| Stay on free Firebase as long as possible | Watch cost hotspots (sync, functions) | Let Plus fund always-on features |

**Founder checklist**

1. Run the dyad / small-circle pilot per [Product overview](PRODUCT_OVERVIEW.md) and [Operations guide](OPERATIONS_GUIDE.md).  
2. Collect hang stories (“We met because…”).  
3. Only then design Plus screens and App Store pricing.  

---

**Last updated:** August 2, 2026  
**Status:** Strategy draft for pilot → soft launch → monetization
