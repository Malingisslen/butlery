# Sprint Backlog

## Sprint: text-import allergen banner — 2026-06-04 (iter-120)

Single-ticket Tier-A: BUT-1208 (filed last iter). Completes allergen-banner coverage
across ALL import surfaces. Closes to Done — reuses the approved BUT-1198 banner at a
logic condition, zero new visual.

### Agent A: direct — BUT-1208 franSocialaMedier allergen banner `[Tier A]`

**Step 0:** FITS. Verified `TextImportViewModel.parseText` → `ImportManager` attaches
Phase-1 allergen tags (import_manager.dart:600-614, shared strategy path), so
`parsedRecipe.tagResult` is populated at the nav point → the banner check works.

- [x] **A1. Wire banner into franSocialaMedier success→SkrivSjalv nav** `[Tier A]` — `fran_sociala_medier_view.dart:161`: after `parseText` success, `AllergenSetupBanner.show` if `unconfiguredContainedAllergens(parsedRecipe, prefs).isNotEmpty`. Covers direct-text AND single-photo handoff. (BUT-1208)

**Verification:** analyze clean; `?? ''` grep clean; `architecture_test.dart` +18 green
(ran locally per the reinforced lesson). No new pure logic (reuses the proven
`unconfiguredContainedAllergens`), so no new unit test; journey coverage tracked with
the import-banner test family (BUT-1209/BUT-1204).

### Needs you (Tier D — flagged, not worked)
- Unchanged carry: store/console/deploy/secrets + monetization; BUT-862/1011/554 (blocked).

### Awaiting Malin — In Review (carried)
BUT-904 (epic), BUT-1198, BUT-1199, BUT-1037, BUT-1039, BUT-918, BUT-912, BUT-946, BUT-1079.

### Post-Sprint Steps
- [x] `dart analyze --fatal-infos` — clean
- [x] `architecture_test.dart` — +18 green
- [ ] Commit, push
- [ ] BUT-1208 → Done

---

## ARCHIVED — iter-119 (BUT-1200 photo allergen banner — shipped → Done)
Shipped `44e0c7472` + fix `837425a2b` (BUT-581 `?? ''` guard miss, fixed forward).
Follow-ups: BUT-1208, BUT-1209.

## ARCHIVED — iter-118 (BUT-1203 AutoSaveManager pt.2 — Done) · iter-117 (CI tooling — Done) · iter-116 (BUT-904 — In Review)
