# Sprint Backlog

## Sprint: photo-import allergen banner — 2026-06-04 (iter-119)

Single-ticket Tier-A: BUT-1200. Closes to **Done** — wires an already-approved banner
(BUT-1198) at a logic condition; zero new visual design, so no review-queue surface.
Chosen after 4 candidates (BUT-1011/862/554/1149) proved non-actionable headlessly
(telemetry/profiler/upstream/coverage-gated).

### Agent A: direct — BUT-1200 photo-import allergen banner `[Tier A]`

**Step 0:** PLAN-STALE → re-scoped (ticket body updated). The photo view's only direct
recipe-commit path is `_navigateToMultiRecipePicker → saveSelectedRecipes` (multi-recipe);
the single-recipe path hands OCR text to `franSocialaMedier` (separate surface → follow-up
BUT-1208). Banner wired at the multi-recipe save success only.

- [x] **A1. Add `AllergenMismatch.anyUnconfigured(recipes, prefs)`** `[Tier A]` — `lib/services/tagging/allergen_mismatch.dart`: batch trigger (one prompt covers the saved selection). (BUT-1200)
- [x] **A2. Wire banner into photo multi-recipe save** `[Tier A]` — `photo_import_view.dart _navigateToMultiRecipePicker`: after `ok`, `AllergenSetupBanner.show` if `anyUnconfigured`; reuse Phase-1 tags, app-level messenger survives `maybePop`. (BUT-1200)
- [x] **A3. Unit-test `anyUnconfigured`** `[Tier A]` — extend `allergen_mismatch_test.dart` (4 new tests: any-untracked, all-tracked, empty, no-tagResult). (BUT-1200)

### Needs you (Tier D — flagged, not worked)
- Unchanged carry: store/console/deploy/secrets + monetization clusters; BUT-862
  (needs profiler+device), BUT-1011 (telemetry-gated), BUT-554 (upstream-blocked).

### Awaiting Malin — In Review (carried)
BUT-904 (epic), BUT-1198, BUT-1199, BUT-1037, BUT-1039, BUT-918, BUT-912, BUT-946, BUT-1079.

### Post-Sprint Steps
- [x] `dart analyze --fatal-infos` — clean
- [x] Run `allergen_mismatch_test.dart` — 10 green
- [ ] Commit, push
- [ ] BUT-1200 → Done (Tier-A, test-proven, reuses approved banner)

---

## ARCHIVED — iter-118 (BUT-1203 AutoSaveManager pt.2 — shipped → Done)
Shipped `d90800c45`. Group-creation draft → AutoSaveManager<Map>; recipe-list filter
documented as non-fit exception; pure codec gate (7 tests). Follow-up: BUT-1207.

## ARCHIVED — iter-117 (CI/release tooling — shipped → Done)
Shipped `303e2011c`. BUT-1192 (nightly flake retry) + BUT-488 (release version-bump tooling).

## ARCHIVED — iter-116 (BUT-904 AutoSaveManager extraction — shipped → In Review)
Shipped `0d61ca2bc`. Generic primitive + 3 surfaces. Epic awaits BUT-910. Follow-ups: BUT-1203/1204.
