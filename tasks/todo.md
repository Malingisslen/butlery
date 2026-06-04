# Sprint Backlog

## Sprint: photo-banner journey test — 2026-06-04 (iter-124)

Single-ticket Tier-A: BUT-1209 (my 3rd filed test-gap — completes the allergen-banner +
AutoSaveManager test-gap family). Test-only, closes to Done.

- [x] **A1. Journey test: photo multi-save → banner wiring** `[Tier A]` — `test/views/photo_import_allergen_banner_journey_test.dart`: 3 cases (untracked allergen → banner; all-tracked → no banner; save-fail → no banner). Drives the real PhotoImportView → BatchImportPreview → save flow. (BUT-1209)
- [x] **A2. Shared-infra: extend MockPhotoImportViewModel** `[Tier A]` — `production_mocks.dart`: added `hasMultipleRecipes`/`parsedRecipes`/`hasError` getters + setter params (additive; unblocks future photo-view journey tests). (BUT-1209)

**Step-0 corrections this iter (recorded on tickets):** BUT-1169 is deploy-blocked (backfill needs CF+prod; can't drop constants before migration) → Tier-D. BUT-839's pure-CF logic is already tested (BUT-778/780); only emulator-integration remains → effectively Tier-D. Both were mis-listed A-CLEAN in the iter-121 scan; per-pick Step-0 caught them.

### Awaiting Malin — In Review (carried)
BUT-904 (epic), BUT-1198, BUT-1199, BUT-1037, BUT-1039, BUT-918, BUT-912, BUT-946, BUT-1079.

---
## ARCHIVED — iter-123 (BUT-1204 — Done) · iter-122 (BUT-1207 — Done) · iter-121 (BUT-1201 — Done) · iter-120 (BUT-1208 — Done) · iter-119 (BUT-1200 — Done) · iter-118 (BUT-1203 — Done) · iter-117 (CI tooling — Done) · iter-116 (BUT-904 — In Review)
