# Analytics events

Catalog from `AnalyticsManager` / `AnalyticsEvent`. Firebase Analytics event names are listed with parameters (no PII — no UIDs or raw phones).

| App enum | Firebase event | Parameters |
|---|---|---|
| `nudgeSent(type:)` | `nudge_performed` | `nudge_type` (`single` / `batch`), `timestamp` |
| `friendRequestSent(source:)` | `friend_request_sent` | `source` (e.g. `contact_sync`, `qr_code`, `deep_link`, `manual`), `timestamp` |
| `searchPerformed(success:)` | `phone_search` | `found_match` (0/1), `timestamp` |
| `availabilityUpdated(status:)` | `status_change` | `new_status`, `timestamp` |
| `heatmapViewed(friendCount:)` | `heatmap_viewed` | `friend_count`, `timestamp` |
| `handshakeCompleted(duration:)` | `handshake_completed` | `duration_seconds`, `timestamp` |
| `appLaunched` | `app_launched` | `timestamp` |
| `linkOpened(route:)` | `link_opened` | `route` (`notification` / `profile` / `unknown`), `timestamp` |
| `timeToFirstFriend(seconds:)` | `time_to_first_friend` | `seconds`, `timestamp` |
| `timeToFirstFreeMark(seconds:)` | `time_to_first_free_mark` | `seconds`, `timestamp` |
| `nudgeReplySent(response:)` | `nudge_reply_sent` | `response`, `timestamp` |
| `nudgeReplyReceived(response:)` | `nudge_reply_received` | `response`, `timestamp` |
| `d7Reopen(daysSinceActivity:)` | `d7_reopen` | `days_since_activity`, `timestamp` |
| `onboardingChecklistShown` | `onboarding_checklist_shown` | `timestamp` |
| `onboardingStepCompleted(step:)` | `onboarding_step_completed` | `step` (`invite` / `free_day` / `handshake`), `timestamp` |
| `onboardingChecklistDismissed` | `onboarding_checklist_dismissed` | `timestamp` |
| `missionChipTapped` | `mission_chip_tapped` | `timestamp` |
| `weekendCTAAccepted` | `weekend_cta_accepted` | `timestamp` |
| `weekendCTADismissed` | `weekend_cta_dismissed` | `timestamp` |
| `localNotificationOpened(kind:)` | `local_notification_opened` | `kind` (`weekend_planning`), `timestamp` |
| `hangoutConfirmed` | `hangout_confirmed` | `timestamp` |
| `hangoutConfirmDismissed` | `hangout_confirm_dismissed` | `timestamp` |
| `bondMilestoneReached(count:)` | `bond_milestone_reached` | `count` (1 / 5 / 10), `timestamp` |

Collection is disabled in DEBUG builds (`UFreeApp` / `AppDelegate`). Prefer `AnalyticsManager.log(...)` over calling Firebase Analytics directly from ViewModels.
