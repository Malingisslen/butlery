# Notification Analytics — Art. 30 Record & Export Treatment

GDPR Article 30 record of processing for the notification-analytics collections, and the
data-subject-access (Art. 15) export treatment. Companion to `account-subcollections-retention.md`, `family-data-retention.md` and
`audit-logs-retention.md`. Sources: BUT-1450 (2026-06-30), BUT-1956 / BUT-1957 (2026-09-02).

## Collections

| Collection | Scope field(s) | Contents | Purpose |
|---|---|---|---|
| `notification_history` | `userId` | The notification the user received: title/body (what they saw), type, sentAt | Deliver + render notifications; effectiveness correlation |
| `notification_batches` | `userId` | Batched-send bookkeeping | Batch/dedupe push delivery |
| `notification_engagement` | `userId` | Open/click events (`action`, timestamp) | Measure notification effectiveness |
| `notification_delivery` | `senderId`, `targetUserId` | Per-delivery log: notificationId, sender + target UID, category, type, status, sentAt | Delivery audit / debugging |
| `analytics/notifications/effectiveness` | `userId` | Per-notification correlation row: notificationId, userId, type, sentAt, wasOpened, openedWithinHours, correlatedAt | Measure whether a notification was opened |
| `users/{uid}/notifications` | path (no `userId` field) | The in-app row for a notification the user was sent: type, the text shown (`message` / `bodyShown`), win-back copy `variant` / `contextKey`, or the weekly digest's own activity counts | Deliver the win-back and weekly-digest notifications; win-back A/B attribution |

The last two were added to this record by BUT-1956 and BUT-1957 (2026-09-02), which are also the
tickets that first gave them an erasure route. Both had been written since their features shipped
and reached by nothing: no cascade step, no probe, no TTL. `analytics/notifications/summary/{date}`
is deliberately absent from this table — it is a uid-free daily aggregate, so Art. 17 does not
reach it and erasing a departed user changes no stored rate.

Note the near-collision that hid `users/{uid}/notifications` for so long: the top-level collection
`user_notifications` is a **different** collection, swept by a **different** function
(`deleteNotifications`).

## Lawful basis
- `notification_history`, `notification_batches`, `notification_delivery`: legitimate interest /
  contract — operating and delivering the notification service the user signed up for (Art. 6.1.b/f).
- `notification_engagement` and `analytics/notifications/effectiveness`: tied to the
  analytics/notification consent purpose (Art. 6.1.a).
- `users/{uid}/notifications`: legitimate interest / contract, as the delivery collections above —
  it is the in-app rendering of a notification the service sent.
- None of these contain Art. 9 special-category data.

## Retention
- Trimmed by the existing `cleanup-old-notifications` scheduled function (see `functions/src/cleanup/`).
  That function trims `notification_history` ONLY. `analytics/notifications/effectiveness` and
  `users/{uid}/notifications` have no trim and no TTL — they grow unbounded until the account is
  deleted, which is what makes the export's 500 cap and its `truncated` flag load-bearing rather
  than theoretical.
- Fully erased on account deletion by `deleteNotificationAnalytics` in
  `account-deletion-cascade.ts`, and verified post-deletion by `probeResidualData`
  (the three `userId`-scoped collections via the probe array; `notification_delivery` via a
  dedicated `senderId`/`targetUserId` probe — BUT-1450).
- `analytics/notifications/effectiveness`: erased by `deleteNotificationEffectiveness`
  (tier-1 step `notification_effectiveness`), verified by its own leg in `probeResidualData`.
  It has **no** TTL, so the cascade is the only thing that removes a row. Its writer,
  `correlateNotificationEffectiveness`, runs daily from in-memory pages, so a cascade landing
  mid-run can see a row written back after the sweep — which is what the probe leg reports
  (BUT-1956).
- `users/{uid}/notifications`: erased by `deleteUserSubcollections` (tier-2 step
  `user_subcollections`), verified by the `listCollections()` enumeration in `probeResidualData`.
  That enumeration replaced a hand-written include-list, so a subcollection added by a future
  feature is reported as residual rather than being invisible (BUT-1957).

## Art. 15 export treatment (BUT-1450, extended BUT-1957)
- `users/{uid}/notifications` is exported as its own `delivered_notifications` section
  (this needed a `firestore.rules` read block, added in the same change — rules do NOT cascade
  to subcollections, so without it the section returns a failure envelope for every user while
  reading as though the gap were closed)
  (`PreferencesExportManager.exportDeliveredNotifications`), capped at 500 most-recent with the
  same N+1 truncation probe as the other capped sections. It is deliberately a separate section
  from `notifications` (the top-level `user_notifications`) rather than merged into it: they are
  different collections, and one section covering two would hide which rows came from where.
  Fields are passed through unprojected — every one is the requester's own (the text they were
  shown, their own copy variant, counts of their own activity — a comment they authored may sit on someone else's recipe).
  **One exception, measured:** a win-back row whose `contextKey` is `ctx_friend_share` carries
  another user's NAME inside `message`/`bodyShown` — the copy resolver builds
  "<namn> delade ett recept med dig" from `sharedByDisplayName`. It is KEPT: the requester
  received and read that exact push text on their own device, so the export discloses nothing
  new, and redacting it would hand them a falsified copy of their own record. Decided on these
  facts alone, NOT by analogy to the conversations or shopping-list entries, which govern
  different collections. Chosen conservatively without asking Malin; stripping it is hers.
- `analytics/notifications/effectiveness` is **not** exported. It holds no content the user has not
  already received: notificationId, their own uid, and whether they opened it. Its human-readable
  counterpart is `notification_history`, which is exported in full. Recorded here rather than left
  implicit, because the export ⊇ erasure invariant below now has one deliberate exception.
- The four BUT-1450 collections are included in `DataExportService.exportUserData()`, ownership-scoped via
  `FirebaseDataExportRepository._guardSelfExport` (no cross-user read).
- High-volume collections are capped (history 2000 most-recent, delivery/engagement 1000, batches
  500) with a `truncated` flag surfaced in `export_metadata`.
- **Counterparty treatment:** the `notification_delivery` counterparty UID (`senderId` /
  `targetUserId`) is exported **as stored, not anonymised**. This was a deliberate decision
  (see `.claude/rules/accepted-deviations.md`, 2026-06-30): Art. 15(4) is a balancing test, not a
  blanket third-party redaction rule, and the export should reflect the user's own interaction
  data as they experienced it — consistent with mainstream exports. The human-readable notification
  is in `notification_history`, joined via `notificationId`. Bulk UID→name resolution is
  deliberately not performed (cost).

## DPIA note
Closing the export gap means a deleted user's export ⊇ what the cascade erases for these
collections (BUT-1396 invariant extended), with the single stated exception of
`analytics/notifications/effectiveness` above. No new special-category data is introduced. Two
third-party data points are exported, both assessed as proportionate under Art. 15(4): another
user's pseudonymous UID within the data subject's own delivery records (per the decision above),
and another user's NAME inside the text of a friend-share win-back notification the data
subject was themselves shown (BUT-1957 — see the export-treatment section).
