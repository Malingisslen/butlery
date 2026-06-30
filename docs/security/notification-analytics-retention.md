# Notification Analytics — Art. 30 Record & Export Treatment

GDPR Article 30 record of processing for the four notification-analytics collections, and the
data-subject-access (Art. 15) export treatment. Companion to `family-data-retention.md` and
`audit-logs-retention.md`. Source: BUT-1450 (2026-06-30).

## Collections

| Collection | Scope field(s) | Contents | Purpose |
|---|---|---|---|
| `notification_history` | `userId` | The notification the user received: title/body (what they saw), type, sentAt | Deliver + render notifications; effectiveness correlation |
| `notification_batches` | `userId` | Batched-send bookkeeping | Batch/dedupe push delivery |
| `notification_engagement` | `userId` | Open/click events (`action`, timestamp) | Measure notification effectiveness |
| `notification_delivery` | `senderId`, `targetUserId` | Per-delivery log: notificationId, sender + target UID, category, type, status, sentAt | Delivery audit / debugging |

## Lawful basis
- `notification_history`, `notification_batches`, `notification_delivery`: legitimate interest /
  contract — operating and delivering the notification service the user signed up for (Art. 6.1.b/f).
- `notification_engagement`: tied to the analytics/notification consent purpose (Art. 6.1.a).
- None of these contain Art. 9 special-category data.

## Retention
- Trimmed by the existing `cleanup-old-notifications` scheduled function (see `functions/src/cleanup/`).
- Fully erased on account deletion by `deleteNotificationAnalytics` in
  `account-deletion-cascade.ts`, and verified post-deletion by `probeResidualData`
  (the three `userId`-scoped collections via the probe array; `notification_delivery` via a
  dedicated `senderId`/`targetUserId` probe — BUT-1450).

## Art. 15 export treatment (BUT-1450)
- All four collections are included in `DataExportService.exportUserData()`, ownership-scoped via
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
collections (BUT-1396 invariant extended). No new special-category data is introduced. The only
third-party data point exported is another user's pseudonymous UID within the data subject's own
delivery records — assessed as proportionate under Art. 15(4) per the decision above.
