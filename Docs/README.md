# UFree documentation

This is the documentation hub for UFree. Start with the guide that matches your role instead of reading the repository history or engineering material first.

## Choose your path

| Audience or goal | Start here | Then use |
|---|---|---|
| Founder, product partner, or TestFlight participant | [Product overview](PRODUCT_OVERVIEW.md) | [Operations guide](OPERATIONS_GUIDE.md) for the pilot and release process |
| Developer joining the app | [Engineering guide](ENGINEERING_GUIDE.md) | [Testing guide](TESTING_GUIDE.md) and [working conventions](AGENTS.md) |
| QA or release owner | [Testing guide](TESTING_GUIDE.md) | [Operations guide](OPERATIONS_GUIDE.md) |
| Developer fixing an environment, build, signing, or Firebase issue | [Troubleshooting runbook](TROUBLESHOOTING_RUNBOOK.md) | The relevant section of the engineering or operations guide |
| Someone researching prior decisions | [Sprint history](SPRINT_HISTORY.md) | Current guides take priority over history |

## Current documentation map

| File | Purpose | Primary audience |
|---|---|---|
| [`../README.md`](../README.md) | Short project introduction and entry point | Everyone |
| [`PRODUCT_OVERVIEW.md`](PRODUCT_OVERVIEW.md) | Problem, product loop, privacy promises, pilot success measures, and roadmap boundaries | Non-technical stakeholders |
| [`ENGINEERING_GUIDE.md`](ENGINEERING_GUIDE.md) | Architecture, local setup, security, deep links, and code conventions | Engineers |
| [`TESTING_GUIDE.md`](TESTING_GUIDE.md) | Automated tests, manual smoke testing, and release sign-off | Engineering and QA |
| [`OPERATIONS_GUIDE.md`](OPERATIONS_GUIDE.md) | Firebase deployment boundaries, Fastlane, TestFlight, monitoring, and pilot operations | Release owners |
| [`TROUBLESHOOTING_RUNBOOK.md`](TROUBLESHOOTING_RUNBOOK.md) | Symptom-based recovery steps | Engineers and release owners |
| [`AGENTS.md`](AGENTS.md) | Concise repository working conventions for coding assistants and contributors | Contributors |
| [`SPRINT_HISTORY.md`](SPRINT_HISTORY.md) | Compact record of completed milestones | Project team |

## Source-of-truth rules

- Current guides describe how the project should be run today.
- `Fastfile`, GitHub workflows, Firebase configuration, and the Xcode project are the implementation source of truth for automation and deployment behavior.
- Sprint history records why work happened; it is not a replacement for current operating instructions.
- Generated Fastlane documentation in `fastlane/README.md` is intentionally left alone and should not be used as the project guide.

## Recent consolidation

The previous start page, improvement plan, TestFlight checklist, and three overlapping Fastlane manuals were folded into the guides above. Old internal links now point to a current document or were removed with the retired document.