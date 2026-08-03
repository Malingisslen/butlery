# Plan: re-sharing a recipe someone shared with you (BUT-1812 + the permission)

**Status: written 2026-08-03, not started. Needs plan-mode approval before any code.**

## Context

Two things are tangled here, and they have to ship together or the result is worse than
today.

**1. Re-sharing is broken outright.** `shared_content` documents for recipes use the recipeId
as the document id. If user B re-shares a recipe A already shared, `firestore.rules` refuses
both the existence probe (`allow get`, :724) and the write (`allow update`, :733) — B is
neither the sharer nor a shared member. A denied read therefore *proves* the write is denied;
no payload rescues it. B's recipients get no read grant and no Art. 15 export row, while the
UI reports success. That is BUT-1812.

**2. The permission that should govern it is half-built.** `socialData.allowMemberInvites`
exists on every shared recipe, is serialized correctly, defaults to **true**, and is read by
exactly one service (`social_recipe_permission_service.dart:150, :210`). Two other modules
carry comments saying they ought to check it and don't
(`recipe_permission_module.dart:76`, `group_permission_module.dart:88`). No screen ever sets
it, and `firestore.rules` never reads it.

So fixing (1) alone would swing re-sharing from "nobody can" to "everybody can, always" —
strictly worse, because it would send recipes to people the owner never chose, silently.

**Malin's decisions, 2026-08-03 — settled:**
1. Re-sharing should be possible **when the owner has granted it**.
2. **Per-share**, not an account-wide setting. The owner decides each time they share.
3. Default **off** (recommended and not contested). Re-sharing sends your recipe to people
   you never chose, so it is opt-in, not opt-out.

## The shape

**Owner chooses, per share.** A toggle in the share sheet — Swedish copy to be written with
the existing sharing strings, along the lines of "Låt mottagare dela vidare" — writing
`socialData.allowMemberInvites`. Changeable afterwards from the sharing panel, because a
regret needs an undo; that is the same instinct behind BUT-1797.

**The server enforces it.** This is the half that makes it a permission rather than a
suggestion. `firestore.rules` must gate a non-owner's `shared_content` write on the source
recipe's `allowMemberInvites`, so a tampered client cannot re-share what the owner closed.

**Then, and only then, unblock the write.** Two candidate fixes for BUT-1812, and this is a
real design choice that wants deciding before code:

- **(a) Widen the update rule** so a member listed in `sharedToUserIds` may extend the
  recipient list. Smaller change, but it lets a recipient rewrite most of a document the
  original sharer owns; the rule would need to pin every other field.
- **(b) Stop reusing `recipeId` as the document id** — let each share write its own auto-id
  document, the way `social_menu_operations` and `shopping_social_share_module` already do.
  Cleaner and matches the two sibling writers. It changes the read model, which would
  normally need a migration story — with only test data, it does not.

(b) is more consistent with the rest of the codebase, and with no real data to migrate its
main drawback disappears — so take (b) unless something else argues against it.

BUT-1809 (the backfill over the same corpus) is very likely moot for the same reason: it
exists to rescue legacy `sharedWithUserIds`-only documents, and there is no legacy.

## No back-compat concern (Malin, 2026-08-03)

The project holds only TEST recipes. There is no production data to protect, so:

- set the model default to `false` and move on — no "treat missing as false" special case,
  no migration, no dual reading path;
- if a stale test document is inconvenient, delete it rather than writing code to tolerate it.

Do not add compatibility scaffolding to this plan. It is the kind of code that survives long
after the reason for it, and here the reason never existed.

## Tests, and the ones that must fail first

1. A non-owner re-share is REFUSED when `allowMemberInvites` is false — asserted at the rules
   level on the emulator, not only in Dart, since the client is not the authority.
2. The same re-share SUCCEEDS when it is true, and the new recipients actually appear in
   `sharedToUserIds` (the field the recipient's read grant and the Art. 15 export both key on).
3. The owner's own share always works — the flag governs OTHERS re-sharing, never the owner.
4. The owner can always share, regardless of the flag.
5. The toggle round-trips: set at share time, read back on the panel, changeable afterwards.
6. Mutation-test each: flip the rule's conjunct, watch the deny test go green and redden the
   allow — the repo's standing rule, and the one that caught the metadata guard on 2026-08-01.

## Interactions

- **BUT-1797** (group share + revoke) has its own plan. Re-sharing and group-sharing both
  write the same `shared_content` row, so whichever lands second inherits the other's shape.
- **BUT-1809** — the backfill over the same corpus. Decide (a) vs (b) before it runs.
- **BUT-1798** closed the erasure half: a recipient's uid is now removed on account deletion.
  A re-share must not reintroduce a uid the cascade cannot reach — the union query added
  there covers both spellings, so as long as re-shares write the same two fields, it holds.

## What this means in plain language

- Right now, if someone shares a recipe with you, you cannot pass it on at all. The app lets
  you try and quietly does nothing.
- After this, you can — but only if the person who shared it with you allowed it, and they
  decide that each time they share.
- The default is off. Sharing a recipe onward sends it to people the original owner never
  picked, so it should be something they say yes to, not something they forget to say no to.
- The check lives on the server, not just in the app, so it holds even if someone tampers
  with the app.
- There is nothing to migrate: the project holds only test recipes, so the default is simply
  off from the start.
