# firestore-rules-tester — chapter: vacuity

- **A nullable map has FOUR stored states, not two — absent, present-with-null,
  present-as-a-map-WITHOUT-the-key-you-chain-into, and fully populated — and each is a
  separate rule branch needing its own fixture.** The third is the one a short comment
  always omits and the one production writes most often (`Message.*Share` factories and
  `writeGroupSystemMessage` all store `metadata` as a map with no `poll` key). **An `is
  map` guard does NOT separate "map without the key" from the real value — a map without
  the key IS a map.** Enumerate shapes by GREPPING THE WRITERS of the field, never from
  the two shapes a null-safety discussion suggests (`poll_votes.pollIsOpen()`, BUT-1832).
- **Absent and present-null can carry OPPOSITE verdicts in one defaulting chain** —
  `d.get('metadata',{}).get('poll',{}).get('isClosed',false)==false` lets ABSENT cascade
  to a falsy leaf (ALLOW, a vote seated with no poll at all) while NULL CEL-errors
  (DENY). A suite pinning only the null case reads as coverage and leaves a live allow.
  Pin BOTH on every defaulting chain, and state each verdict — "both are empty" is the
  losing intuition.
- **A chained `is map` guard (`m is map && m.get('poll', null) is map && …`) needs ONE
  mutant PER GUARD, and each guard's kill set is a different fixture.** Measured on the
  `messages` sender limb (BUT-2092): dropping both guards together killed three tests and
  said nothing about which guarded what; separately, the outer guard killed the absent- AND
  null-`metadata` edits (`.get(k, null)` makes those one state), and the inner guard killed
  only the map-without-`poll` share edit. A one-way flag on the PRE-state also bypasses
  through DELETE-then-CREATE at the same id when the create limb does not constrain the
  field — measured allowed on the same limb; check the create limb before calling any
  update-limb conjunct "one-way".
- **The ELSE branch of an `is map` ternary is the security decision, not the guard
  itself.** `x is map ? x.get(k,d) : null` keeps a null-parent deny; `x is map ?
  x.get(k,d) : {}` re-defaults it to ALLOW. Neither closes the ABSENT case on its own.
  Probe both spellings before a comment calls either one "the repair."
- **An `affectedKeys().hasOnly([...])` allow-list needs one deny test PER KEY THE APP
  MIGHT PLAUSIBLY ADD, not one per key a test happened to try.** Widening the messages
  RECEIPT branch by one token (`+ 'metadata'`) — a one-token edit a future ticket would
  make — leaves 26/26 green while handing every participant the whole inline poll store.
  `hasOnly` is TOP-LEVEL, so a nested privilege escalation is caught only because the
  parent key is named; enumerate the collection's real top-level keys and pin the
  privileged ones by name (BUT-1832). **The DENY-list mirror
  (`!affectedKeys().hasAny([...])`) fails more quietly still: a key that every fixture
  AND every payload holds CONSTANT is never varied, so nothing tests it while the suite
  reads as covered** — `conversations`' `createdAt` and `participantIds` sat that way
  through two tickets because ONE builder supplied both sides. Audit a deny-list key by
  key, asking which test MOVES it; "the payload round-trips" is the smell (BUT-1831).
- **Two new conjuncts can mask each other**: a missing-required-key test alone can pass
  even with the neighbouring `is list`/`is map` type-guard deleted, because the absent
  key already CEL-errors first. Pin the type guard separately with a WRONG-TYPE payload,
  not just a missing-field one. The converse holds too: a `hasAll([...])` whose every key
  also carries an `is <type>`/`== value` conjunct is UNREACHABLE (deleting it reddens
  nothing) — report it as redundant, not as covered by the missing-field denies. And pick
  the wrong type per guard: `.size()` answers on list, map AND string, so an `is list` or
  `is string` beside a size bound is pinned only by a type that still has `.size()`
  (a string for a list, a one-element list for a string).
- A collection with no root `keys().hasOnly()` validator silently accepts new top-level
  fields — pin a regression test that fails the day a `hasOnly([...])` is added without
  the new field, rather than trusting the absence of a validator to stay noticed.

- **In a rules-are-not-filters LIST deny, WHICH rows force the refusal is a quantifier over
  the SEED — and a MEMBERSHIP arm can make another person's row readable to the caller.**
  Walk the read limb per matching row against the fixture; never infer the set from a
  neighbouring fixture comment, whose subject is usually a DIFFERENT actor. Measured on
  `household_allergen_shares` (BUT-1693): "h4 and h5 are what refuse this query" was false,
  because the seed makes B a member of h5, so B reads A's `h5_A` through the membership arm
  (the arm tests the HOUSEHOLD, not the row's owner) and `h4_A` alone refuses. The sentence
  came from the fixture comment "A is not a member of h5" — a fact about A, read as a fact
  about B. The TEST is self-guarding (it asserts failure, so a seed change making every match
  readable reddens it); the ENUMERATION in its comment is not guarded by anything, so strike
  it rather than reword — a corrected enumeration is a fresh unmeasured claim.
- **A deny on a CORRUPT body (the gated fields absent) is produced by error-absorption across
  EVERY arm of a multi-arm read limb, so no arm is attributable — the comment above such a test
  states the VERDICT and its production consequence, never the mechanism.** Measured on
  `household_allergen_shares` R13 (BUT-1693, rules `452e81a6` / suite `5efc443c`): reading
  `h6_A`, body `{trackedAllergens:[…]}`, leaves the `resource == null` arm a clean false and
  both remaining arms CEL-erroring on the absent `userId`/`householdId`. True, and graded by
  NOTHING — a defaulting rewrite (`resource.data.get('userId','') == request.auth.uid`) keeps
  the deny and the suite green — which is the most durable kind of comment rot. The membership
  arm is dead TWICE over wherever the fixture never seeds the household (`households/h6` is not
  in the seed), so naming it reads as attribution of an over-determined arm. An error-text probe
  measures the RULE's evaluation, which is a DIFFERENT OBJECT from the TEST's coverage; only the
  latter belongs above a test, so such a measurement is archived, never commented.
  **What such a test IS worth is its ONE kill: the HARMONISATION mutant.** Adding the
  path-derived delete's own arm (`shareId.split('_')[1] == request.auth.uid`) to the read limb
  goes 51/52, killing R13 alone — so it is the sole guard against making READ path-derived to
  match DELETE, the plausible edit, since the repository documents the delete limb's
  path-derivation as deliberate and invites the symmetry.
- **A `cannotModify([...])` key can be STRUCTURALLY unreachable when a neighbouring
  conjunct pins the same field to `request.auth.uid` on BOTH the pre- and post-state.**
  `weekly_menu_plans` names `userId` in `cannotModify` while also requiring
  `uid == resource.data.userId && uid == request.resource.data.userId`, so no payload can
  fail the immutability key alone — dropping `'userId'` from `cannotModify` reddens NOTHING
  (measured 2026-08-27). The deny test is real; only its ATTRIBUTION is wrong. Probe every
  key of a multi-key `cannotModify` list separately, and report an unreachable key as
  "guards the pair" rather than as covered.
  **A comment arguing a field is EXCLUDED from `cannotModify` because "absent -> present is
  an affectedKeys() hit" is scoped to LEGACY rows ONLY, and the quantifier is where it goes
  false.** Measured on `recipe_ratings` (BUT-2057): adding the field to the list kills the
  legacy merge-add and SPARES a re-rate of a row that already carries it (the key is not in
  the diff when the value is re-sent unchanged), so "would refuse every re-rate of an existing
  rating" is true only while no row has the field — and the SAME COMMIT's repository change
  starts writing it, i.e. the sentence rots by its own commit. Probe the exclusion with TWO
  fixtures, legacy and already-populated, and quantify over the legacy population only.
  **An `affectedKeys().hasOnly([...])` added BESIDE a `cannotModify([...])` whose keys it
  excludes MASKS the whole `cannotModify`** — every pin deny is then denied twice, so deleting
  `cannotModify` reddens nothing (`recipe_ratings`, BUT-2077). Re-attribute the pin tests to
  the pair; do not call either conjunct proven alone.
- **An `isAuthenticated()` conjunct on a read rule whose disjuncts compare
  `request.auth.uid` is MASKED for every LIST test — deleting it reddens nothing.** With no
  auth, `resource.data.f == request.auth.uid` is already unprovable, so the engine refuses
  the query on the disjunct alone; only opening the rule to `if true` kills the signed-out
  deny (measured on `blocks`, BUT-1917: `if isAuthenticated() && (...)` -> `if (...)` left
  14/14 green, `if true` killed 4). Report such a signed-out test as pinning the null-auth
  deny, never as attributing to `isAuthenticated()`, and never let a comment say the rule
  "opens with `isAuthenticated()`, and that is what refuses this".
- An `allow update` textually identical to `allow create` still needs its OWN allow
  test — a client `set()` on an existing doc is an update, and a toggle/edit path can
  live entirely there, unproven by create-side coverage alone. **A presence-keyed conjunct
  (`!('f' in request.resource.data) || gate(...)`) copied onto an UPDATE limb is pinned only
  by the production verb that ADDS `f`, i.e. `set(merge:true)`; a `.update()` of unrelated
  keys exercises the already-present and the still-absent states and never the transition.**
  Measured on `recipe_ratings` (BUT-2057): the suite went 7/7 with the merge-add case absent,
  and that case is the only one the `cannotModify` hardening would redden. Read the
  repository's real write verb before choosing the fixture's verb.
- **A conjunct on `resource.data.<f>` (PRE-state) is only proven by a payload that MOVES
  `<f>`.** A deny whose payload leaves the field alone passes identically under
  `request.resource.data.<f>` — the likeliest wrong edit, since both spellings read as "the
  message's type" — so the suite stays green with the guard testing the attacker's own
  input. Measured (BUT-1904): the three original tests survived that mutant whole; the case
  that killed it was the sender writing the field itself. Pin the field-moving payload
  beside the field-preserving one on every pre-state conjunct, immutability guards included.
