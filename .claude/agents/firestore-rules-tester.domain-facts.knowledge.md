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
- **Guest mode (BUT-920)**: `isAgeCompliant()` itself carries `!isGuest()`, so on every
  limb that ALSO calls `isAgeCompliant()` the limb's own `!isGuest()` is masked (deleting it
  reddens nothing); grade those with a PAIR mutant (both removed). A limb that calls
  `isAgeCompliant()` with no `!isGuest()` of its own (the `recipe_ratings` update limb) is
  where the clause inside the helper is load-bearing alone — pin a guest deny there.
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
- **The chat-list preview (`conversations.lastMessage`) has more than one write path, and a
  block gate on one does not reach the others.** BUT-2246 put BUT-2017's two-armed gate on
  a `conversations` update whose `affectedKeys()` include `lastMessage` (direct merge-set,
  dotted `lastMessage.status`, null: all DENIED for the blocked person). The second path is a
  sender EDIT of their own pre-block message: `syncConversationLastMessage` re-projects an
  edit into `lastMessage` under the Admin SDK (its `>=` tie rule exists so an edit refreshes
  the preview), so the same gate also sits on the messages sender `allow update` when
  `content` changes. The thread hides blocked authors (`MessagingService._filterBlocked`);
  the list row does not. Enumerate every writer of a denormalised field (client verbs AND
  server projections fed by another collection's limb) before passing "the preview is gated".
  A gate added to the messages sender limb is graded by `cook-snaps-and-message-mod` and
  `poll-votes` too: their sender-edit allows are the legitimate-path controls.
- **A Storage download-URL regex in rules that pins `users%2F<uid>%2F<folder>` but leaves the
  bucket as `[A-Za-z0-9._-]+` admits the same path in ANY bucket**, the attacker's own Firebase
  project included. Measured ALLOW on the `messages` fill-in (BUT-2294). A rule cannot read
  the bucket name, so pinning it needs a literal per environment. Also check whether the
  collection's CREATE limb validates the URL at all. `messages` create does not, which is
  what keeps the update-side gap from being an escalation. The foreign-bucket deny must use a
  `<other>.firebasestorage.app` bucket, the shape a new project gets: an `appspot.com` fixture
  leaves a mutant that keeps the suffix and widens only the project id green.
- **`isNotBlockedBy` is a bare `exists()` reading no field, and no READ limb in
  `firestore.rules` is block-gated** — a sentence saying a change to the helper would put it
  "on the read side" confuses reading the block doc's FIELDS with the read limb.
- **1:1 DM minor gate** (`passesMinorDmGate`): size!=2, or other party not minor, or
  creator is their friend. Group conversations (size>2) are DELIBERATELY ungated in
  rules — minor protection there is the separate `enforceGroupMinorMembership` Cloud
  Function; don't file "group DM has no minor gate" as a rules finding. (Moved here from
  the core card 2026-09-20 to keep that card under its cap; text unchanged.)
- **Household membership** (`households`/`diner_profiles`/`family_ratings`) is a
  DOC-READ gate (`get(households/{hid})` + uid in `memberUserIds`), not a path segment —
  every test must seed the household first. Household-admin is separate from app-level
  `isAdmin()`.
