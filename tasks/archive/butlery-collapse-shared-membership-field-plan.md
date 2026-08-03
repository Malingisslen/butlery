# Plan: collapse the two `shared_content` membership spellings into one

**Status: written 2026-08-03, not started. Needs plan-mode approval before any code.**

## Context

Every `shared_content` document currently carries the SAME recipient list twice:

- `sharedToUserIds` — what `firestore.rules` grants recipient read on (:722, :727), what the
  Art. 15 export selects on, and what `BaseSharedContentRepository` speaks.
- `sharedWithUserIds` — written by the three direct-share managers, read by nothing except
  the deletion cascade's union query.

The duplication is not a design. It is scar tissue: the two spellings drifted apart, rows
written under one were invisible to readers keying on the other, and on 2026-08-01 the fix was
to make every writer emit BOTH. That closed the bug and left a field that exists only so old
documents stay readable.

**Malin, 2026-08-03: the project holds only TEST recipes.** There are no old documents. The
compatibility field is protecting nothing, and half of the GDPR work on 2026-08-01/03 — the
export leg, the erasure union query, the residual probe pairs — is machinery for keeping two
copies of one fact in agreement.

Collapsing to `sharedToUserIds` deletes that whole class of bug.

## This supersedes a deviation entry — do that properly

`.claude/rules/accepted-deviations.md` currently says, of the 2026-08-01 export decision:

> Both spellings are named deliberately — the writers emit the same list twice, and an entry
> naming one invites a future reviewer to strip the other "for consistency".

That was written to stop exactly this change being made casually. It is not being overruled
casually: the premise it rests on (documents exist that only one spelling can reach) is false
in this project.

**Append a new dated entry to BOTH deviation files superseding it — never edit or delete the
old one.** The new entry should say: with no production corpus, the dual write is retired and
`sharedToUserIds` is the single membership field; the earlier entry stands as the record of
why it was ever dual.

## The trap that will bite a careless rename

`sharedWithUserIds` is ALSO the legitimate, sole field name on an unrelated collection:

- `firestore.rules:1247` — `match /recipe_comments/{commentId}`, where a comment carries a
  denormalized `recipeOwnerId` and `sharedWithUserIds` written at create time (BUT-458).
- `lib/models/recipe_comment.dart:44`, `lib/repositories/firebase/firebase_comments_repository.dart`.

A repo-wide find-and-replace would silently break comment read access. **Scope every change to
`shared_content` writers and readers, and grep by collection, not by field name.**

## The work

**Remove the write** of `sharedWithUserIds` from the three direct-share managers:
`recipe_sharing_manager.dart`, `social_menu_operations.dart`,
`shopping_social_share_module.dart`.

**Simplify the erasure leg.** `removeFromSharedContent` in `account-deletion-cascade.ts`
currently runs two `array-contains` queries and dedups by document id, purely because two
fields exist. It becomes one query. The `arrayRemove` of the second field goes; so does the
`legacyOnly` counter and the log line that reports it. The two probe pairs in
`probeResidualData` become one.

**Simplify the export.** `_sharedContentReceivedQuery` already reads only `sharedToUserIds`;
what goes is the doc comment explaining why it must, and the note about documents the client
cannot reach.

**Delete the stale test data** rather than tolerating it. If a test document exists with only
`sharedWithUserIds`, remove it; do not add a compatibility read.

## Tests

The suites added on 2026-08-01/03 encode the dual-field world and must be updated in the same
edit, not deleted:

1. `shopping_social_share_module_test.dart:451`, `recipe_sharing_manager_test.dart:287/:372`,
   `social_menu_operations_test.dart:194` each pin `sharedToUserIds` — these stay, and are the
   regression guard that the surviving field is still written.
2. `account-deletion-cascade.test.ts` — `scenario_adHocSharedContentMembershipIsScrubbed`
   currently proves BOTH spellings are cleared and that a legacy-only row is reached. Rewrite
   it to the single-field world; keep the owner-skip assertion and the "never written before
   it is deleted" check, which are about the NOT_FOUND poison-pill and remain true.
3. Mutation-test the survivor: remove `sharedToUserIds` from one writer and confirm that
   writer's test reddens. The whole reason this field matters is that a dropped membership
   field is invisible — no fake ever denies.
4. Rules suite unchanged: nothing in `firestore.rules` reads the retired spelling for
   `shared_content`, so the rules diff should be empty. If it is not, stop — that means
   something reads it that this plan did not find.

## Order

Do this **before** the two sharing plans (BUT-1797 group revoke, BUT-1812 re-share). Both
write the same row, and building either on two fields means writing the dual-write logic twice
more and then deleting it.

## What this means in plain language

- Every shared recipe currently stores the list of people twice, under two different names.
- That was a fix, not a design: the two lists drifted apart, and things that read one couldn't
  see rows written by the other. Making everything write both stopped the bleeding.
- It only exists to protect old data, and you don't have any — so it can go.
- Removing it deletes a whole category of future bug: two copies of one fact that can disagree.
- One thing to be careful of: the same field name is used, legitimately, by recipe comments.
  A careless search-and-replace would break who can read comments. The plan says so explicitly.
- It should happen before the two sharing features, because both write that same record.
