# Sprint Backlog

## Sprint: AutoSaveManager extraction — 2026-06-04 (iter-116)

Focused single-ticket Tier-C refactor. The pure-Tier-A quick-win backlog is drained
(confirmed via full 60-ticket backlog scan); 8 Tier-B items already sit In Review
awaiting Malin. The highest-leverage autonomous work now is a **closes-to-Done**
refactor, not more Tier-B UI that just deepens her review queue.

### Agent A: direct (refactor) — BUT-904 AutoSaveManager<T> extraction `[Tier C]`

**Step 0 classification:** FITS. Re-scoped ticket (2026-05-28) is accurate — 5 per-surface
draft-persistence copies exist with a near-verbatim `_loadDraft/_saveDraft/_clearDraft`
try/catch triad over SharedPreferences; `recipe_auto_save_manager.dart` is the
RecipeFormState-coupled exception. Acceptance: create generic `AutoSaveManager<T>` +
migrate ≥2 surfaces + keep recipe-form as documented exception. (Acceptance #3, BUT-910
photo-import adoption, is its own separate ticket and stays a follow-up.)

**Files touched:**
- CREATE `lib/services/persistence/auto_save_manager.dart` (~130 lines) — generic primitive.
- CREATE `test/unit/services/persistence/auto_save_manager_test.dart` — String + non-String T,
  empty→remove, decode-error-safe, debounce coalescing, clear, dispose-cancels-timer.
- EDIT `lib/widgets/recipe/comment_form_widget.dart:48-116,177-194` — replace triad with
  `AutoSaveManager<String>` (key `comment_draft_v1_<recipeId>` unchanged).
- EDIT `lib/views/import_via_url_view.dart:58-141` — same (key `url_import_draft_v1` unchanged).
- EDIT `lib/views/fran_sociala_medier_view.dart:86-185` — same (key `text_import_draft_v1` unchanged).

**Blast radius:** 3 UI surfaces, all String drafts. Keys kept byte-identical → existing
persisted drafts survive. `comment_form_widget_test.dart` (254 lines, tests load/save/clear
cycle under the real key via mocked prefs) is the behavior-preservation gate — it must stay
green WITHOUT modification. No Firestore, no rules, no platform code. Group-creation
(`create_group_dialog.dart`, JSON payload + friend-id resolution) deferred to a follow-up —
its extra decode complexity isn't worth bundling into this diff.

**Product-intent flags:** none — pure internal refactor, zero user-visible change.

**Rollback shape:** revert the commit; the 3 surfaces return to their inline triads, new
files are orphaned/deleted. No data migration to unwind (keys unchanged).

- [x] **A1. Create `AutoSaveManager<T>`** `[Tier C]` — `lib/services/persistence/auto_save_manager.dart`: generic SharedPreferences draft primitive (load/save/clear/flush/dispose, optional debounce, best-effort try/catch + AppLogger). (BUT-904)
- [x] **A2. Unit-test the primitive** `[Tier C]` — `test/unit/services/persistence/auto_save_manager_test.dart` (13 tests green: load/save/clear/debounce/dispose/best-effort/non-String generic). (BUT-904)
- [x] **A3. Migrate comment composer** `[Tier C]` — `comment_form_widget.dart`; existing widget test green UNMODIFIED. (BUT-904)
- [x] **A4. Migrate URL import** `[Tier C]` — `import_via_url_view.dart`. (BUT-904)
- [x] **A5. Migrate text import** `[Tier C]` — `fran_sociala_medier_view.dart`. (BUT-904)

### Needs you (Tier D — flagged, not worked)
- Carried from iter-115: BUT-1169, BUT-838, BUT-934, BUT-1187, onRecipeDeleted gen-2 deploy
  (all need prod/console/deploy access). BUT-530/BUT-431 (main.dart cold-start) need
  startup verification not possible headless. No change this iter.

### Awaiting Malin — In Review (8 Tier-B, carried)
BUT-1198, BUT-1199, BUT-1037, BUT-1039, BUT-918, BUT-912, BUT-946, BUT-1079 (pt1).

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` on changed files
- [ ] Run `comment_form_widget_test.dart` + new `auto_save_manager_test.dart`
- [ ] File follow-up: group-creation migration + recipe-form-exception doc
- [ ] Commit, push
- [ ] BUT-904 → Done if test-proven (mechanical, behavior-preserving), else In Review

---

## ARCHIVED — iter-115 (paused)

(Prior content: loop paused at iter-115; 10 tickets shipped, 8 Tier-B In Review.
Superseded by this sprint which resumed on the AutoSaveManager refactor.)
