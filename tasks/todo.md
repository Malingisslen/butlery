# Sprint Backlog

## Sprint: AutoSaveManager consolidation pt.2 — 2026-06-04 (iter-118)

Focused single-ticket Tier-C: BUT-1203 (the follow-up filed in iter-116). Closes to
**Done** if behavior-proven. Chosen for hot AutoSaveManager context + it advances the
BUT-904 epic cleanup without deepening the In-Review queue.

### Agent A: direct — BUT-1203 AutoSaveManager consolidation pt.2 `[Tier C]`

**Step 0 classification:** FITS (re-scoped during read).
- **Group-creation** (`create_group_dialog.dart`): single JSON key `group_creation_draft_v1`
  → fits `AutoSaveManager<Map<String, dynamic>>` (the non-String generic the BUT-904 test
  already proves). Migrate.
- **Recipe-list filter** (`recipe_list_viewmodel.dart:232 _persistActiveFilters`): does NOT
  use a single SharedPreferences key — it calls a typed `PersistenceService` facade with 8
  per-dimension setters (`setRecipeTimeFilters`, …) under a 300ms debounce. This is a
  multi-key typed store, not a single-key draft → **document as a non-fit exception**, like
  `recipe_auto_save_manager.dart`. No migration.

**Files touched:**
- EDIT `lib/widgets/social/groups/create_group_dialog.dart:33-156` — replace the inline
  `_loadDraft/_saveDraft/_clearDraft` JSON triad with `AutoSaveManager<Map<String,dynamic>>`.
  Key `group_creation_draft_v1` byte-identical; encode does the all-fields-empty → null
  (remove-key) check; decode = `jsonDecode as Map`. Friend-id resolution + setState stay
  widget-side. Drop `shared_preferences` import (keep `dart:convert`, keep `logger` — still
  used at the friend-resolve catch).
- CREATE `test/widget/social/groups/create_group_dialog_draft_test.dart` — behavior gate
  (currently MISSING): seed prefs → fields restore on open; type → key written; all-empty →
  key removed; commit → key cleared. Byte-identical-key assertions.
- EDIT (1 line) recipe-list-filter: add a `// BUT-1203:` exception note at
  `_persistActiveFilters` documenting why it stays on the typed PersistenceService facade.

**Blast radius:** 1 UI widget (group dialog) + 1 new test + 1 comment. Group draft is
JSON-map; key kept byte-identical → existing persisted drafts survive. No existing test
covered the group draft, so the new test is the behavior gate (without it the migration
would be unverified → In Review; with it → Done). recipe-list-filter untouched (doc-only).

**Product-intent flags:** none — internal persistence refactor, zero user-visible change.

**Rollback shape:** revert the commit; the dialog returns to its inline JSON triad, new
test file orphaned. No data migration to unwind (key unchanged).

- [x] **A1. Migrate group-creation draft → `AutoSaveManager<Map>`** `[Tier C]` — `create_group_dialog.dart`, key byte-identical. (BUT-1203)
- [x] **A2. Add group-draft behavior test** `[Tier C]` — `create_group_dialog_draft_test.dart` (restore/save/empty-removes/clear). (BUT-1203)
- [x] **A3. Document recipe-list-filter as a non-fit exception** `[Tier C]` — 1-line note at `recipe_list_viewmodel._persistActiveFilters`. (BUT-1203)

### Needs you (Tier D — flagged, not worked)
- Unchanged carry: store/console/deploy/secrets + monetization clusters; BUT-530/BUT-431
  cold-start (headless startup verification not possible).

### Awaiting Malin — In Review (carried)
BUT-904 (epic), BUT-1198, BUT-1199, BUT-1037, BUT-1039, BUT-918, BUT-912, BUT-946, BUT-1079.

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` on changed files
- [ ] Run new `create_group_dialog_draft_test.dart`
- [ ] Commit, push
- [ ] BUT-1203 → Done if behavior-test green (mechanical, behavior-preserving)

---

## ARCHIVED — iter-117 (CI/release tooling — shipped)

Shipped `303e2011c`. BUT-1192 (nightly cross-OS flake retry) + BUT-488 (release version-bump
+ changelog tooling: `release.yml` workflow_dispatch + `tools/release/bump_version.sh`). Both
→ Done. No follow-ups.

## ARCHIVED — iter-116 (BUT-904 AutoSaveManager extraction — shipped)

Shipped `0d61ca2bc` + `fe3ca8c74`. Generic `AutoSaveManager<T>` + 3 String-draft surfaces.
Epic → In Review (acceptance #3 = BUT-910 photo-import remains). Follow-ups: BUT-1203, BUT-1204.
