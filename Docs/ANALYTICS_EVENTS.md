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

Collection is disabled in DEBUG builds (`UFreeApp` / `AppDelegate`). Prefer `AnalyticsManager.log(...)` over calling Firebase Analytics directly from ViewModels.
