# firestore-rules-tester — chapter: domain-facts

## Builder shapes

### `validRecipeBody` (firestore-rules.test.ts)

Recipe documents at `/users/{userId}/recipes/{recipeId}` require:

```ts
{
  core: {
    title: string,
    tagResult: {
      tags: [],
      allergenStatus: { [allergen]: "free" | "contains" | "unknown" },
      dietaryStatus:  { [diet]:     "free" | "contains" | "unknown" },
      coverage: 0..1,
      unknownIngredients: [],
      generatedAt: Date,
      generatorVersion: string,
      isPartial: boolean,
      schemaVersion: 1,
    },
  },
}
```

Rules validator may reject unknown fields or out-of-range coverage — test both happy
and malformed shapes when the validator changes.

### Domain-specific rule facts (re-check against, don't re-derive)
- **Age gate**: `isAgeCompliant()` fails CLOSED (no claim → CEL undefined → deny).
  `birthYear`/`isMinor` are CF-only-written on BOTH `users/{uid}` and
  `users/{uid}/settings/{settingId}` — create requires absent, update requires unchanged;
  test both docs. Adding the gate to an EXISTING create rule fails closed every prior
  create-allow test lacking the claim — grep `authenticatedContext(<actor>)` for that
  collection whenever a gate is added.
- **`conversations/{id}/participants` roster**: a GROUP's parent conversation doc is
  written under `users/{creator}/conversations/{id}` and the top-level doc doesn't exist
  until the first message — a rule attesting only via `get(parent)` denies every group
  roster write permanently. Shipped shape: `attestedWriter()` (parent names writer AND
  subject) OR `rosterUnclaimed()` (parent doc absent — bootstrap), read via
  `exists(.../{own uid})`, delete NARROWER than create (self-only). Test with the
  writer's REAL `WriteBatch` (roster + membership in one commit) — a failed batch prints
  a `false` verdict for EVERY doc in it, including ones allowed on their own, so attribute
  the deny with a separate probe.
- **A blocking conjunct guarded by `!('f' in request.resource.data) ||` is DEFEATED BY
  OMITTING `f`, so "the write side denies a blocked caller" is true of OUR client and false
  of the rule.** `recipe_comments` and `recipe_ratings` spell the BUT-459 gate
  `!('recipeOwnerId' in request.resource.data) || isNotBlockedBy(...)`; `user_notifications`
  reads a REQUIRED field (`userId`) and is unconditional. Every suite fixture supplies the
  denormalised field, so nothing reddens and the gap is invisible from the test names. Check
  each blocking call site for its guard before passing any sentence contrasting an open READ
  limb with a closed write side — that contrast is the load-bearing clause of the deviation
  entry it usually sits in (BUT-2054, 2026-09-09).
- **`isNotBlockedBy` sits on CREATE limbs only** (`social_requests`, `recipe_comments`,
  `recipe_ratings`, `user_notifications`) and is a bare `exists()` reading no field — so no
  READ limb in `firestore.rules` is block-gated, and a sentence saying a change to the helper
  would put it "on the read side" confuses reading the block doc's FIELDS with the read limb.
- **1:1 DM minor gate** (`passesMinorDmGate`): size!=2, or other party not minor, or
  creator is their friend. Group conversations (size>2) are DELIBERATELY ungated in
  rules — minor protection there is the separate `enforceGroupMinorMembership` Cloud
  Function; don't file "group DM has no minor gate" as a rules finding. (Moved here from
  the core card 2026-09-20 to keep that card under its cap; text unchanged.)
- **Household membership** (`households`/`diner_profiles`/`family_ratings`) is a
  DOC-READ gate (`get(households/{hid})` + uid in `memberUserIds`), not a path segment —
  every test must seed the household first. Household-admin is separate from app-level
  `isAdmin()`.
