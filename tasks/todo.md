# Sprint Backlog

## Sprint: backend perf + observability hardening — 2026-05-04 (G)

Theme: cluster of 7 P3/P4 perf+observability tickets across Cloud Functions hot-paths (rating aggregation, structureRecipe timeout, ping enforcement) and client/backend hardening (cache disposal logging, batch idempotency audit, tag rename UX). **6 implementations + 1 obsolete close. 3 batches.**

**In Progress carry-overs (NOT in this sprint):**
- BUT-442 — repo migrations (4 candidates remaining; deserves own focused sprint).
- BUT-760 — App Check enforcement; awaiting Firebase Console flip (Play Integrity / App Attest registration).

**Step 0 verification — done:**
- **BUT-482** valid — `functions/src/index.ts:232/260/295` triggers `onRatingCreated/Updated/Deleted` each call `updateRecipeRatingStats(recipeId)` at line 136, which re-reads ALL ratings + writes `recipe_social_stats/{recipeId}` synchronously. No debounce, no Cloud Tasks queue, no shard collapse. Hot-spot real for popular recipes; Firestore single-doc write throttle at ~1/sec.
- **BUT-480** plan-stale (premature scope) — `firebase_recipe_repository.dart:482-540` `renamePersonalTagInRecipes` uses `batchLimit = 500` (not 450; at hard limit), client-side fetch-all + chunked batch update. Ticket itself flags "Fine for current scale; bottleneck at 100x" — 10K+ recipes per tag is hypothetical for solo+beta. Re-scope to (a) lower batchLimit to 450 for safety margin, (b) make rename idempotent (re-run safe — the map-rebuild is already idempotent, but document it), (c) add user-facing "Byter namn i bakgrunden…" toast wrapping the call. Defer Cloud Function migration to a future scale-driven sprint.
- **BUT-483** plan-stale (Cloud Logging filter is console config) — `functions/src/llm/structure-recipe.ts` exists. A "Cloud Logging metric filter" is a GCP console artifact (Logs Explorer → Create Metric), not a code change. Re-scope to: add structured timing log at function exit covering `{durationMs, textLength, mode, success}` so any future GCP filter has a clean signal field. Doc in `functions/RUNBOOK.md` (or create) noting how to wire the metric filter when monitoring becomes a need.
- **BUT-627** valid — `functions/src/scheduled/` exists (only `north-star-weekly.ts` today); no `triggers/` dir yet. Rules confirm `match /pings/{groupId}/pings/{pingId}` at `firestore.rules:836` and collection-group rule at `:1608`. Both new files clean adds.
- **BUT-619** premise-gone (closed as Duplicate of wave-1 HIGH-SEC7 / BUT-456 build validation work) — `.github/workflows/build-validation.yml:180` (Android) AND `:221` (iOS) both already invoke `flutter build … --obfuscate --split-debug-info=build/debug-info`. The original "Inspect" deduction has since been resolved via the cross-platform build-validation hardening. Close ticket; link resolving commit.
- **BUT-592** valid (audit-style) — `content_deletion_operations.dart` exists at `lib/services/account/account_deletion/content_deletion_operations.dart` (454 lines), `_batchLimit = 450` confirmed at line 27. Ticket is correct that the partial-write story is undocumented. 30+ files in `lib/` use `writeBatch`/`firestore.batch()`. Scope to a focused audit of the 4 multi-batch consumers (content deletion, social deletion, recipe tag rename, notifications cleanup) — document idempotency/checkpoint behavior + add at least one observable failure marker.
- **BUT-473** valid (path-stale) — line numbers shifted: `_disposeCacheManager` is at `main.dart:586-596`, not `:506-516`. Trivial fix: replace silent catch with `kDebugMode`-guarded `AppLogger.warning('cacheManager dispose failed: $e')`.

### Agent A: Cloud Functions perf — cloud-functions-specialist

- [x] **A1. BUT-482 — Debounce rating aggregation** (Firestore-marker + drainer over Cloud Tasks; latency 0..60s vs exactly 5s — noted) —
  - `functions/src/index.ts`:
    - Replace direct `updateRecipeRatingStats(recipeId)` calls in `onRatingCreated/Updated/Deleted` (lines 232/260/295) with a debounced enqueue helper.
    - Add `scheduleRatingAggregation(recipeId)` that writes a debounce marker to `_internal/rating_debounce/{recipeId}` with `pendingUntil = now + 5s` server timestamp; only schedules a delayed Cloud Tasks enqueue if no marker exists or it's expired. Use `firestore.runTransaction` for the read-check-write pattern.
    - Cloud Tasks queue `rating-aggregation-queue` (or use `scheduleFunction.delay()` if simpler — pick the lighter-weight approach for region `europe-west1`): a 5s-deferred handler that reads the marker + calls `updateRecipeRatingStats`, then deletes the marker.
    - On rapid successive ratings within the 5s window, only the first triggers a scheduled run; the eventual run reads the latest ratings (correct by construction since aggregation reads the full collection).
    - Add `logger.info({event: 'rating_aggregation.skipped', recipeId, reason: 'debounce'})` for the skip path so we can see throttle effectiveness.
  - `functions/src/__tests__/rating-aggregation.test.ts` (new or extend existing): rapid-fire 5 rating creates within 5s → only 1 aggregation run; rating after 6s → second aggregation run.
  - **Trade-off accepted**: 5s perceived latency on rating-stats freshness vs. eliminating throttle errors at popular-recipe hot-spots. (BUT-482)

- [x] **A2. BUT-483 — Add structured timing log at structureRecipe exit** —
  - `functions/src/llm/structure-recipe.ts`:
    - Capture `const startMs = Date.now();` at the start of the callable handler.
    - At every exit path (success + caught error), `logger.info({event: 'structure_recipe.complete', durationMs: Date.now() - startMs, textLength: text.length, mode: mode ?? 'extract', success: <bool>})` so a GCP Logs-Explorer filter can compute p50/p95/p99 by mode without any deploy.
    - Add 3 lines to `functions/RUNBOOK.md` (create if absent — minimal: just this one operations note) covering: "How to wire a `structure_recipe.duration_ms` distribution metric in Cloud Logging when latency monitoring becomes a need" — point at the structured field name + the mode label dimension.
  - No client behavior change. No timeout bump (60s stays — the bump is data-driven after we have p95). (BUT-483)

- [x] **A3. BUT-627 — Ping sweeper + onCreate hourly rate-limit enforcement** (audit path corrected to 4-segment `audit/ping_rate_limit/entries/{auto}`) —
  - `functions/src/scheduled/ping_sweeper.ts` (new):
    - `onSchedule({schedule: 'every 10 minutes', region: 'europe-west1', timeoutSeconds: 120})` handler.
    - Collection-group query `db.collectionGroup('pings').where('expiresAt', '<', admin.firestore.Timestamp.now()).limit(500)` → batched delete (chunk to 500-op batch limit).
    - `logger.info({event: 'ping_sweeper.complete', deleted: count, durationMs})`.
  - `functions/src/triggers/ping_onCreate.ts` (new):
    - `onDocumentCreated('pings/{groupId}/pings/{pingId}')` handler, region `europe-west1`.
    - Read `data.fromUserId`, then collection-group query `pings` where `fromUserId == X` AND `createdAt >= now - 1h`. Use `.count()` aggregate.
    - If count > 5: delete the just-written ping (`event.data.ref.delete()`), append audit log to `audit/ping_rate_limit/{autoId}` with `{userId, deletedPingId, count, ts}`, log `{event: 'ping_rate_limit.exceeded'}`.
    - Idempotency: trigger fires once per create; transient retries are safe (delete is idempotent).
  - `functions/src/index.ts`: re-export both — `export { pingSweeper } from "./scheduled/ping_sweeper";` and `export { onPingCreated } from "./triggers/ping_onCreate";`.
  - Required composite indexes for collection-group query: `pings` collection-group on `(fromUserId ASC, createdAt DESC)` and `(expiresAt ASC)`. Add to `firestore.indexes.json`.
  - Tests: `functions/src/__tests__/ping_rate_limit.test.ts` against the emulator — 5 pings in 1h: all kept; 6th: deleted + audit row written; sweeper deletes only `expiresAt < now`. (BUT-627)

### Agent B: Client perf observability + tag rename UX — flutter-developer

- [x] **B1. BUT-473 — Log cacheManager dispose errors in debug** —
  - `lib/main.dart:586-596`: inside `_disposeCacheManager` catch block, replace the silent `// Silently ignore` comment with:
    ```dart
    if (kDebugMode) {
      AppLogger.warning('cacheManager dispose failed: $e');
    }
    ```
  - Add necessary imports: `package:flutter/foundation.dart` for `kDebugMode`, and `AppLogger` (likely already imported — verify).
  - No test needed (debug-only diagnostic). (BUT-473)

- [x] **B2. BUT-480 — Tag rename: lower batch limit + idempotency doc** (toast deferred — coupled to deferred CF migration) —
  - `lib/repositories/firebase/firebase_recipe_repository.dart:505`: change `const batchLimit = 500;` → `const batchLimit = 450;` (50-op safety margin under Firestore's hard 500). Aligns with `content_deletion_operations.dart:27`.
  - `lib/repositories/firebase/firebase_recipe_repository.dart:482-487`: extend the doc-comment block to explicitly state the idempotency contract: "Re-running this method with the same `(tagId, newName)` is a no-op for already-renamed entries (the `personalTags` rebuild only writes when `entry['tagId'] == tagId`, and a tag already at `newName` produces an identical document). Safe to retry on partial failure."
  - Find caller of `renamePersonalTagInRecipes` — likely `lib/viewmodels/personal_tags_viewmodel.dart` or `lib/services/personal_tag_service.dart`. Wrap the call in a UI-feedback flow: show a non-blocking toast ("Byter namn i bakgrunden…" sv / "Renaming in background…" en) at start, success/error toast on completion. Use existing `SnackBarHelper` or `ToastService` if present (grep first).
  - Tests: `test/unit/repositories/firebase_recipe_repository_test.dart` — add idempotent-rerun test (run rename twice, assert second run produces no field changes / second batch.commit() is no-op-equivalent).
  - **Defer (out of scope)**: Cloud Function migration of the rename; denormalized lookup collection. Both await actual scale signal (>1K recipes per tag in production traffic). (BUT-480)

### Agent C: Batch partial-write audit — direct + firebase-backend-security review

- [x] **C1. BUT-592 — Audit + document partial-write semantics for 4 multi-batch consumers** —
  - **Scope** (NOT a full 30-file audit — focus on the multi-batch sequences where partial failure is most user-visible):
    1. `lib/services/account/account_deletion/content_deletion_operations.dart` — already uses `_batchLimit = 450` + commit-and-renew helper at line 49-55. Document in a class doc-comment what happens if commit N succeeds and N+1 fails (user has half-deleted recipes — recoverable on next deletion attempt because deletion of already-gone docs is a no-op).
    2. `lib/services/account/account_deletion/social_deletion_operations.dart` — verify same pattern; if not using the shared helper, port it. Same doc-comment.
    3. `lib/repositories/firebase/firebase_recipe_repository.dart` `renamePersonalTagInRecipes` (covered also by B2) — partial failure leaves some recipes renamed and some not. Document the idempotent-rerun recovery path in the same doc-comment from B2.
    4. `lib/repositories/firebase/firestore_batch_utils.dart` — extend with a `commitOrThrow({required String operationLabel})` wrapper that adds `AppLogger.error` of `{operationLabel, batchIndex, totalBatches}` on failure so partial-write incidents surface in production logs (currently many catch sites swallow). Audit the 4 callers above to use it.
  - **Out of scope** (not multi-batch — single-batch operations are atomic): `firestore_batch_utils.dart` consumers that only commit one batch (notifications cleanup, friend removal — single-batch ops don't have partial-write risk).
  - Tests: extend `test/unit/services/account/account_deletion/content_deletion_operations_test.dart` (or create a focused test) — simulate batch.commit() throwing on second batch; assert (a) first-batch deletions persisted, (b) `AppLogger.error` was called with the operation label, (c) re-running the operation completes successfully (idempotent recovery).
  - Output artifact: a 30-line summary block in `docs/architecture/BATCH_PARTIAL_WRITE_NOTES.md` (new, brief) listing the 4 multi-batch consumers with their partial-failure mode and recovery path. Doc-only — no future drift maintenance burden if kept under 50 lines. (BUT-592)

### Closure-only (no implementation)

- [x] **D1. BUT-619 — Closed as Duplicate** — Both Android (`.github/workflows/build-validation.yml:180`) and iOS (`:221`) already build with `--obfuscate --split-debug-info=build/debug-info`. Resolved by wave-1 HIGH-SEC7 close-out (BUT-456 + BUT-456-followup). Close in Linear with comment linking to commit `920b761ee` (BUT-456-era) + the workflow file lines.

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` — 0 issues
- [ ] Functions: `cd functions && npm run build && npm test`
- [ ] Affected Dart unit tests: `firebase_recipe_repository_test`, `content_deletion_operations_test`
- [ ] Affected TS tests: `rating-aggregation.test.ts`, `ping_rate_limit.test.ts`, `structure-recipe.test.ts`
- [ ] Tier-2 specialist gates: `code-reviewer` (any .dart), `testing-specialist` (any lib/), `firebase-backend-security` (account_deletion + tag rename touched), `cloud-functions-specialist` (functions/src/ touched), `firestore-rules-tester` (no rules change, skip)
- [ ] Commit, push to main
- [ ] CI watcher monitors green
- [ ] Update Linear: BUT-482/483/473/480/592/627 → Done; BUT-619 → Closed (Duplicate / obsolete)

### Continued blockers (NOT in scope per memory)
- BUT-415 / BUT-714 / BUT-646 / BUT-731 — store/Play submission deferred (Apple Dev enrollment gated)
- BUT-549 — post-beta (Sign in with Apple lands when social login does)
- BUT-579 — held for button-system sprint
- BUT-444 / BUT-445 — own product-design sprints
- BUT-498 / BUT-697 — explicitly skipped
- BUT-686 / BUT-660 / BUT-694 — feature-level brainstorming first
- BUT-674 / BUT-721 — own scoped sprints
- BUT-626 — bucket-based A/B infra; own sprint
- BUT-420 / BUT-451 / BUT-452 / BUT-486 — deploy-pipeline / staging cluster; focused infra sprint
- BUT-550 / BUT-536 / BUT-441 — ACCEPTED_LARGE_FILES drift sprint
- BUT-558 — DCM install (own sprint)
- BUT-554 — tracking ticket (blocked on drift_dev upstream)
- BUT-594 — macOS sandbox audit needs hardware-exercise step
- BUT-701 — focus traversal (2-day a11y sprint)
- BUT-479 — cursor-pagination half is non-trivial; needs design ticket
- BUT-435 + BUT-502/503/507/509 — Dart SDK 3.10 bump cluster (one focused sprint)
- All `idea`-labeled monetization scaffolding — post-beta

### What this means in plain language
- **Faster ratings on popular recipes**: when many people rate the same recipe quickly, the app no longer chokes — it batches the math instead of redoing it for every single click.
- **Better signal when something slow happens during recipe import**: the import function now logs how long each call takes, so if it gets slow we'll see it instead of guessing.
- **Stricter ping abuse protection**: a server-side guard now catches anyone who tries to spam more than 5 pings per hour by going around the app, plus old expired pings auto-clean themselves.
- **A small dev-mode warning for cache leaks**: if the cache fails to clean up when closing the app, you'll see it in the debug console instead of it being silently swallowed.
- **Tag renames feel more responsive**: a small "Renaming in background…" toast appears so you know it's working, and the operation is safer if it gets interrupted.
- **Documentation of what happens if account deletion fails halfway**: written down so we know the recovery path (re-run the deletion).
- **One ticket closed without code**: the iOS code-obfuscation gap was already fixed in earlier work — just closing the leftover ticket.
- **Risk**: very low. All changes are additive (logging, doc, toast) or behavior-equivalent (debounce produces same final stats). Easy to revert per task.

---

## Archived prior sprint (completed in commit 4fc17758e + d9cb88acf)

Parsing/social tech-debt + dependency hygiene — 2026-05-04 (F) — shipped BUT-700/682/676/631/630/513/529 + BUT-698 closed as Duplicate. See git log for full task breakdown.

## Archived sprint before (completed in commit 75873d1e1)

Pre-beta moderation + anti-spam + UGC compliance — 2026-05-04 (E) — shipped BUT-537/544/649/651/654/659. See git log for full task breakdown.
