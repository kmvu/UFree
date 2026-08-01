# UFree

UFree helps close friends make weekend plans with less back-and-forth. Each person marks when they are free, friends can see shared availability, and either person can send a lightweight nudge for a specific day.

## Start here

| If you are... | Read |
|---|---|
| A founder, tester, partner, or other non-technical stakeholder | [Product overview](Docs/PRODUCT_OVERVIEW.md) |
| Running the current TestFlight pilot | [Operations guide → TestFlight pilot](Docs/OPERATIONS_GUIDE.md#testflight-dyad-pilot) |
| A developer joining the project | [Engineering guide](Docs/ENGINEERING_GUIDE.md) |
| Testing or validating a release | [Testing guide](Docs/TESTING_GUIDE.md) |
| Looking for a specific document | [Documentation hub](Docs/README.md) |

## What the current app does

- Lets a person record full-day or partial availability.
- Connects friends only after a mutual request, using a link, QR code, phone search, or optional contact matching.
- Shows which connected friends have an available window for a selected day.
- Supports day-specific nudges and replies: **I’m in**, **Maybe**, or **Busy**.
- Keeps availability usable offline first, then synchronizes it in the background when a connection is available.

## Current pilot focus

The active product question is whether pairs of real friends return to UFree to make weekend plans. The TestFlight pilot is intentionally limited to that loop:

**Connect → mark free → see each other → nudge → reply → reopen next Friday**

Group chat, shared calendars, and calendar import are deliberately deferred until the pilot shows repeat use. Background push notifications and the scheduled weekend digest are also not part of the current Spark-tier pilot; the app’s in-app updates work while participants have the app open.

## Documentation principles

The repository has one path for each audience. The product overview uses plain language; engineering, testing, and release details live in their own guides. The [documentation hub](Docs/README.md) is the source of truth for navigation.
