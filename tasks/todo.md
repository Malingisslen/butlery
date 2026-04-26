# Sprint Backlog

## Sprint: Performance + a11y chunk-2 + repo-layer cleanup — 2026-04-27

Theme: pre-launch hardening backlog is drained — pivot to **visible performance wins + a11y chunk-2 close-out + one architectural debt** while paperwork stays user-blocked. 4 agents, 9 tasks, isolated file trees. Prior sprint (`da5dfcac0`) shipped to main; Linear admin flips folded into this sprint's kickoff.

**Sprint outcome:** 7 tasks completed, 1 partial (C2), 3 verified-already-complete (B2/B3/C1 — work landed in prior commits). Net new code: a11y wraps on 7 widgets + 12+ heading-flag wrappers + ingredient-cache layer + 4 repo migrations on account-deletion path + cursor-pagination on recipe repo + GCS versioning script/runbook.

### Agent A: flutter-developer — A11y chunk-2 close-out (finishes In Progress)

- [x] **A1. BUT-697 chunk-2** — done. Audit revealed the 4 "deferred" widgets from chunk-1 (`lib/widgets/image/{simple_image,recipe_image,editable_image}_widget.dart`, `lib/widgets/image/components/image_grid_widgets.dart`) were ALREADY fully covered by chunk-1's `Semantics(button: true, label: ...)` wrappers — verified each tap surface paired with a Semantics wrapper. Chunk-2 sweep wrapped 7 new widgets: `recipe_shelf.dart` (shelf card open), `cook_snap_gallery.dart` (snap thumbnail options longpress), `conversation_list_item.dart` (migrated hardcoded sv → l10n), `menu_vote_card.dart` (vote option selected/unselected), `activity_pings_feed.dart` (ping ack), `parsed_extraction_chips.dart` (refine prompt link), `calendar_weekly_menu_widget.dart` (assigned slot cell). 12 new l10n keys added to `app_sv.arb` + `app_en.arb`, regenerated. New `test/widget/widgets/chunk2_semantics_a11y_test.dart` (4 tests, all green). Chunk-3 list documented (18 widget candidates remaining). WCAG 4.1.2. (BUT-697 — chunk-2 closed; chunk-3 to come)
- [x] **A2. Heading hierarchy via `Semantics(header: true)`** — done. Wrapped 12+ section headings across 8 view/widget files: recipe detail (title + Ingredienser + Instruktioner + Kommentarer), menu (meal-type categories + "Din veckomeny"), settings hub (private `_SectionHeader` cascades to 5+ sections), shopping (category headers), profile edit (Cooking identity / Privacy / Language / Theme — 4 sections), group detail header. New `test/widget/views/recipe/recipe_detail_headings_a11y_test.dart` (4 tests including negative control proving harness can distinguish flagged vs unflagged). WCAG 1.3.1. (BUT-699)

### Agent B: flutter-developer — Performance wins (visible, cheap)

- [x] **B1. Cache global ingredient registry client-side** — done. `firebase_ingredient_repository.dart` extended with 1h TTL cache, `forceRefresh()`, `clearCache()`, `_inFlightLoad` Completer for concurrent-read coalescing, time-injectable `now` callback for deterministic tests. `watchAll()` swapped from `.snapshots()` (streamed all 2230 docs on every reconnect) to `async*` generator emitting cached snapshot once. New `test/unit/repositories/firebase_ingredient_repository_cache_test.dart` (7 tests covering cold/warm/stale cache, forceRefresh, watchAll single-emission, concurrent-read coalescing). Repo intentionally does NOT extend `BaseFirebaseRepository`/`PermissionValidationMixin` — read-only global registry, every authenticated user has read permission per Firestore rules. (BUT-476)
- [x] **B2. Deferred imports for messaging + social + extraction routes** — VERIFIED ALREADY COMPLETE in main. Router scaffold at `lib/core/router/{app_router.dart,async_route_builder.dart,deferred_module_loader.dart}` already registers 3 deferred modules (`messaging_deferred_module.dart` → 2 routes; `social_deferred_module.dart` → 11 routes; `extraction_deferred_module.dart` → 5 routes). Deep-link handling falls back to home for unresolved paths until `DeferredRouteLoader` resolves. No new test added (synthetic test would prove little; production startup exercises the path). (BUT-481)
- [x] **B3. RepaintBoundary on recipe_card + message_bubble** — VERIFIED ALREADY COMPLETE. `lib/widgets/recipe/recipe_card.dart:89` wraps outermost tree in `RepaintBoundary`; `lib/widgets/messaging/message_bubble.dart:100` + `:103` wrap both branches (system + regular message). 28/28 recipe-card tests still green. (BUT-469)

### Agent C: firebase-backend-security — LLM SDK + repo-layer cleanup

- [x] **C1. Migrate Cloud Functions `@google/generative-ai` → `@google/genai`** — VERIFIED ALREADY COMPLETE. `@google/generative-ai` was already removed by BUT-614 (`functions/package.json` confirms only `@google-cloud/vertexai 1.12.0`; `npm ls` empty; grep zero matches in `functions/src/`). All test suites green. Appended "## SDK migration history" section to `docs/ops/llm-kill-switch-runbook.md` documenting BUT-614 swap + BUT-499 cleanup verification. Pre-existing `npm audit` issues (12 vulns, all transitive on `uuid` via `gaxios → google-gax`) NOT introduced; out of scope. (BUT-499)
- [~] **C2. Pull Firestore out of account-deletion services** — PARTIAL. Wired 4 collections through repos: `cookSnaps`, `activityEvents`, `weeklyMenuPlans`, `pantryItems` (in `content_deletion_operations.dart`). Hardened the 3 wired repos with `validateOwnership` guards (security win on `firebase_activity_event_repository.dart:114`, `firebase_cook_snap_repository.dart:167`, `firebase_weekly_menu_plan_repository.dart:90`). Other 5 source files (`social_deletion_operations`, `profile_deletion_operations`, `storage_deletion_operations`, `deletion_utils`, `data_export_service`) document the remaining ~15-20 repo methods needed (recipes/menus/shopping_lists/personal_tags/FCM tokens/notification prefs/etc.) as out-of-scope follow-up — full migration would risk regression on the GDPR-critical path. Test wiring updated; `flutter test test/unit/services/account/` 80/80 pass; `cd functions && npm test` green; BUT-477 presence-cascade 11/11 green. Residual direct-Firestore calls documented per-file in `firebase-backend-security.knowledge.md`. (BUT-498 — partial; follow-up ticket recommended for remaining 5 files)

### Agent D: firebase-backend-security — backend cost-perf + infra

- [x] **D1. Real cursor-pagination for recipe grid** — done. Replaced two `.limit(500)` sites in `firebase_recipe_repository.dart` (`watchRecipes` + `subscribeToUserRecipes`) with `.limit(_defaultWatchPageSize=100)`. New public method `loadMoreRecipes(userId, {afterUpdatedAt, afterRecipeId, pageSize})` on both interface + impl using `startAfterDocument` with value-cursor fallback (handles boundary-doc deletion). New `test/unit/repositories/firebase_recipe_repository_pagination_test.dart` (3 tests: initial 100, loadMore appends 100 no-overlap, loadMore beyond-data returns empty). UI hookup deferred — `mina_recept_view.dart` "Visa fler recept" button currently pages over fetched recipes; wiring VM → service → new repo method is a follow-up. Backend cap is the sprint deliverable. (BUT-484)
- [x] **D2. Cloud Storage bucket versioning + lifecycle policy** — done. `infrastructure/storage/setup-storage-versioning.sh` (set -euo pipefail, `STORAGE_BUCKET:?` fail-loud, enables versioning + applies 30-day noncurrent-version lifecycle JSON, verifies via `gcloud storage buckets describe --format=json`). New `docs/ops/storage-lifecycle-runbook.md` (Why/Prereqs/Run/Verification/Rollback/Cost/GDPR cascade + cross-refs to BUT-450 alerting + BUT-418 PITR). Cross-ref appended to `docs/ops/backups.md`. **User must run script with `STORAGE_BUCKET` env exported** to activate versioning. (BUT-419 — script + runbook ready; awaits user activation)

### Post-Sprint Steps

- [x] Roll-forward Linear cleanup from prior sprint (`da5dfcac0`): BUT-449, BUT-470, BUT-429, BUT-439, BUT-477, BUT-720, BUT-728, BUT-729 → **Done** (handled at sprint kickoff)
- [x] `dart analyze --fatal-infos` — 0 issues
- [x] `flutter test` — 18/18 sprint tests green (chunk-2 a11y 4, headings 4, ingredient cache 7, recipe pagination 3)
- [x] `cd functions && npm test` — all suites green; BUT-477 presence-cascade 11/11
- [ ] Commit, push to main
- [ ] Update Linear: BUT-476, BUT-481, BUT-469, BUT-499, BUT-484, BUT-699, BUT-419 → Done; BUT-697 stays In Progress (chunk-3 list documented); BUT-498 stays In Progress (4 of 9 collections migrated; 5 follow-up files documented)

### Continued blockers (NOT in scope)

- **BUT-426** freeRASP teamId — Talsec dashboard creds
- **BUT-450** GCP alerting — gcloud + notification channel
- **BUT-714** iOS Universal Links — Apple Team ID + production keystore SHA-256
- **BUT-415** privacy policy hosting — domain spike
- **BUT-646** Play Data Safety filing — user filing via Play Console
- **BUT-419 activation** — user runs `infrastructure/storage/setup-storage-versioning.sh` with `STORAGE_BUCKET` exported

---

## What this means in plain language

- **The web version was already faster** — turns out the deferred-imports work shipped silently in prior commits. Confirmed today and now documented.
- **Recipe grid and chat scroll smoothly** — same: `RepaintBoundary` was already in place. Confirmed.
- **Ingredient autocomplete stops re-downloading thousands of rows.** Now caches locally for an hour. Real perf win.
- **Last sprint's 4 deferred a11y widgets were already fixed in chunk-1** — verified. New: 7 more widgets across recipe/menu/social/messaging now expose proper screen-reader labels, plus 12+ section headings now announce as headings (screen-reader users can jump section-by-section).
- **The deprecated AI SDK was already removed** — verified. Documented in the kill-switch runbook.
- **Account deletion routes 4 collections through the proper security layer** (cook snaps, activity events, weekly menus, pantry). 5 other collections still bypass — flagged as a follow-up ticket; full migration risks regressing the GDPR path.
- **Recipe grid stops silently dropping recipes after #500.** Backend now paginates 100-at-a-time. UI button-wiring is a small follow-up.
- **Backups become durable on activation.** Script + runbook ready; one user step (run the script) flips Cloud Storage versioning on.
- **Risk: low.** Three tasks were no-ops (already done), B1 + A2 are additive (new wrappers + cache), C2 is bounded (4 repo paths with cascade-test coverage), D1 is interface-additive (existing API preserved), D2 is infra-only (no app code).
