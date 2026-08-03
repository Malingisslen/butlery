# Plan: group sharing that can actually be revoked (BUT-1797)

**Status: written 2026-08-03, not started. Needs plan-mode approval before any code.**

## Context

Sharing a recipe "with a group" is half-built and does nothing a user can rely on.

The UI offers it, and `shareRecipe` takes a `categoryIds` argument — but every path funnels
into `UnifiedRecipeService.createCollaborativeRecipe`, which accepts the parameter and never
forwards it (`unified_recipe_service.dart:786` → `:788`, where `_socialModule.createCollaborativeRecipe`
has no such field). Nothing else in `lib/` writes `socialData.categoryIds`; the only other
mentions are the model and its serializer. So:

- the "Grupper" section in the sharing panel never renders,
- `RecipeMemberManager.removeGroup` is unreachable in practice,
- and if it *were* reached it would strip a display id and revoke nothing, because access
  lives in `socialData.memberPermissions`, which the group share expanded into individual
  entries with no record of where they came from.

That last part is the real defect: **there is no provenance.** Once a group is expanded, a
member who arrived via the group is indistinguishable from one invited directly, so no code
can know whom a group-revoke should cut.

**Malin's decisions, 2026-08-03 — these are settled, do not re-open:**
1. The feature is wanted: share to a group, and be able to revoke that share.
2. A member who ALSO has a direct share **keeps access** when the group is revoked. A direct
   share is its own decision and is unaffected by the group one.
3. Snapshot, not live: a group share reaches whoever is in the group **at that moment**.
   Adding someone to the group later does not silently grant them access to recipes shared
   before they joined.

## The model

Add one field to `RecipeSocialData`:

```dart
/// Which grant(s) gave each member their access. Absent = a direct share, which
/// is the pre-existing behaviour and what every current document implies.
final Map<String, List<String>> grants; // uid -> ['direct', 'group:<categoryId>', ...]
```

Why a per-member list rather than a per-group member list: revoking has to answer "does this
person still have any reason to be here?", and that question is per member. A per-group map
would make the common case (one group, no overlap) marginally simpler and the decided case
(overlap) require a second lookup.

`memberPermissions` stays exactly as it is and remains the sole source of truth for access —
`grants` only records *why*. Nothing in `firestore.rules` needs to change, which is the point:
the access model is untouched, so this cannot open a hole.

## No migration (Malin, 2026-08-03)

The project holds only TEST recipes, so there is no production data to preserve. Add the
`grants` field, write it from the start, and delete any stale test document that gets in the
way rather than writing code to tolerate it.

Specifically: do NOT add a "read a missing `grants` as all-direct" compatibility path. It
would be dead code the day it shipped.

## Behaviour

**Sharing to a group** — resolve the group's members *now*, add each to `memberPermissions`
as today, and append `'group:<categoryId>'` to that member's `grants`. Record the group id in
`socialData.categoryIds` (the field that already exists and is currently dropped), so the
panel can render it.

**Sharing directly** — append `'direct'` to that member's `grants`.

**Revoking a group** — for each member holding `'group:<categoryId>'`: remove that entry. If
their `grants` list is now empty, remove them from `memberPermissions` too. If it still holds
anything (`'direct'`, or another group), they keep access. Then drop the group from
`categoryIds`.

**Revoking a member directly** — unchanged: remove them outright, whatever their grants say.
An explicit "remove this person" is the user overriding every grant at once.

## Files

- `lib/models/recipe_unified.dart` — the field, its serialization, `copyWith`.
- `lib/services/unified/unified_recipe_service.dart` — stop dropping `categoryIds`; forward
  it and the resolved grants into the create path.
- `lib/services/unified/operations/social_recipe_creation_service.dart` — accept them.
- `lib/services/unified/operations/modules/recipe_sharing_manager.dart` — record grants on
  both the create and the re-share path.
- `lib/services/unified/operations/modules/recipe_member_manager.dart` — the revoke algorithm
  above, replacing the current `categoryIds`-only strip.
- `lib/views/recipe_detail/recipe_detail_sharing_status.dart` — render a group as one row
  ("Familjen (4 personer)"), and restore the honest-but-now-accurate copy: the group dialog
  can say it removes the group's access again, because it will.

## Tests, and the ones that must fail first

The repo's standing rule: revert the fix, watch the named test redden, restore.

1. Group revoke removes a member whose only grant was that group.
2. **The decided case:** a member with `['group:x', 'direct']` KEEPS access when group x is
   revoked, and their `grants` afterwards is exactly `['direct']`.
3. A member in two groups keeps access when one is revoked.
4. A direct removal cuts a member who also holds a group grant.
5. Snapshot: someone added to the group AFTER the share does not appear in
   `memberPermissions` and is unaffected by the revoke.
6. A member revoked individually is gone regardless of how many grants they held.
7. The panel renders one row per group, and the group dialog's title, confirm button and
   tooltip all describe a real revocation (the widget test added on 2026-08-03 asserts the
   opposite today and must be updated in the same edit, not deleted).

## Interactions worth knowing before starting

- **BUT-1812** — re-sharing a recipe someone else already shared cannot write the
  `shared_content` row at all. A group share by a second sharer will hit that first. Decide
  BUT-1812's direction (widen the rule, or stop reusing `recipeId` as the doc id) before or
  alongside this, or group sharing will look broken for the second sharer for reasons that
  have nothing to do with this plan.
- **BUT-1785** was closed by the seam fix on 2026-08-03 — member writes now actually reach
  Firestore. Without that, none of this would have worked either.

## Open questions

None blocking. The three product calls are made and recorded above. Assumptions stated:
`memberPermissions` remains the only thing `firestore.rules` reads, and `grants` is
descriptive metadata that never widens access on its own.

## What this means in plain language

- Sharing a recipe with a group looks like it works today. It doesn't — the app forgets which
  group you picked the moment you tap share.
- This makes the app remember, so "un-share this group" can actually take the recipe back
  from exactly those people.
- If you shared with someone twice — once through a group, once directly — removing the group
  leaves them alone. You made that call twice; only one of them is being undone.
- People added to a group later don't get access to things you shared before they joined.
- Nothing changes about who can read what today; the security rules are untouched. This only
  records *why* someone has access, so it can be undone.
- Risk is low and reversible: existing shares keep behaving exactly as they do now.
