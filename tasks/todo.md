# Sprint Backlog

## Sprint: architecture-test broaden + sessionId plumb + UI mechanical sweeps — 2026-05-06 (T)

Theme: tighten the structural floor (arch-test broadening + analytics correctness) and clear directional-padding RTL gap.

### Step 0 results
- **BUT-777** — Fits.
- **BUT-796** — **Premise gone**: firebase-functions 7.2.5 v2 has no `onUserDeleted` (only blocking triggers). Auth `.onDelete()` remains v1-only. Closed Cancelled with explanation.
- **BUT-786** — Fits. Chokepoint = `FirebaseAnalyticsRepository._sanitize`.
- **BUT-803** — Fits, partial: PA5/PA8/PA9/PA11 implemented; PA6 rejected as anti-pattern (would break Firebase DebugView); PA7 deferred (needs new repo query) → BUT-830.
- **BUT-799** — **Plan stale**: bulk migration already done in commit cc17ce235 (RTL sweep). Ticket assumed 39 sites. Re-grep with multi-line regex caught 16 mixed-axis violations the audit missed; migrated those + added regression guard.
- **BUT-798** — **Scope larger than estimated**: ticket said 34 files, re-grep shows 50+. Deferred bulk sweep to BUT-829; arch-test guard not added (would fail until sweep complete).
- **BUT-800** — Fits. clampTextScaling lifted to `MaterialApp.builder` root. viewInsets sub-task deferred to BUT-831 (per-scaffold work, breakage risk).

### Agent A: Architecture + Backend
- [x] **A1. BUT-777** — `test/architecture/architecture_test.dart`: 4 new groups added (Firebase{Auth,Storage,Analytics,Functions}.instance, VM cloud_firestore imports, view→firebase-repo imports, .collection(literal) bans). Pre-existing violators allow-listed inline with follow-up references.
- [~] **A2. BUT-796** — Premise gone. Closed Cancelled.

### Agent B: Analytics correctness
- [x] **B1. BUT-786** — `setSessionId`/`currentSessionId` on `AnalyticsRepository` interface; Firebase impl injects `session_id` into every event via `_sanitize` chokepoint; one-time warning when null at emission time. Cold-start + >30min-resume regenerates session via `_ensureAnalyticsSessionId()` in main.dart. NoOp impl tracks locally. 5 unit tests cover fast-path / null-params / PII slow-path / clear / `currentSessionId` getter.
- [x] **B2. BUT-803 (PA5/PA8/PA9/PA11)** — `setUserId` on interface + Firebase impl + service delegate. `feature_flag_evaluated` now also fires from `isEnabled` path (was only `isInRollout`). `recipe_favorited` event constant + emission from `toggleFavorite`. `first_cook` milestone constant + `logFirstCookIfMilestone` method on RecipeEventsTracker. PA6 (debug drop) rejected: would suppress DebugView. PA7 (cooksLast14Days) deferred to BUT-830.

### Agent C: UI mechanical sweeps
- [x] **C1. BUT-799** — 16 `EdgeInsets.only(...left/right...)` mixed-axis sites migrated to `EdgeInsetsDirectional.only(start/end)`. Arch-test regression guard added. `SkeletonComponents.skeletonBox` `margin:` widened from `EdgeInsets?` to `EdgeInsetsGeometry?` to accept directional callers.
- [-] **C2. BUT-798** — Deferred. 50+ files exceed sprint slot. Filed BUT-829 follow-up. Returned to Backlog.
- [x] **C3. BUT-800** — `MaterialApp.builder` now clamps `textScaler` at root (1.4× ceiling). Per-scaffold `clampTextScaling` wrappers become redundant but harmless. viewInsets sub-task deferred to BUT-831.

### Tier-2 agent reviews
- [ ] code-reviewer — full Dart diff (run before commit)
- [ ] testing-specialist — `lib/repositories/firebase/firebase_analytics_repository.dart` + `lib/services/analytics_service.dart` + `lib/main.dart`
- [-] firebase-backend-security — skip (no rules / functions touched)
- [-] firestore-rules-tester — skip (rules not touched)

### Post-Sprint Steps
- [x] `dart analyze --fatal-infos` clean
- [x] Architecture test green (8 groups, all pass)
- [x] BUT-786 unit tests pass (5/5)
- [x] Feature-flag dedup tests pass (5/5)
- [ ] Commit (specific paths only — leave MASTER-wave docs / overnight log untouched per parallel-session rule)
- [ ] Push
- [ ] Linear close: BUT-777, BUT-786, BUT-803, BUT-799, BUT-800 to Done; BUT-796 already Cancelled; BUT-798 to Backlog (deferred)
- [ ] File follow-ups: BUT-829 (CPI sweep), BUT-830 (cooksLast14Days), BUT-831 (viewInsets), BUT-832 (recipe_cooked is_first_time test fix)

### Known follow-ups (filed in Linear in Phase 3)
- **BUT-829** — Bulk-migrate 50+ raw `CircularProgressIndicator` → `StateWidget.loading()`/`LoadingIndicator` + arch-test guard. Replaces deferred BUT-798 scope.
- **BUT-830** — Compute `cooksLast14Days` user property on session-complete. Needs cookSession repo `countSince(now-14d)`. (BUT-803 PA7 carve-out.)
- **BUT-831** — Roll out `MediaQuery.viewInsetsOf` to keyboard-affected scaffolds (login, comments, recipe form, chat input). (BUT-800 sub-scope.)
- **BUT-832** — Fix `recipe_cooked` test assertion: expects string `'false'` but BUT-523 dictates native bool. Pre-existing failure not caused by this sprint.
- **BUT-833** — Wire `setUserId` on auth state transitions in `AuthService` listener / `AuthWrapper`. (BUT-803 PA5: chokepoint added; caller wiring still needed.)
- **BUT-834** — Wire `logFirstCookIfMilestone` from `markRecipeAsCooked` callsite. (BUT-803 PA11: tracker method added; emission point still needed.)

### What this means in plain language
- **Architectural enforcement**: 4 new arch-test rules catch `FirebaseAuth.instance` etc., view→repo direct imports, VM→firestore imports, and hardcoded collection-name strings at PR time. Pre-existing violators are noted with cleanup tickets.
- **Analytics now has session IDs**: every event emitted from now on carries a `session_id` field. Funnel analysis (signup → first cook → favorite) can now bucket events to one user-session in BigQuery instead of guessing.
- **Cross-device user tracking**: `setUserId` is now wired on the analytics chokepoint — once we hook it into auth-state changes (BUT-833), events on phone + tablet will tie to the same user.
- **Three new analytics events**: `recipe_favorited`, `feature_flag_evaluated` (now fires from both code paths), `first_cook` milestone (method ready, emission point pending).
- **RTL readiness improved**: 16 padding sites that were stuck in left-to-right are now bidirectional. Arabic/Hebrew users would have seen wrong-side padding without this.
- **Accessibility**: extreme text-scale settings (250%+) now clamp to 1.4× at the app root, so layouts don't clip.
- **Risk**: low. Behavior changes are additive (new events) or visual-equivalent in current LTR locale (directional padding looks the same in Swedish/English). Sprint scope adjusted from 7→5 implemented tickets after Step 0 caught two stale-audit cases and one over-large scope.

---

## Archived prior sprint (completed in commit 4f8654b87)

hygiene + supply-chain pins + backend index — 2026-05-06 (S) — BUT-810/809/794/791/790/793/792/795/772; follow-ups BUT-822..828.
