# Sprint Backlog

## Sprint: iter-107 — Tier C refactor (file decomposition) — 2026-05-30 (Sat)

### Agent C (refactor) — large-file decomposition

- [x] **C1. BUT-1154 (1 of 4): decompose `photo_import_viewmodel.dart`** `[Tier C]` —
  Step 0: PLAN-STALE — file was 622 lines, not 721 as ticket claimed (drifted down). Has an
  875-line test suite = safe behavior-preserving refactor. Extracted the BUT-410 heirloom form
  state → `lib/viewmodels/photo_import/photo_import_heirloom_form_mixin.dart` (mixin on
  ImportBaseViewModel — shares notifyListeners/isDisposed; all external access is via public
  accessors so transparent). Trimmed WHAT-style doc bloat per code-style.md. 622 → **508**
  (under the 520 baseline). 28 passing tests still pass; the 3 failing tests are PRE-EXISTING on
  main (verified by reverting to HEAD — identical +28 −3), filed as a follow-up. ACCEPTED_LARGE_FILES.md
  updated. (BUT-1154, P3 — ticket stays In Progress, 3 files remain)

### Remaining on BUT-1154 (future iterations)
- `smart_import_view.dart` (803), `user_profile_edit_view.dart` (816), `photo_import_view.dart`
  (674) — all VIEWS (Tier B/C — UI risk; decompose into sub-widgets, verify visually).

### Post-Sprint Steps
- [x] `dart analyze --fatal-infos` clean
- [x] Full photo-import VM test suite (behavior preserved: +28 −3, 3 failures pre-existing on HEAD)
- [x] code-reviewer + testing-specialist on staged Dart — both CLEAN to commit
- [x] Added inline mixin test (5 tests, all green) pinning truncation/disposed/clear invariants
- [x] Filed BUT-1171 (LOW) for the 3 leaky pre-existing tests (test-harness artifacts, not prod bugs)
- [x] Commit (stage specific files — NOT `git add -A`), push to main
- [x] BUT-1154 progress comment (1/4 done — stays In Progress)

---

## Prior sprints (shipped)
iter-104 `b80aac380` (BUT-1055+1066), iter-105 closed BUT-969 premise-gone, iter-106 `c03789f69`
(BUT-975 Tier B → In Review), autonomy-tier policy `a3c49bd67`. Durable record: Linear + git.

> iter-107 note: a stray untracked file `notification_analytics_manager_repository_test.dart`
> came from accidentally popping `stash@{0}` (sprint3-salvageable, still preserved in the stash).
> Removed from the tree; recoverable via the stash. Do NOT `git add -A` blindly.
