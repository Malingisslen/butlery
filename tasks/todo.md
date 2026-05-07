# Sprint Backlog

## Sprint: analytics caller-wiring + backend correctness sweeps — 2026-05-07 (Th)

Theme: close BUT-803 caller-wiring carve-outs that left analytics dark, plus two correctness sweeps that the wave-1 audit flagged as crash-tail risks.

### Step 0 results

- **BUT-833** Fits.
- **BUT-834** Plan stale: `markRecipeAsCooked` in `personal_recipe_module.dart:351` is a stub — real cook flow is `recipe_detail_viewmodel.markAsCooked` line 289-317 (calls `RecipeCookingService.markAsCooked` then `logRecipeCooked`). Re-scoped emission point inline.
- **BUT-830** Plan stale: cooking-session repo holds ephemeral collab data, not historical cook events. Counted from `_recipeService.personalRecipes` lastCookedAt (one row per recipe — distinct-day proxy matching classifier's ≥3 habitual semantics). Re-classifier emitted post-cook.
- **BUT-824** Fits.
- **BUT-826** Fits.
- **BUT-787** Scope larger than slot: audit said "7+ models", grep finds 33 sites + 40+ across `lib/models/`. Most use `as Type? ?? default` (relatively safe). The dangerous unguarded `as DateTime` casts are inside layers that pre-coerce. Re-scope ticket needed.
- **BUT-783** Scope uncertain: ticket cites "14 write paths"; repo grep finds ~5 read paths and 8 write-key occurrences (mostly Firestore field-name keys, not bypass writes). BUT-466 cleaned `sharedByDisplayName`. Re-audit needed before sweep.

### Agent A: Analytics caller wiring (BUT-803 carve-outs)
- [x] **A1. BUT-833** — `auth_service.dart` constructor's `authStateChanges()` listener now calls `_analyticsService.setUserId(user?.uid)` unconditionally. Unit test added (push signed-in → asserts uid pinned; push null → asserts cleared). MockAnalyticsService gained `capturedUserId` capture-helper.
- [x] **A2. BUT-834** — `recipe_detail_viewmodel.markAsCooked` post-success now calls `_analyticsService.recipe.logFirstCookIfMilestone(userId, mealType, joinedAt)` (idempotent via SharedPreferences). UserService resolved via ServiceLocator; null-tolerant.
- [x] **A3. BUT-830** — Same VM site: counts `personalRecipes.where(lastCookedAt > now-14d)` and calls new `_analyticsService.reclassifyLifecycleStage(signupAt, lastCookAt, cooksLast14Days)`. Method delegates to pure `classifyLifecycleStage` and emits via `setUserProperty`. MockAnalyticsService stubs the new method.

### Agent B: Backend correctness sweeps
- [-] **B1. BUT-787** — Deferred (scope ≥4× ticket estimate). Filed re-scope ticket in Phase 3.
- [-] **B2. BUT-783** — Deferred (premise-check inconclusive). Filed re-audit ticket in Phase 3.
- [x] **B3. BUT-824** — Removed two `friend_requests` composite-index blocks from `firestore.indexes.json`. `social_requests` has equivalent shape. JSON validates.

### Agent C: Documentation reconciliation
- [x] **C1. BUT-826** — `lib/services/CLAUDE.md` no longer claims "~98%"; now links to auto-generated `docs/architecture/adoption-status.md` (reads "67.0% (59/88)" as of 2026-05-06).

### Tier-2 agent reviews (run before commit)
- [ ] code-reviewer — full Dart diff
- [ ] testing-specialist — staged `lib/**/*.dart`
- [ ] firebase-backend-security — if any `lib/repositories/` or `firestore.indexes.json` changes
- [ ] firestore-rules-tester — skip unless `firestore.rules` touched

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos`
- [ ] Relevant unit tests pass
- [ ] `firebase deploy --only firestore:indexes` (B3) — manual ops if MCP can't
- [ ] Commit, push
- [ ] Linear close: BUT-833, BUT-834, BUT-830, BUT-787, BUT-783, BUT-824, BUT-826
- [ ] File any deferred follow-ups

---

## Archived prior sprint (completed in commit 80cefdb64)

architecture-test broaden + sessionId plumb + UI mechanical sweeps — 2026-05-06 (T) — BUT-777/786/803/799/800; BUT-796 obsolete; BUT-798 deferred to BUT-829; follow-ups BUT-829..834 filed.
