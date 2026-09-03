# Firestore schema (from `firestore.rules`)

High-level collections used by UFree. Rules enforce owner / friend / participant access; prefer `get` over collection `list` for discovery docs.

```text
┌─────────────────────────────────────────────────────────────────┐
│ publicProfiles/{userId}                                         │
│   displayName                                                   │
│   get: signed-in · create/update/delete: owner                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ phoneDirectory/{hash}                                           │
│   uid                                                           │
│   get: signed-in · create: claim own uid · no update · delete:  │
│   owner of claim                                                │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ users/{userId}                                                  │
│   profile fields + friendIds[]                                  │
│   get: owner or listed friend · list: denied                    │
│                                                                 │
│   ├── availability/{date}   (yyyy-MM-dd)                        │
│   │     status / timeBlocks · read: owner|friend · write: owner │
│   │                                                             │
│   └── notifications/{docId}                                     │
│         type friendRequest|friendAccepted|nudge|nudgeReply      │
│         read/update/delete: owner · create: signed-in sender    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ friendRequests/{fromId_toId}                                    │
│   fromId, toId, fromName, status pending|accepted|declined      │
│   create: sender · read: participants · update: recipient       │
│   delete: either participant                                    │
└─────────────────────────────────────────────────────────────────┘
```

Availability day keys and nudge `targetDateString` use UTC `yyyy-MM-dd` (`DateFormatter.yyyyMMdd`).
