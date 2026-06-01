# Sprint Backlog

## Sprint: iter-111 — Tier A test-gap hardening (iter-110 follow-ups) — 2026-06-01 (Mon)

Close the two test gaps the testing-specialist flagged during iter-110's commit review. Both Tier A,
both directly extend iter-110 tests (warm context), both → Done.

### Agent A — DI forwarding + heirloom coverage
- [x] **A1. BUT-1174: DI forwarding test for onShareError (SocialRecipeOperations → manager)** `[Tier A]`
  - Construct a real `SocialRecipeOperations` (via the MockDIContainer ServiceLocator bridge so
    RecipeSharingManager's `ServiceLocator.get<FirestoreRepository>()` resolves), pass an `onShareError`
    sink + an at-cap collaborative recipe, call `shareRecipe`, assert the sink fires with
    `errorShareCapReached`. Proves the DI hop the leaf-level manager test can't see.
  - File: `test/unit/services/unified/operations/social_recipe_operations_test.dart`.
- [x] **A2. BUT-1175: VM-level heirloom-pending upload test for saveImportedRecipe** `[Tier A]`
  - In `photo_import_viewmodel_test.dart`, stage a pending `HeirloomDraft` on the registered bridge +
    a `MockStorageRepository` + authed `PermissionService`; call `saveImportedRecipe()`; assert upload
    fires on success and `errorAuthentication` + draft-restored on the signed-out path. Uses the new
    iter-110 `@visibleForTesting` setters + ServiceLocator bridge.
  - File: `test/unit/viewmodels/photo_import_viewmodel_test.dart`.

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` clean on changed files
- [ ] Relevant test suites green
- [ ] code-reviewer + testing-specialist markers
- [ ] Commit, push to main
- [ ] Linear: both → Done (Tier A, test-proven)

---

## Sprint: iter-110 — Tier A quality cluster (test-quality + error-surfacing) — 2026-06-01 (Mon)

Shipped `329991f0a`. BUT-1056 (share cap-rejection → UI via onShareError callback), BUT-1171 (photo-import
save tests — bridged production ServiceLocator + removed shadow-field seam, 31/31 green), BUT-1172 (2
instanceReady re-bind edge-case widget tests). All → Done. Follow-ups BUT-1174 + BUT-1175 filed (worked in iter-111).

---

## Prior sprints (shipped)
iter-104 `b80aac380`, iter-105 (BUT-969 premise-gone), iter-106 `c03789f69` (BUT-975 Tier B), iter-107
`d881cbf27` (BUT-1154 1/4), iter-108 `9159fbce9` (BUT-1170), iter-109 `0181823fa` (BUT-1168 wave),
iter-110 `329991f0a` (BUT-1056/1171/1172). Durable record: Linear + git.

> Tree hygiene: `docs/cleanup/deletable-files-report.md` is an untracked parallel-session/hook artifact —
> not mine, leave it. `stash@{0}` (sprint3-salvageable) must stay preserved. Do NOT `git add -A` blindly.
