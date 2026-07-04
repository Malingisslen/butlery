# Scan — Role #23 Database Administrator / Data-layer Engineer

Date: 2026-06-27
Lens: Firestore indexes, query efficiency, cleanup/migration correctness, scheduled-job idempotency/cost, data integrity.
Owned paths: firestore.indexes.json, firestore.rules, functions/src/cleanup/**, functions/src/migrations/**, functions/src/scheduled/ping_sweeper.ts, functions/src/shared/{notification-send-events,scheduled-notifications}.ts

Dedup sources checked: tasks/_scan_dedup_titles.txt, .claude/linear-tracker.json, .claude/rules/accepted-deviations.md, dossier #23 watch-items.
Pre-existing (NOT re-flagged): BUT-430 (rating-stream denorm counter), BUT-463 (collectionGroup members safety), BUT-464 (friendUserIds array growth), BUT-955 (cap sharedWithUserIds), BUT-477 (presence TTL), BUT-1372 (cleanupSubcollection 10k pagination), BUT-1373 (chunk learned-aliases batch), BUT-1376 (paginate unbounded reads — ingredient triggers + analytics scans), BUT-478 (defensive .limit), equality-only-index deviation.

---

## PASS 1 — indexes, unbounded scans, cleanup correctness, migration safety

### NEW-1 [HIGH] Missing composite index for `ingredients` cleanup query — not equality-only, will FAILED_PRECONDITION
`cleanupDeletedIngredients` (cleanup-deleted-ingredients.ts:91-95) runs:
`ingredients.where("status","==","deleted").where("deletedAt","<",cutoff).limit(5000)`.
This is **equality + inequality on two different fields** → requires a composite index (`status ASC, deletedAt ASC`). It is NOT the accepted equality-only deviation (that covers multi-*equality* only; an inequality/range second field needs a composite).
There is **no `ingredients` entry anywhere** in firestore.indexes.json (verified: 0 matches). The admin stats query `getDeletedIngredientStats` (lines 192-197) adds `.where("status","==","deleted").orderBy("deletedAt","asc")` — same composite requirement.
Consequence: either (a) the scheduled function throws `FAILED_PRECONDITION` weekly and soft-deleted ingredients never get hard-deleted (data accumulates, 30-day grace silently never enforced), OR (b) the index was hand-created in the Firebase console and is **config drift** — absent from source, so it cannot be recreated on a staging/new project (ties to the staging-project ticket on the backlog). Either way it's a real gap.
Fix: add the two `ingredients` composites to firestore.indexes.json and deploy.
Evidence: functions/src/cleanup/cleanup-deleted-ingredients.ts:91-95,192-197; firestore.indexes.json (no `ingredients` collectionGroup).

### Checked, NOT flagged (pass 1)
- `cleanupExpiredSocialRequests` query `status==pending AND sentAt<cutoff` — same equality+range shape, BUT a `social_requests` composite would be needed... it uses `status` + `sentAt`. No `(status, sentAt)` composite exists in the file (only `toUserId/type/sentAt` and `fromUserId/type/sentAt`). **Borderline** — see NEW-2.
- `countStaleRecipes` / stale+failed count queries — pure equality on one field + `.count()`, no orderBy → no composite needed (deviation applies). OK.
- `backfill-recipe-comments-denorm` — cursor-paginated by `__name__`, BATCH_SIZE 450 < 500, dedups recipeIds, idempotent (skips migrated), orphan graceful-degrade to author-only. Batch math correct. Migration safety OK. (Lifecycle-debt-marker risk already in dossier watch-item #2 — not re-flagged.)
- `on-user-deleted` unbounded reads (social_requests, notification queues, activeUsers collectionGroup, reports, shared_content, feedback) — bounded by per-user scale, explicitly argued in code; BUT-1376 already covered the cross-collection unbounded-read class for analytics/triggers. Not re-flagged.
- All `on-user-deleted` batches correctly halve the 500-op cap when staging audit rows (`Math.floor(BATCH_LIMIT/2)`, `opsPerItem:2`). Batch-limit handling is correct throughout. OK.
- `pingSweeper` — paginated (500×20), `<` filter self-advances, fieldOverride present (`pings.expiresAt` COLLECTION_GROUP). OK.

---

## PASS 2 — idempotency/cost, denorm consistency, deletion-cascade integrity

### NEW-2 [LOW] `cleanupExpiredSocialRequests` query likely needs a `(status, sentAt)` composite
cleanup-expired-social-requests.ts:32-35 runs `social_requests.where("status","==","pending").where("sentAt","<",sevenDaysAgo)` via `batchUpdateQuery`. Equality + range on different fields → composite required. The two existing `social_requests` composites are keyed on `toUserId/type/sentAt` and `fromUserId/type/sentAt`; neither satisfies `(status, sentAt)`. Same drift/FAILED_PRECONDITION risk as NEW-1 but lower stakes (expiry is cosmetic — requests have a client-side `isExpired` getter, so a failed sweep doesn't break UX, only leaves `status:pending` stale in storage). Verify against the live console index list; add `(status ASC, sentAt ASC)` if absent.
Evidence: functions/src/cleanup/cleanup-expired-social-requests.ts:32-35; firestore.indexes.json social_requests entries lines 68-85.

### NEW-3 [LOW] `cleanupOldNotifications` 10k-per-collection cap drops residue with no pagination (same class as BUT-1372, different file)
cleanup-old-notifications.ts:28-39 reads each of `notification_history`/`notification_delivery`/`notification_engagement` with `.limit(MAX_DOCS_PER_COLLECTION=10000)`, deletes that one snapshot, and treats the collection as done — **no `startAfter` loop**. Identical completeness gap to the now-Done BUT-1372 (which fixed only `cleanup-shared-content-metadata.ts`). At ≤1k beta users a single collection is very unlikely to exceed 10k expired rows in one weekly window, so impact is low today; but as a scheduled retention job it's the same latent GDPR/cost residue pattern. Fix: wrap `cleanupCollection` in a `startAfter(lastDoc)` loop until empty, keeping the 500-op batch-delete.
Evidence: functions/src/cleanup/cleanup-old-notifications.ts:22-40.

### Checked, NOT flagged (pass 2)
- TTL manual-setup risk for `notification_send_events` (30d) / `scheduled_notifications` (7d) — already dossier watch-item #1; the 90d `cleanupOldNotifications` sweeper is a partial fallback. Not re-flagged.
- `scheduled-notifications` idempotency: drainer flips status AFTER send (at-least-once, documented + accepted for pushes). `expireAt` anchored to `now`, not `deliverAt` — correct for failed-doc passive expiry. OK.
- Deletion-cascade collection coverage: `cleanupNotificationQueuesWithDb` deletes all three of scheduled_notifications / notification_send_events / notification_opened_events keyed on `userId`. (The residual-data *probe* mismatch is owned by role #5 Privacy/DPO watch-item, account-deletion-cascade.ts — outside my owned paths; not duplicated here.)
- `cleanupDeletedIngredients` step-2 docstring ("ensure they're marked for retagging") overstates the code — `countStaleRecipes` only COUNTS; the actual stale-marking happens at soft-delete time in `on-ingredient-soft-deleted.ts`. So no real orphan gap, just a misleading comment. Cosmetic, not ticket-worthy.
- `cleanupDeletedIngredients` writes `system_events` log doc unconditionally each run (even on 0 deletes) — unbounded `system_events` growth, but trivial (1 doc/week/job) and out of scope vs. retention of that collection. Noted, not flagged.

---

## Summary
NEW findings: 3 (1 HIGH, 2 LOW). The HIGH (NEW-1) is the load-bearing one: an `ingredients` cleanup query that needs a composite index nowhere present in source — either silently failing weekly or living as console-only config drift.

COVERAGE: firestore.indexes.json (all 41 composites + 7 fieldOverrides cross-checked against owned-path queries), firestore.rules (comment denorm read-fallback path), functions/src/cleanup/** (cleanup-deleted-ingredients, cleanup-expired-social-requests, cleanup-old-notifications, on-user-deleted), functions/src/migrations/backfill-recipe-comments-denorm, functions/src/scheduled/ping_sweeper, functions/src/shared/{notification-send-events, scheduled-notifications}. Dedup against tracker + dedup-titles + accepted-deviations + dossier #23 watch-items.
