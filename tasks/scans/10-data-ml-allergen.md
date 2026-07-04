# Scan — Role 10: Data / ML Engineer (parsing & tagging integrity)

Two passes. Reviewed through the expanded role (commit c6d9d7efe) owning the full
parse → ingredient-lookup → tag → allergen-verdict pipeline. Allergen-verdict safety
is the pinned #1 concern.

Owned paths: `lib/models/tagging/**`, `lib/services/parsing/**`, `lib/services/tagging/**`,
`scripts/crf/**`, `scripts/ner/**`.

Date: 2026-06-27

---

## PASS 1 — Upstream (parsing)

Verified the dossier's parsing watch-items against current code. All five remain accurate
and are already documented in the role dossier (CRF-never-retrained, no per-label P/R
tracking, lexicon drift between static `lexicons.json` and live Firebase set, model-size
not CI-enforced, line-classifier span-level metrics missing). Per the dedup rules these are
already-documented dossier watch-items, not new actionables — **no new findings**.

Model-version SHA fail-close gates verified sound: `_expected_model_hashes.dart` refuses
load on missing registry entry; `kExpectedCrfWeightHashes` intentionally empty (bundled v1
weights live, no remote publisher yet). No regression.

---

## PASS 2 — Downstream (tagging / allergen verdict — the safety end)

The core verdict primitives are sound and well-guarded:

- `tri_state.dart` — TriState is a true 3-value enum; `orCombine`/`andCombine` correctly
  rank CONTAINS > UNKNOWN > FREE; empty-combination defaults to UNKNOWN. No boolean collapse.
- `ingredient_lookup_result.dart` — every verdict entry point (`getPropertyStatus`,
  `getCombinedPropertyStatus`, `getDietaryStatus`) returns UNKNOWN when `coverage < 1.0`
  **before** checking presence. Coverage gates the verdict exactly as required.
- `tag_phase1_allergen.dart` / `tag_phase1_dietary.dart` — re-state the coverage guard;
  CRIT-1 skips allergens with empty triggerProperties (fail-safe).
- `tagging_pipeline_runner.dart` — Phase 1 is a hard floor (failure → `TagResult.failed`);
  lookup failure → all allergens/dietary set to UNKNOWN with a `timeout-warning` tag.
- `tag_result.dart` — convenience getters (`isAllergenFree`, `isGlutenFree`, …) return true
  ONLY for `TriState.free`; CRIT-2 coverage-range validation + retagging trigger intact.
- `allergen_mismatch.dart` — only `TriState.contains` triggers the import banner (correct).
- `allergen_status_badge.dart` — renders all three states with distinct color+icon; UNKNOWN
  hidden-on-cards is the accepted deviation, not re-flagged.

No conflation between the auto-tag verdict and the `PersonalTag` subsystem found.

### NEW — HIGH (allergen safety)

**[HIGH] Single-user menu allergen/dietary filter silently includes untagged recipes even when the user opted out of UNKNOWN — diverges from the household path**

`lib/viewmodels/menu/menu_generator.dart` has two parallel filter implementations that
disagree on how a recipe with **no tag data at all** (`tagResult == null`) is treated:

- Household/async path `_filterByPrefs` (line 133):
  `if (tagResult == null) return includeUnknown;` — untagged recipe is **excluded** when
  `includeUnknownInMenu` is false. Correct: a null verdict is the maximally-unknown case.
- Single-user/sync path `_filterByAllergenPreferences` (line 170) **and**
  `_filterByDietaryPreferences` (line 196):
  `if (tagResult == null) return true; // No tag data = include (can't know)` —
  untagged recipe is **unconditionally included**, ignoring the `includeUnknown` opt-out.

Consequence: a user who turns OFF "include unknown in menu" (i.e. *only proven-safe recipes
in my menu*) still gets fully-untagged recipes slipped into their single-user weekly menu —
the exact case the opt-out is meant to exclude — while the household path correctly excludes
them. A null `tagResult` is functionally UNKNOWN; treating it as "safe to include" in one
path is a TriState-collapse-adjacent safety bug at the verdict-consumer layer.

This is the product's #1 safety surface (allergen-free menu filtering, itself flagged as a
Tier-1 *untested* gap in project memory), so the inconsistency is both a correctness bug and
an untested one.

Fix direction: make the sync paths mirror the async path — `return includeUnknown;` for the
null-tagResult branch in both `_filterByAllergenPreferences` and `_filterByDietaryPreferences`.
Add a guard test asserting an untagged recipe is excluded from a single-user menu when
`includeUnknownInMenu == false` (covers the existing untested gap).

Verified not present in `tasks/_scan_dedup_titles.txt`, `.claude/linear-tracker.json`,
`.claude/rules/accepted-deviations.md`, or the role dossier watch-items.

_Evidence: `lib/viewmodels/menu/menu_generator.dart:133` (async, correct), `:170` & `:196`
(sync, wrong); `lib/models/user_allergen_preferences.dart:25,33` (`includeUnknownInMenu`,
defaults true)._

---

COVERAGE: tri_state.dart, ingredient_lookup_result.dart, tag_result.dart,
tag_phase1_allergen.dart, tag_phase1_dietary.dart, ingredient_lookup_service.dart,
tagging_pipeline_runner.dart, tag_display_utils.dart, allergen_mismatch.dart,
allergen_status_badge.dart, menu_generator.dart, user_allergen_preferences.dart;
parsing model-hash gates (_expected_model_hashes.dart) + dossier PASS-1 watch-items reviewed.
1 NEW finding (HIGH, allergen-safety). Parsing-pass watch-items already in dossier — none re-filed.
