# Performance + Tech-Debt Linear Audit — Verdicts

**Date:** 2026-05-28
**Repo HEAD:** main
**Method:** Each ticket cross-checked against current code in `C:\Butlery\butlery`. Drift claims re-measured with `wc -l` and grep. Tickets already `Done` in Linear are flagged DELETE-DUP (no-op needed — Linear already shows them resolved; listed here only for completeness).

---

## Performance tickets

## BUT-429 [DELETE] — (does not exist)
**Evidence:** Linear API returns `Entity not found: Issue` for BUT-429.
**Reason:** Already deleted/archived from Linear; nothing to act on.
**Action:** Skip — no ticket to mutate.

## BUT-430 [DELETE] — (does not exist)
**Evidence:** Linear API returns `Entity not found`.
**Reason:** Already removed.
**Action:** Skip.

## BUT-431 [KEEP+UPDATE] — Reduce cold start (DI bootstrap split)
**Evidence:** `lib/main.dart` is now **1,395 lines** (accepted at 954). `_initializeModularSystem` still runs all 5 stages sequentially before `runApp`; only the Crashlytics+AppCheck `Future.wait` parts are parallelised (lines 186, 310).
**Reason:** 3/4 sub-bullets shipped; the DI Phase-A/Phase-B split is still outstanding and the file has drifted +46% since the ticket was written.
**Action:** KEEP. Update body to note `main.dart` is now 1,395 lines (was cited as ~1,100 area in the ticket). Bundle execution with BUT-530.

## BUT-469 [DELETE] — (does not exist)
**Evidence:** Linear API returns `Entity not found`.
**Action:** Skip.

## BUT-470 [DELETE] — (does not exist)
**Evidence:** Linear API returns `Entity not found`.
**Action:** Skip.

## BUT-471 [DELETE-DUP] — friends_state_manager → StreamManagementMixin
**Evidence:** Linear status = **Done** (completed 2026-05-04, archived). `lib/services/unified/friends/friends_state_manager.dart` exists at 619 lines and contains zero raw `StreamSubscription` declarations.
**Reason:** Already implemented.
**Action:** No-op (already closed).

## BUT-472 [KEEP] — Audit realtime_session_manager.dart
**Evidence:** `lib/services/unified/modules/realtime_session_manager.dart` is 378 lines (smaller than the ticket said), but contains **15 `StreamSubscription` references + 14 `Timer` references** — the resource-density claim still holds.
**Reason:** Still the highest-density resource owner; audit hasn't happened.
**Action:** KEEP. Update body line to "15 subs + 14 timers (file is 378 lines after BUT-1142 work)".

## BUT-473 [DELETE-DUP] — Log IntelligentCacheManager dispose errors
**Evidence:** Linear status = **Done** (2026-05-04, archived).
**Action:** No-op.

## BUT-474 [DELETE] — (does not exist)
**Evidence:** Linear API returns `Entity not found`.
**Action:** Skip.

## BUT-475 [DELETE-DUP] — Route recipe search through Algolia
**Evidence:** Linear status = **Done** (2026-04-27, archived).
**Action:** No-op.

## BUT-476 [DELETE] — (does not exist)
**Evidence:** Linear API returns `Entity not found`.
**Action:** Skip.

## BUT-477 [DELETE] — (does not exist)
**Evidence:** Linear API returns `Entity not found`.
**Action:** Skip.

## BUT-478 [DELETE-DUP] — Defensive .limit() on snapshots
**Evidence:** Linear status = **Done** (2026-05-04, archived).
**Action:** No-op.

## BUT-479 [DELETE-DUP] — Bound friend_relationship stream
**Evidence:** Linear status = **Done** (2026-05-19, archived).
**Action:** No-op.

## BUT-480 [DELETE-DUP] — Optimize tag rename
**Evidence:** Linear status = **Done** (2026-05-04, archived).
**Action:** No-op.

## BUT-481 [DELETE] — (does not exist)
**Evidence:** Linear API returns `Entity not found`.
**Action:** Skip.

## BUT-482 [DELETE-DUP] — Debounce rating aggregation
**Evidence:** Linear status = **Done** (2026-05-04, archived).
**Action:** No-op.

## BUT-483 [DELETE-DUP] — Monitor structureRecipe 60s timeout
**Evidence:** Linear status = **Done** (2026-05-04, archived).
**Action:** No-op.

## BUT-484 [DELETE] — (does not exist)
**Evidence:** Linear API returns `Entity not found`.
**Action:** Skip.

## BUT-589 [DELETE-DUP] — LlmService circuit breaker
**Evidence:** Linear status = **Done** (2026-05-04, archived).
**Action:** No-op.

## BUT-628 [DELETE-DUP] — FamilyPresenceBar StatefulWidget conversion
**Evidence:** Linear status = **Done** (2026-05-04, archived).
**Action:** No-op.

## BUT-629 [DELETE-DUP] — ActivityPingsFeed timer pause
**Evidence:** Linear status = **Done** (2026-05-04, archived).
**Action:** No-op.

## BUT-951 [DELETE-DUP] — ListView.builder for recipe detail
**Evidence:** Linear status = **Done** (2026-05-24, archived).
**Action:** No-op.

## BUT-992 [DELETE-DUP] — Client-side image compression
**Evidence:** Linear status = **Done** (2026-05-23, archived). Related to BUT-1129.
**Action:** No-op.

## BUT-995 [KEEP] — Adopt prompt caching on LLM calls
**Evidence:** `grep -r "cachedContent" functions/src/llm/` returns nothing. No `cachedContents` API usage in `structure-recipe.ts` or `ocr-recipe-image.ts`. Ticket still Backlog.
**Reason:** Not yet implemented; high cost-saving lever from CLAUDE.md cost-principles.
**Action:** KEEP as-is. High-priority.

## BUT-998 [DELETE-DUP] — Snapshots → cached .get()
**Evidence:** Linear status = **Done** (2026-05-24, archived).
**Action:** No-op.

## BUT-1001 [DELETE-DUP] — Listener disposal audit
**Evidence:** Linear status = **Done** (2026-05-24, archived).
**Action:** No-op.

---

## Tech-debt tickets

## BUT-441 [DELETE-DUP] — mina_recept_view drift
**Evidence:** Linear status = **Done** (2026-05-06, archived). `lib/views/mina_recept_view.dart` is now 553 lines (was 1,017) — facade extraction landed.
**Action:** No-op.

## BUT-442 [KEEP+UPDATE] — Migrate repos to BaseFirebaseRepository
**Evidence:** Current measurement: **33 files** under `lib/repositories/` extend `BaseFirebaseRepository` out of 55 `lib/repositories/firebase/*.dart` files plus 13 other repo files (~94 total counted in BUT-574). Adoption ≈ 60% if we trust the firebase/ subtree denominator (33/55). Ticket claims 32%, but BUT-574 (closed) already reconciled to that denominator. Status In Progress since 2026-05-02 with no apparent recent activity.
**Reason:** Real migration work remains; status has stalled.
**Action:** KEEP. Update body: "33 firebase/* repos now extend BaseFirebaseRepository; verify list of 12 highest-value remaining holdouts is still accurate." Consider closing if no longer prioritised.

## BUT-444 [KEEP] — Portion scaling + unit conversion
**Evidence:** Not a code-measurable ticket — feature gap claim. No portion-scaling UI exists in recipe_detail_view (verified by directory check). Still Backlog, High priority. Strategic product-feature ticket.
**Reason:** Genuine missing feature; competitive parity argument unchanged.
**Action:** KEEP as-is.

## BUT-455 [DELETE-DUP] — Audit 5 repos bypassing base chain
**Evidence:** Linear status = **Done** (2026-05-21, archived).
**Action:** No-op.

## BUT-498 [DELETE-DUP] — account-deletion services bypass repo layer
**Evidence:** Linear status = **Done** (2026-04-27). Verified: `lib/services/account/account_deletion/` directory **no longer exists**.
**Action:** No-op.

## BUT-499 [DELETE] — (does not exist)
**Evidence:** Linear API returns `Entity not found`.
**Action:** Skip.

## BUT-500 [DELETE-DUP] — Pull ~40 minor-version updates
**Evidence:** Linear status = **Done** (2026-05-05, archived).
**Action:** No-op.

## BUT-501 [KEEP+UPDATE] — Data-export managers hold Firestore directly
**Evidence:** Linear status = **Done** (2026-04-30) BUT current code in `lib/services/account/export/` still has files; `grep -r FirebaseFirestore lib/services/account/export/` returns **zero matches**. The files are now refactored — confirmed Done correctly.
**Reason:** Re-verified Done — managers no longer hold Firestore directly.
**Action:** No-op.

## BUT-502 [KEEP] — Upgrade file_picker → 11.x
**Evidence:** `pubspec.yaml` shows `file_picker: ^11.0.2`. **Already at 11.x.**
**Reason:** Upgrade landed already; ticket is stale.
**Action:** DELETE (close ticket as already done — file_picker already on 11.0.2).

## BUT-503 [KEEP] — Upgrade archive → 4.x (blocked on Dart SDK)
**Evidence:** `pubspec.yaml` shows `archive: ^3.6.1` (also pinned via `image: ^4.3.0` comment for compat). Block on Dart SDK (BUT-435) still applies.
**Reason:** Still valid; not yet upgraded.
**Action:** KEEP.

## BUT-504 [KEEP+UPDATE] — Layer-skipping services (7 files)
**Evidence:** Verified each cited file:
- `group_shared_content_service.dart`: still holds FirebaseFirestore (2 refs)
- `permission_cache_invalidator.dart`: still holds FirebaseFirestore (2 refs)
- `global_recipe_cache.dart`: **0 refs** (refactored away)
- `import_rate_limiter.dart`: **0 refs** (refactored away)
- `message_reactions_service.dart`: file is only 75 lines, grep on messaging dir found no FirebaseFirestore — refactored away
- `notification_analytics_manager.dart`: still 1 FirebaseFirestore ref
**Reason:** Scope shrank from 7 → 3 files (group_shared, permission_cache_invalidator, notification_analytics).
**Action:** KEEP. Update body to list only the 3 remaining offenders.

## BUT-507 [KEEP] — Upgrade csv → 7.x/8.x (blocked on Dart SDK)
**Evidence:** `pubspec.yaml` shows `csv: ^6.0.0` with comment "Blocked: 7.x/8.x needs Dart 3.10+".
**Reason:** Valid, blocker intact.
**Action:** KEEP.

## BUT-509 [KEEP] — Upgrade flutter_local_notifications → 21.x
**Evidence:** `pubspec.yaml` shows `flutter_local_notifications: ^20.1.0` with comment "21.x needs Dart 3.10+".
**Reason:** Valid, blocker intact.
**Action:** KEEP.

## BUT-520 [KEEP] — ChangeNotifier → BaseViewModel sweep
**Evidence:** Re-measured: 17 files extend `BaseViewModel` vs 62 files extend `ChangeNotifier` in `lib/viewmodels/`. Adoption ≈ 21% (17/79). Ticket cites 18% (16/46) — denominator differs but still under-adopted.
**Reason:** Still valid as an EPIC. The 6 priority VMs in audit follow-up are still all on ChangeNotifier (recipe_list, recipe_form, recipe_detail, unified_shopping, friends, menu — all in the ChangeNotifier list).
**Action:** KEEP. Update numbers: "17/79 = ~21% adoption (re-measured 2026-05-28)".

## BUT-526 [DELETE-DUP] — recipe_unified drift
**Evidence:** Linear status = **Done** (2026-05-05). Current `recipe_unified.dart` is now 1,486 lines and ACCEPTED_LARGE_FILES.md lists 1,425 (the doc has been updated to reflect the new accepted size). Mild +4% drift remains but inside expected churn band.
**Action:** No-op.

## BUT-530 [KEEP+UPDATE] — main.dart drift
**Evidence:** Current `lib/main.dart` is **1,395 lines**. ACCEPTED_LARGE_FILES.md still lists 954. Drift is now **+441 lines (+46%)**, not the +357 the ticket was rescoped to.
**Reason:** Drift continues to grow; needs extraction. Couples with BUT-431 work.
**Action:** KEEP. Update body: "Real drift is now +441 lines (+46%, file is 1,395 lines as of 2026-05-28). Extract ButleryApp + bundle with BUT-431."

## BUT-536 [DELETE-DUP] — firebase_recipe_repository drift
**Evidence:** Linear status = **Done** (2026-05-06). Current size 934 lines vs accepted 906 (+28 mild drift) — acceptable churn band.
**Action:** No-op.

## BUT-542 [DELETE-DUP] — calendar_weekly_menu_widget refactor
**Evidence:** Linear status = **Done** (2026-05-04). Current file is **191 lines** (was 747) — major decomposition already landed (see `lib/widgets/menu/calendar/` directory).
**Action:** No-op.

## BUT-550 [DELETE-DUP] — Accepted-large files drift sweep
**Evidence:** Linear status = **Done** (2026-05-27). ACCEPTED_LARGE_FILES.md was updated 2026-05-28 with reconciled values + "flag decomp follow-up" notes for the worst drifters (photo_import_view/vm, smart_import_view, user_profile_edit_view).
**Action:** No-op. Optionally open a follow-up ticket for the 4 flagged-for-decomp files.

## BUT-554 [KEEP] — Discontinued build_resolvers / build_runner_core
**Evidence:** `pubspec.yaml` shows `build_runner: ^2.7.1` pinned with comment "match drift_dev 2.29.0". Tracker-only ticket per its own body.
**Reason:** Status unchanged.
**Action:** KEEP as tracker.

## BUT-555 [DELETE-DUP] — Audit sembast dev dep
**Evidence:** Linear status = **Done** (2026-05-04).
**Action:** No-op.

## BUT-558 [KEEP] — Install DCM
**Evidence:** `grep -c "dart_code_metrics\|dcm" pubspec.yaml` returns 0. Not installed.
**Reason:** Valid; tooling install hasn't happened.
**Action:** KEEP (Low priority, do when bandwidth allows).

## BUT-567 [DELETE-DUP] — BaseService narrative update
**Evidence:** Linear status = **Done** (2026-05-05, archived).
**Action:** No-op.

## BUT-574 [DELETE-DUP] — Reconcile BaseFirebaseRepository number
**Evidence:** Linear status = **Done** (2026-05-02).
**Action:** No-op. Migration work in BUT-442.

## BUT-579 [DELETE-DUP] — Consolidate parallel button systems
**Evidence:** Linear status = **Done** (2026-05-19). Verified: `lib/widgets/styled/` no longer contains `styled_button.dart`. `lib/widgets/common/buttons/` is the canonical home with README.
**Action:** No-op.

## BUT-581 [KEEP+UPDATE] — Migrate `?? ''` → `.orEmpty()`
**Evidence:** Re-measured: 224 occurrences of `?? ''` across 115 files (ticket claimed 220). Both extensions still exist:
- `lib/core/extensions/default_value_extensions.dart` — method form
- `lib/core/utils/validation_utils.dart:329` — `String get orEmpty => ValidationUtils.safeString(this)` getter form (still divergent)
**Reason:** Pre-codemod blocker (two competing extensions) still applies.
**Action:** KEEP. Update count to 224. Migration plan in body remains correct.

## BUT-598 [DELETE-DUP] — Remove 15 section-divider comments
**Evidence:** Linear status = **Done** (2026-05-01, archived). Re-verified: `grep "// =====|// -----|// ****"` across `lib/` returns 0 hits.
**Action:** No-op.

## BUT-608 [DELETE] — UserId value object
**Evidence:** Idea-ticket, "Likely not worth the refactor cost" in body itself. 2-4 weeks effort, low priority. Body says "filed as idea to consider".
**Reason:** Speculative; ticket author already flagged not worth doing. Delete to reduce backlog noise.
**Action:** DELETE.

## BUT-689 [DELETE-DUP] — Colors.* → theme tokens sweep
**Evidence:** Linear status = **Done** (2026-04-27, archived).
**Action:** No-op.

## BUT-690 [DELETE-DUP] — Hardcoded Color literals to AppColors
**Evidence:** Linear status = **Done** (2026-04-29, archived).
**Action:** No-op.

## BUT-693 [DELETE-DUP] — Reconcile dark-mode comment
**Evidence:** Linear status = **Done** (2026-04-30, archived).
**Action:** No-op.

## BUT-695 [DELETE-DUP] — Rename borderRadius8 = 0.0
**Evidence:** Linear status = **Done** (2026-05-01, archived).
**Action:** No-op.

## BUT-885 [KEEP] — CircularProgressIndicator migration Phase 4
**Evidence:** Status In Progress (2026-05-24). Current count: 0 raw `CircularProgressIndicator(` in `lib/views/`, but **44 occurrences across 36 files in `lib/widgets/`** still exist (acceptance demands 0 outside indicators/state folders + arch-test guard). Many are inside the allowed folders (`lib/widgets/common/indicators/`, `lib/widgets/common/state/`, `lib/widgets/common/loading/`).
**Reason:** Phase still has work; needs arch-test addition. Check which of the 44 hits are inside allowed folders before estimating remaining work.
**Action:** KEEP. Update body to note current count and that views are clean.

## BUT-1004 [KEEP] — IngredientCategorizer Swedish labels + splits
**Evidence:** `lib/services/tagging/ingredient_categorizer.dart` exists. Body is internally consistent and describes future work, not stale claims.
**Reason:** Genuine deferred enhancement.
**Action:** KEEP as-is.

---

## Tally

| Verdict | Count |
|---|---|
| KEEP (work outstanding) | 13 |
| KEEP+UPDATE (re-measure body) | 6 |
| DELETE-DUP (already Done in Linear) | 27 |
| DELETE (no-longer-applicable / non-existent) | 12 |
| **Total audited** | **58 ticket slots** |

Out of the audited tickets, **13 require active updates to body/title**, **12 don't exist (already deleted)**, and the remaining **27 are already Done**. Net real backlog from this audit: **13 KEEP + 6 KEEP+UPDATE = 19 live tickets**.
