# Sprint Backlog

## Sprint: BUT-536 firebase_recipe_repository module extraction — 2026-05-06 (P)

Theme: large-file decompose cluster, second ticket. `lib/repositories/firebase/firebase_recipe_repository.dart` had drifted from 931 (accepted entry) → 1104 (+18%). Extracted three cohesive concern groups into the existing `lib/repositories/firebase/modules/` directory (matching the `recipe_legacy_validator.dart` pattern). No behavior changes; every `@override` surface preserved as a delegating wrapper.

**In Progress carry-overs (NOT in this sprint):**
- BUT-442 — repo migrations.
- BUT-760 — App Check; awaiting Firebase Console flip.

**Step 0 verification — done:**
- **BUT-536 fits.** File at 1104 (was 1009 in ticket; still drifting). Three clean extraction targets:
  1. **Tag operations** (~158 lines): `renamePersonalTagInRecipes`, `removePersonalTagFromRecipes`, `addRemovePersonalTagFromRecipesToBatch`. Read-side from the repo's perspective (no `read`/`update` calls).
  2. **GDPR export operations** (~40 lines): `exportPersonalRecipesByUser`, `exportTopLevelRecipesByOwner` (BUT-501). Need `validateOwnership` callback.
  3. **Query operations** (~60 lines): `fetchRecipesByTagId`, `findBySourceUrl`, `findByTitle`. Pure Firestore reads.
- Tests: 3 existing test files at `test/unit/repositories/firebase_recipe_repository*_test.dart` drive the public surface; tag cascade additionally covered via `test/unit/services/tagging/personal_tag_service_test.dart`. Internal refactor preserves all surfaces.

### Agent A: Module extraction

Specialists: `code-reviewer` + `testing-specialist` + `firebase-backend-security` (Tier-2 + Firebase trigger for `lib/repositories/`).

- [x] **A1. New `lib/repositories/firebase/modules/recipe_tag_operations.dart`** (192 lines after simplify-DRY) — `RecipeTagOperations` class. Three rename/remove cascade methods + private `_buildTagRemovalUpdate` helper deduplicating the two-field mutation map (`core.personalTagIds` arrayRemove + filtered `core.personalTags`).
- [x] **A2. New `lib/repositories/firebase/modules/recipe_gdpr_export_operations.dart`** (72 lines) — `RecipeGdprExportOperations` class. Both BUT-501 export paths; `validateOwnership` pre-flight preserved.
- [x] **A3. New `lib/repositories/firebase/modules/recipe_query_operations.dart`** (84 lines) — `RecipeQueryOperations` class. Three `findBy*` reads.
- [x] **A4. Edit `lib/repositories/firebase/firebase_recipe_repository.dart`** — instantiate the three modules in constructor; replace inlined methods with thin delegating wrappers. 1104 → 906 lines.
- [x] **A5. Update `docs/architecture/ACCEPTED_LARGE_FILES.md`** — entry 931 → 906 with the BUT-536 note.

### Tier-2 + Firebase + simplify reviews (all APPROVED)

- [x] **code-reviewer** — APPROVED (initial + simplify-fix delta).
- [x] **testing-specialist** — APPROVED, no new test obligation; existing tests cover behavior through public surface.
- [x] **firebase-backend-security** — APPROVED, no security regression. Auth-gate semantics + GDPR pre-flight + tag-cascade write paths all preserved byte-for-byte.
- [x] **/simplify three-agent pass** — clean except two micro-fixes applied (DRY helper extraction, redundant comment cleanup). Two larger follow-ups noted but out-of-scope: shared module typedef + `userId Function()` callback pattern across all three modules.

### Post-Sprint Steps
- [x] `dart analyze --fatal-infos` clean on touched files.
- [x] No new tests required (per testing-specialist verdict).
- [x] All 4 specialist markers touched after re-review of the simplify delta.
- [ ] Commit + push.
- [ ] Linear: BUT-536 → Done with summary.

### What this means in plain language
- **One large file got broken into smaller pieces**: the file handling all Firebase recipe data had grown to 1104 lines (accepted limit was 931, so 18% over). Now at 906 lines, with three new helper files in a `modules/` folder handling tag cascades, GDPR data export, and recipe queries.
- **No behavior changes**: every method still works the same way; the repository's public surface is unchanged. Tests still pass without modification.
- **Risk**: low. Three reviewers (code, testing, Firebase security) verified no regressions. The extracted modules use the same pattern that's already established in the codebase.

---

## Archived prior sprint (completed in commit 1c82cee20)

BUT-441 mina_recept_view facade extraction — 2026-05-06 (O) — view file 997 → 549 lines via 5 new files in `lib/views/mina_recept/`.

## Archived sprint before (completed in commit 9598e784d)

BUT-702 closure + BUT-554 dep tracking refresh — 2026-05-06 (N).

## Archived sprint before (completed in commit 5b480e01f)

CI duration telemetry + ML runtime memo + Linear hygiene — 2026-05-05 (M) — shipped BUT-495/571.

## Archived sprint before (completed in commit 6af9efc88)

Release polish + ops doc + Linear cleanup — 2026-05-05 (L) — shipped BUT-715/493.

## Archived sprint before (completed in commit 25ec5b025)

Tech-debt sweep + dep watch + web polish — 2026-05-05 (K) — shipped BUT-526/567/562/564/578/724/738.
