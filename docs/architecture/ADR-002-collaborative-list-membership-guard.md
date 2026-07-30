# ADR-002: Membership on a collaborative shopping list is changed through one named repository method that declares its base

**Status:** Accepted (2026-07-30)
**Ticket:** BUT-1726 (recorded retroactively by BUT-1752)
**Supersedes:** none

## Context

`/unified_shared_shopping_lists` documents carry their own access control: `ownerId` and the
`memberPermissions` map. `firestore.rules` forbids a non-owner from touching either, so any
write carrying one of those keys is making an access-control statement rather than editing
content. The three keys are enumerated once, in
`ShoppingOfflineWriteModule.privilegedKeys` (`ownerId`, `memberPermissions`, `createdAt`).

The problem BUT-1726 was opened for: `update` takes a whole `UnifiedShoppingList` and cannot
tell a *deliberate* membership change from a *stale* `memberPermissions` map riding along on
a rename. Guessing wrong is harmful in both directions — reinstating a member the owner
removed on another device, or dropping one that device added.

**The originally planned fix was small:** add an optional `accessControlBase` parameter to
`updateCollaborativeList`, and make the undeclared path strip the privileged keys. That
shape shipped first and was wrong in a way the tests could not see: **zero production
callers passed the new argument**, so add-member, remove-member, change-permission,
join-a-list and leave-a-list all silently wrote nothing while the UI reported success. The
owner believed access was revoked; the removed member kept their rules-granted write. The
three unit tests were green precisely *because* they hand-passed the new argument, which is
evidence about the module and never about the app.

An optional parameter is therefore not a guard. It is a convention, and a convention that
defaults every existing caller into the wrong branch.

## Decision

Membership changes go through a **named method on the repository interface**, and the
divergence from the original one-parameter plan is deliberate. Four parts, all load-bearing:

1. **`ShoppingRepository.updateCollaborativeListMembership(updated, base)`** — a named
   method on the *interface*, not an optional argument on `update`. `update` never writes
   access control at all. A caller that means to change membership says so by handing over
   `base`: the exact copy of the list it computed `updated` from. A forgotten optional
   argument can silently downgrade "remove this member" to a write of `updatedAt`; a missing
   *method* cannot compile.

2. **A dedicated service seam** — `ListMemberOperations` receives an injected
   `updateMembership` function (wired to `UnifiedShoppingService.updateSharedListMembership`
   → `ShoppingListManagementModule.updateListMembership` → the repository method). Every
   add / remove / permission-change / leave is re-typed at compile time instead of relying
   on each call site remembering to pass a flag. `ShoppingListManagementModule.updateList`
   keeps swallowing failures and returning a bool; `updateListMembership` **rethrows** and
   refuses to update local state, because "removed" and "the list moved under you" must not
   look the same on screen.

3. **`StaleAccessControlBaseException extends PermissionDeniedException`** — a distinct
   type, thrown by `ShoppingListPermissionGuards.restrictAccessControlToDeclaredBase` when
   the declared `base` disagrees with the stored document's access control. Subclassing
   keeps every existing `on PermissionDeniedException` handler catching it, while the
   *wording* can differ. **Its arm MUST precede the `PermissionDeniedException` arm** in
   `shoppingFailureMessage`'s `switch`, which takes the first match; reordering them
   silently reverts the member manager to "du saknar behörighet" — an invented cause, since
   the manager does have the right and their copy is merely older.

4. **A declared-base disagreement is a refusal, not a merge.** The write is rejected and the
   caller must re-read and let the user decide again against what the list says now. This is
   the opposite of the sibling item path (BUT-1665), which merges concurrent edits inside a
   transaction — a tick is commutative, "remove Bob" is not.

## Rationale

1. **A guard must fail closed at the call site, not at the write.** The dead-opt-in incident
   is the whole argument: a parameter nobody passes protects nothing and hides the gap
   behind green module tests.
2. **Type-level intent beats discipline.** Membership is rare and high-consequence; paying
   one extra interface method removes a class of silent no-ops permanently.
3. **Different failures need different sentences.** BUT-1696 established that a denied edit,
   a vanished list and a broken connection are three different things to tell someone
   standing in a shop. A stale membership base is a fourth, and it is the only one fixed by
   reloading.
4. **Refusing beats merging for access control.** Replaying a removal computed against a
   member list the user never saw is exactly the harm the ticket exists to prevent.

## Implications

- **New membership code MUST route through `updateCollaborativeListMembership`.** A write of
  `ownerId` / `memberPermissions` reaching `update` is stripped, and the strip is logged as a
  `granted:false` audit row — treat such a row as a bug in the caller, never as a working
  path.
- **A personal list throws.** `ListType.collaborative` only; routing a personal list here
  would write it into the shared collection.
- **Tests must drive the ENTRY POINT** (dialog / coordinator), never hand-pass `base`.
  Hand-passing is exactly how the dead opt-in shipped green. `BUT-1749` adds the widget-level
  counterpart on the member-management dialog.
- **Review discipline (BUT-1752):** a diff touching this seam is reviewed by
  `firebase-backend-security`, and its marker must name **`updateCollaborativeListMembership`
  explicitly** — not merely the files. The failure mode here was a method that existed and
  was never called, which a file-level marker cannot distinguish from a method that works.
- **Do not "simplify" the named method back into an optional parameter.** That is the shape
  this ADR rejects, with a shipped incident behind it.

## Residual, still open

The privileged-key strip sits *after* `requireNoPrivilegeEscalation`, so it only helps the
owner: a non-owner's plain content edit carrying a stale member map still throws before
reaching the strip — a false denial of a write the rule would have allowed. The real fix is
to run the escalation guard against the payload that will actually be written rather than
against the raw entity.

Separately, this strictening *exposed* (rather than caused) a product gap:
`canManageShoppingList` grants a non-owner `admin` member management and `leaveList` is
offered to every member, but the update rule lets no non-owner touch `memberPermissions`.
That UI is dead, and now says so out loud.

## Cross-references

- Interface contract: `lib/repositories/interfaces/shopping_repository.dart`
  (`updateCollaborativeListMembership`).
- Implementation + the `accessControlBase` seam:
  `lib/repositories/firebase/modules/shopping_repository_routing_module.dart`.
- The guard that refuses: `ShoppingListPermissionGuards.restrictAccessControlToDeclaredBase`
  in `lib/repositories/firebase/modules/shopping_list_permission_guards.dart`.
- Privileged-key set: `ShoppingOfflineWriteModule.privilegedKeys` in
  `lib/repositories/firebase/modules/shopping_offline_write_module.dart`.
- Service seam: `lib/services/unified/operations/collaborative_shopping/list_member_operations.dart`
  → `UnifiedShoppingService.updateSharedListMembership` →
  `ShoppingListManagementModule.updateListMembership`.
- Exception + wording: `lib/core/exceptions/permission_exceptions.dart`,
  `lib/services/unified/shopping_failure_message.dart`.
- The contrasting merge decision for item edits: BUT-1665 (`mutateCollaborativeList`), and
  the accepted offline tradeoff in `docs/architecture/ACCEPTED_DEVIATIONS.md` (BUT-1683).
