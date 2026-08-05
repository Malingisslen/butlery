# UNFILED — Linear hit its free issue limit on 2026-08-03

**These could not be filed as tickets.** The workspace refused new issues:
*"You've exceeded the free issue limit for this workspace."* They are recorded here
instead so they are not lost. File them the moment the tracker has room.

## 1. Leaving a group twice reports failure the second time

`leaveGroupConversation`'s no-oracle gate answers three situations with one reply, on
purpose, so it never leaks whether a conversation exists: missing conversation, caller was
never a participant, and **caller has already left** (an idempotent retry). All three return
`{removed: false, remainingParticipants: 0}`.

Since the 2026-08-03 commit the client treats `removed: false` as a failure and throws —
which was the point, because a silent no-op used to be spelled exactly like success. But a
double-tap, or a retry after a dropped response, now shows an error to a user who did leave.

Strictly better than what it replaced (silently claiming success), so not a regression — but
reachable by accident.

**The fix is caller-side.** The callable must not try to distinguish the cases; that would
make it an existence oracle over conversation ids, which is the property it was written to
preserve. Add an in-flight guard on the leave action in `conversations_viewmodel.dart` and
`group_detail_viewmodel.dart`, and treat a late `removed: false` after a successful local
departure as a no-op rather than an error.

Sits on top of BUT-1795 — once the path split is unified the missing-document case largely
disappears and only the genuine retry remains, so they may be worth doing together.

---

# Sprint salvage — open review findings (handoff)

**State: 95 files STAGED, nothing committed, tree clean, `dart analyze` clean, TypeScript clean.**
Plan: `tasks/todo.md` (top section). Backup of the original sprint tree:
`<scratchpad>/sprint-backup/`.

Six commit gates ran against the staged diff. Twelve blocking findings were raised; the ones
already fixed are listed at the bottom. **The items below are still open.** Every one names the
file, why it matters, and the fix the reviewer proposed — none needs re-deriving.

---

## 1. PRODUCTION DEFECT — `removeGroup` returns false; BUT-1785's fix does not work

**This is the only item here that is a live bug rather than a coverage gap. Do it first.**

`lib/services/unified/operations/social_recipe_operations.dart:173-181`

The seam chain, traced across five files:
- `:66` hands the constructor's `updateRecipe` to `RecipeMemberManager`
- `social_operations_initializer.dart:17-38` forwards `SocialOpsContext.updateRecipe`
- `unified_recipe_service.dart:410` binds it to `updateRecipe`; `:741` →
  `PersonalRecipeCrud.updateRecipe` → `personal_recipe_module.dart:242`, which is
  `if (!updatedRecipe.isPersonal) return false;`
- `recipe_member_manager.dart:228` filters on `r.isCollaborative` and rebuilds with
  `type: recipe.type`; `recipe_unified.dart:1474-1476` makes the two types mutually exclusive

So every group revoke ends at `recipe_detail_sharing_status.dart:259` → `commonUnknownError`.
`recipe_member_manager_test.dart` is green **only** because it stubs
`mockParentService.updateRecipe(any()) → true`.

**Fix:** bind `SocialOpsContext.updateRecipe` to `saveRecipeForSocialModule`
(`unified_recipe_service.dart:754` — "Unlike [updateRecipe], this does not reject collaborative
recipes"), which `SocialRecipeModule` already uses at `:339`. That is a production change and
needs its own plan. Add a test that drives `SocialRecipeOperations.removeGroup` with the seam
bound to the REAL terminal function, not a `→ true` stub.

---

## 2. Test-coverage gaps that block the gate

Each one is invisible today: the named mutation leaves the suite green.

**a. `firebase_data_export_repository.dart:465` — the new shopping-list export leg has no
query-level test.** Its collection, its `contentType` literal and its membership field are all
unpinned; a wrong one is a syntactically perfect query that throws nothing and matches nothing —
exactly how the menu leg stayed dead for a year. `seedShare` in
`firebase_data_export_repository_shared_content_test.dart` is already parameterised on
`contentType`; add a `shopping_list` case plus the third leg in the "legs do not bleed into each
other" case.

**b. `notification_preference_manager.dart:396-418` — the discard AND the eviction are both
uncovered.** `grep "tryFromJson\|notification_preferences_"` on the suite returns nothing. The
discriminating assertion is on the SECOND call, after the repository recovers with a non-default
payload: under the reverted spelling `getPreferences` caches `defaults()` for the full 10-minute
window and the recovered read can never win. Second test: assert the poisoned key is gone from
`SharedPreferences`.

**c. `offline_user_storage.dart:111` — `stale-properties` has no test.** The adjacent
`stale-ingredient` test (`offline_user_storage_test.dart:605-660`) is a four-line copy with one
literal changed; it already uses `coverage: 0.5` so it is not answered by the `coverage == 0.0`
branch.

**d. `recipe_social_stats.dart:58-62` — the owner-uid derivation has no test at all.**
`rating_statistics_denormalization_test` pins the callee given a correct uid; nobody pins the
caller deriving it. Returning null, or the classic wrong guess `currentUserId`, is silent.
The discriminating fixture exists in `recipe_social_stats_test.dart` (current user `user_789`,
recipe owner `user_123`).

**e. `recipe_sharing_manager.dart:612-622` — the fail-OPEN catch is untested, and its own comment
is why.** The comment says no unit test can see it; that is true of the rules *denial* and false
of the *catch*. Inject a `FirestoreRepository` whose `.doc().get()` throws
`FirebaseException(code: 'permission-denied')` and assert the `set` still lands with `sharedAt`
present. `_MockCollectionRef`/`_MockDocRef` already exist in
`shopping_repository_routing_module_test.dart:1796`. Narrow the comment in the same edit.

**f. `import_result_handler.dart` — two separate gaps.** None of the three route-argument branches
is asserted (reverting `arguments: matches.first` → `matches.first.id` leaves 17/17 green), and
the new refused-write branch has zero coverage (`grep duplicateMergeFailed test/` → nothing).
Reuse the router mirror at `recipe_save_navigation_test.dart:55-81`. Drive `replaceWithNew` and
`mergeBestFields` separately — each carries its own copy of the guard.

**g. `recipe_detail_sharing_status.dart` — nothing under `test/` renders this widget.** Both the
`isGroup` dispatch and the whole copy split can revert to the lying "Ta bort delning" copy with
the suite green. The Swedish strings are distinct, so `find.text` discriminates; the real
discriminator is a `Fake` `social` recording which method got which id.

**h. `shopping_member_management_dialog.dart:207-211, 300-305` — two of three `_rebaseMembers`
sites are unreachable.** `_RefusingCollaborativeOps` returns `false` unconditionally, so both
success branches never run. Add a success flag per operation; remove Bob, then change Cecilia's
permission, and assert the second declared base no longer carries Bob.

---

## 3. Worth doing but not blocking

- `recipe_detail_sharing_status.dart:300` — `_ShareeRow`'s tooltip is still
  `recipeSharingRevoke` on group rows: the third place the group action promises a revocation it
  does not perform.
- `social_export_manager.dart:365` — `sharedLists.truncated` joined the section OR with no
  positive fixture.
- `social_export_redaction.dart:119` — the fail-closed limb is mutation-dead; every fixture name
  is paired with a present uid. One item with a name and no uid key makes the deviation entry's
  "fails CLOSED" claim true rather than intended.
- `cleanup-deleted-ingredients.ts` / `bulk-retag.ts` — no `test:bulk-retag` suite exists at all;
  the cursor and the clamp are untested.
- `.claude/agents/testing-specialist.knowledge.md` is ~60k tokens against a stated ~35k CHARACTER
  budget and now has to be paged to read. It needs a curation pass.

---

## Already fixed this round (do not redo)

Rules `metadata: null` blanket deny · first-share probe failing closed · the retry that could
never succeed (now BUT-1812) · `shared_content` Art. 17 erasure gap · missing shopping-list
export leg · notification-preference cache poisoning · OCR tier skipping sanitization (pinned,
mutation-proven) · the redaction walk's missing sixth field (now driven off
`SharedShoppingListExport.nameKeysByOwnerIdKey`) · the merge write discarding its bool · the group
dialog's lying title and confirm button · the shopping writer's unpinned `sharedToUserIds` ·
the vacuous "not scrubbed first" cascade assertion · the default menu title branch.

## Tickets filed from this round

BUT-1809 (backfill), BUT-1810 (support runbook), BUT-1811 (Art. 15(4) record),
BUT-1812 (re-share writes nobody), BUT-1813 (why reviews miss cross-file disagreements).

## Unfiled finding — 2026-08-04, `flutter test` is red on a clean tree

Four files under `test/test_support/` are named `*_test.dart` but are shared BASE CLASSES with
no `main()`:

- `base_integration_test.dart`, `base_test.dart`, `base_unit_test.dart`, `base_widget_test.dart`

`flutter test` with no path argument discovers them by name, fails to load each one
("Undefined name 'main'"), and reports 4 failures. Last touched 2026-06-23, so this is not new.

**Why it has stayed invisible:** CI runs `flutter test test/unit` (sharded), never the whole
tree, so the job is green. Only a human or agent running bare `flutter test` sees the red — and
on a 20,000-test run the four failures scroll past in a wall of passes.

**Why it is worth fixing anyway:** a suite that is *always* 4-red trains everyone to read "some
tests failed" as normal, which is precisely how a real regression gets waved through. The repo's
own lesson says chronic-red disarms safety gates silently.

**Fix:** rename to `base_*_support.dart` (or move under `test/helpers/`) and update the imports.
Mechanical; no behaviour change.

Not filed: Linear is at its free-issue limit.

Measured on this run: 20,072 passing, 108 skipped, 4 failing — the four above and nothing else.

## Unfiled finding — 2026-08-04, an order-dependent test in photo import

`test/unit/viewmodels/photo_import/photo_import_draft_test.dart` →
*"clearPhoto (explicit user clear) discards draft and staged image"* failed once inside a
combined `flutter test test/unit test/widget` run (~20k tests), and passed:

- in isolation (9/9),
- across its whole directory, `test/unit/viewmodels/` (3440/3440).

**Not caused by the BUT-1797 change.** That change touches sharing, grants and l10n; its only
edit to shared test infrastructure is an ADDITIVE `removeGroup` override on
`FakeSocialRecipeOperations`, a class this test never constructs.

**Reproduction pattern, four samples:** passes in isolation (9/9) and across
`test/unit/viewmodels/` alone (3440/3440); fails in both large combined runs
(`test/unit` + `test/widget`, and unified+models+repositories+viewmodels+widget).
So it is load-dependent rather than order-dependent on a specific neighbour — which is what a
timing race looks like, and what makes it invisible in CI's sharded lanes.

**Likely root cause, stated as a hypothesis and not verified:** the test writes a real file to
disk, calls `vm.clearPhoto()`, and asserts `File(staged).existsSync() == false` after a single
`pumpEventQueue()`. If `clearPhoto` fires an unawaited async delete, one pump is a race that
widens under load. The repo's own rule is to fix a flake at its root rather than rerun until
green — the root here would be awaiting the deletion, or exposing a future the test can await.

**Why it is being recorded rather than fixed here:** it belongs to another area, and a fix
round for a failed review gate is the wrong place to start editing an unrelated suite. Note CI
runs `flutter test test/unit` sharded and never combines `test/unit` with `test/widget`, so this
ordering does not occur there — which is also why it has stayed invisible.

Not filed: Linear is at its free-issue limit.

## Ship rules that still apply

- Reviewers earn the gate by opening files with `Read`; editing a file un-proves it, so the
  affected gate must re-run after any fix.
- Nothing may be committed until every gate passes on the FINAL staged bytes.
- `firestore.rules` and `firestore.indexes.json` are in this change: deploy them explicitly,
  `--non-interactive`, **never `--force`** (13 live TTL policies are absent from the indexes file).
