# Sprint Backlog

## Sprint: BUT-441 mina_recept_view facade extraction — 2026-05-06 (O)

Theme: large-file decompose cluster, first ticket. `lib/views/mina_recept_view.dart` was the worst drifter on the accepted-large list (687 → 1017 lines, +48%). Facade-extracted into 5 focused files in `lib/views/mina_recept/`. Behavior-preserving structural refactor; no public-surface changes.

**In Progress carry-overs (NOT in this sprint, NOT shipped):**
- BUT-442 — repo migrations (own focused sprint, mid-flight).
- BUT-760 — App Check enforcement; awaiting Firebase Console flip.

**Step 0 verification — done:**
- **BUT-441 fits.** Current line count 997 (was 1017 in ticket; minor settling). Five clean extraction targets with no `setState` reach-through:
  - `_buildRecipeCard` (152 lines) — pure widget that takes viewModel/recipe/allergenPrefs/onDelete.
  - `_buildEmptyState` + `_buildOnboardingBanner` (108 lines combined) — pure presentational.
  - `_buildDiscoveryShelves` + `_buildSeasonalHero` + `_navigateToRecipe` (~46 lines) — receives the once-resolved seasonal future from parent.
  - `_buildSelectionAppBar` (48 lines) — top-level builder returning `PreferredSizeWidget`.
  - `_buildSortChip` + `_getQuickFilterIds` + `_onQuickFilterToggle` (~140 lines) — helpers + sort chip widget.
- Tests: no widget tests exist for this view (only e2e imports the public class). Internal refactor doesn't break the e2e contract.

### Agent A: Extraction (lib/views/mina_recept/*.dart, .dart triggers Tier-2 specialists)

Specialists: `code-reviewer` + `testing-specialist` (any `.dart` change in `lib/`).

- [x] **A1. New `lib/views/mina_recept/recipe_card_widget.dart`** — `MinaReceptRecipeCard` (188 lines). Stateless. `onDelete` callback so parent retains `_handleDeleteWithUndo` with its `mounted` flow context. Confirmation dialog still gates delete in both swipe path and semantic-action path.
- [x] **A2. New `lib/views/mina_recept/empty_state_widgets.dart`** — `MinaReceptEmptyState` + `MinaReceptOnboardingBanner` (148 lines).
- [x] **A3. New `lib/views/mina_recept/discovery_shelves_widget.dart`** — `MinaReceptDiscoveryShelves` (69 lines). Receives the once-resolved `seasonalMonthFuture` from parent.
- [x] **A4. New `lib/views/mina_recept/selection_app_bar.dart`** — top-level `buildMinaReceptSelectionAppBar` function (68 lines). Bulk-delete confirmation + 7s undo SnackBar preserved; `mounted` → `context.mounted` (top-level fn, no State).
- [x] **A5. New `lib/views/mina_recept/filter_chip_helpers.dart`** — `getMinaReceptQuickFilterIds`, `handleMinaReceptQuickFilterToggle`, `MinaReceptSortChip` (131 lines).
- [x] **A6. Edit `lib/views/mina_recept_view.dart`** — main file rewritten with the inline code removed, the new symbols imported, and the call sites updated. 549 lines (was 997, -45%).
- [x] **A7. Update `docs/architecture/ACCEPTED_LARGE_FILES.md`** — bump entry from 687 → 549 with note explaining the BUT-441 extraction.

### Tier-2 specialist gates (both APPROVED)

- [x] **code-reviewer** — APPROVED with two LOW non-blocking nits (doc comment wording about file size; one cosmetic comment dropped). Both addressed in the commit.
- [x] **testing-specialist** — APPROVED. No test obligation introduced; original had no widget tests, e2e public-surface contract intact.

### Post-Sprint Steps
- [x] `dart analyze --fatal-infos` clean on touched files (verified pre-commit + lefthook will rerun).
- [x] No new tests required (per testing-specialist verdict).
- [x] Tier-2 markers touched (`.claude/state/code-review-done.marker`, `testing-review-done.marker`).
- [ ] Commit + push.
- [ ] Linear: BUT-441 → Done with summary.

### Continued blockers (NOT in scope per memory)

(unchanged from sprint N — see archived sprint N below for the full list.)

### What this means in plain language
- **One large file got broken into smaller pieces**: the "my recipes" screen was a single 997-line file doing too many things at once (filtering, sorting, recipe cards, empty states, discovery, selection mode). It's now split into a 549-line main file plus 5 focused helper files in a new `mina_recept/` subdirectory.
- **No behavior changes**: every button, swipe, and animation works exactly the same. This is a "rearrange the furniture" change, not a feature change.
- **Why now**: a "this file shouldn't grow past 687 lines" rule existed and the file had grown to 1017 lines — 48% over the limit. After this refactor, it's at 549 lines and back inside the rule.
- **Risk**: low. No tests existed for this view before; the public class is unchanged so the end-to-end tests that drive it as a whole still work; analyzer is clean; both the code-reviewer and testing-specialist agents reviewed and approved.

---

## Archived prior sprint (completed in commit 9598e784d)

BUT-702 closure + BUT-554 dep tracking refresh — 2026-05-06 (N) — closed BUT-702 with asymmetric-undo analysis + refreshed BUT-554 with quarterly check date.

## Archived sprint before (completed in commit 5b480e01f)

CI duration telemetry + ML runtime memo + Linear hygiene — 2026-05-05 (M) — shipped BUT-495/571 + rescoped BUT-488 + deferred BUT-397.

## Archived sprint before (completed in commit 6af9efc88)

Release polish + ops doc + Linear cleanup — 2026-05-05 (L) — shipped BUT-715/493 + reconciled BUT-738/724 + rescoped BUT-702.

## Archived sprint before (completed in commit 25ec5b025)

Tech-debt sweep + dep watch + web polish — 2026-05-05 (K) — shipped BUT-526/567/562/564/578/724/738 + rescoped BUT-581.

## Archived sprint before (completed in commits 245b71478 + a5288014f)

Dep hygiene + PWA polish + Linear cleanup — 2026-05-05 (J) — shipped BUT-500/519/524/718 + closed BUT-437 + rescoped BUT-431/530.
