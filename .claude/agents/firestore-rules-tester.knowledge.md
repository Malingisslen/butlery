# firestore-rules-tester — accumulated knowledge

Step-0 read for every invocation. **Principles only, edited in place** — a finding
extends the bullet it matches or earns a new one; it never appends a dated paragraph
here. The dated raw entry belongs in the append-only
`firestore-rules-tester.knowledge.archive.md`. Full contract below ("How new learning
enters this file").

## How new learning enters this file

- **Extends an existing bullet?** Edit it in place — merge aggressively; most findings
  are a new instance of a pattern already here.
- **A genuinely new durable rule** (a future run would act differently because of it):
  add one tight bullet under the right category, AND append the full dated narrative to
  the archive. It earns its place only if SHARP and FINDABLE — a principle that takes a
  paragraph to say will not be read.
- **A new collection→test-file mapping**: add the row to the table below in place — that
  table is living reference data, not a log, so it grows by row, never by dated entry.
- **A one-off verified-clean review with no new reusable rule**: archive only.
- If an edit would grow this file past budget, sharpen or retire a principle first,
  rather than letting it accumulate as a story-of-the-day log.

## Collection → test file map

| Path                                  | Test file                  | npm script                |
|---------------------------------------|----------------------------|---------------------------|
| `/users/{uid}` and recipes subtree    | `firestore-rules.test.ts`  | `test:rules:recipes-users`|
| `/reports/*`                          | `reports-rules.test.ts`    | `test:rules`               |
| Age-gate paths                        | `age-gate-rules.test.ts`   | `test:rules:age-gate`      |
| `/unified_shared_shopping_lists`      | `shared-shopping-lists-rules.test.ts` | `test:rules:shared-shopping-lists` |
| `/conversations/*` incl. `participants` roster, **and `/messages`** | `conversations-rules.test.ts` | `test:rules:conversations` |
| `/chat_groups/{groupId}`              | `chat-groups-rules.test.ts` | `test:rules:chat-groups`  |
| `messages/{id}/poll_votes/{voterUid}`, the messages RECEIPT `allow update`, **and `/shared_content` create** | `poll-votes-rules.test.ts` | `test:rules:poll-votes` |
| `/cook_snaps`, the messages ADMIN read/delete clauses, **and the BUT-1904 `duplicateBlocked` freeze on the sender `allow update`** | `cook-snaps-and-message-mod-rules.test.ts` | `test:rules:cook-snaps-and-message-mod` |
| `/weekly_menu_plans` and `/group_weekly_menu_plans` | `weekly-menu-plans-rules.test.ts` | `test:rules:weekly-menu-plans` |
| All of the above                      | (sequence)                 | `test:rules:all`          |

If the diff touches a collection not listed above, **create a new test file** named
`functions/src/__tests__/<collection>-rules.test.ts`, add a matching
`test:rules:<name>` script, append it to `test:rules:all`, and add the mapping here.

## Actor conventions

```ts
const OWNER_UID = "owner-uid";
const OTHER_UID = "stranger-uid";
const ADMIN_UID = "admin-uid";
```

- Authenticated:   `env.authenticatedContext(uid)`
- Unauthenticated: `env.unauthenticatedContext()`
- Admin grant:     write to `/admins/{uid}` via `env.withSecurityRulesDisabled(...)` during setup.

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

## Test naming convention

Each `test()` name states the behavior in plain English. Comment IDs above each test,
grouped by collection: `// R1:` for recipes, `// U1:` for users, `// A1:` for
admin/age-gate, etc.

```ts
// R1: owner can create their own recipe with a valid tagResult
test("recipes: owner can create a recipe with valid tagResult", async () => { ... });
```

Section banners between collections:

```ts
// ============================================================================
// RECIPES (8 assertions across 6 tests)
// ============================================================================
```

## Coverage requirement

For each rule branch in the diff, prove **both** the allow path **and** the deny path.
A green `assertSucceeds` without a matching `assertFails` is not coverage.

Standard deny matrix for ownership-checked collections:
- non-owner authenticated user
- unauthenticated user
- (when applicable) admin without the right claim

---

## Principles

### CEL nullable-map semantics (the recurring root cause)
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
- **The ELSE branch of an `is map` ternary is the security decision, not the guard
  itself.** `x is map ? x.get(k,d) : null` keeps a null-parent deny; `x is map ?
  x.get(k,d) : {}` re-defaults it to ALLOW. Neither closes the ABSENT case on its own.
  Probe both spellings before a comment calls either one "the repair."
- **`a.get(k1,d1).get(k2,d2)` is a deny-everything candidate whenever the outer key can
  be PRESENT-BUT-NULL**, not just absent — a present-null parent makes the inner `.get()`
  a CEL error, denying every write through that branch (BUT-1788 `conversations.metadata`
  — the app writes `null` on every send via `ConversationDto.toFirestore`, never absent).
  Verified spelling that survives it: `(x.get(k,{}) is map ? x.get(k,{}).get(k2,null) :
  null)` on both sides of a comparison. **A SINGLE `.get(k, d)` compared against a literal
  is the safe shape and needs no guard** — measured on `messages.type` (BUT-1904): absent,
  present-null, a number and a map all ANSWER the comparison rather than CEL-erroring, so
  only an exact match denies. The hazard is the second `.get()`, never the first; still pin
  all four states, because a wrong DEFAULT freezes every legacy row and nothing else catches
  it.
- **`resource` ITSELF is null on a read of a document that does not exist, so ANY read
  limb dereferencing `resource.data` DENIES the absent case** — a CEL evaluation error, not
  a false. Harmless for a collection reached by query (a listed doc always exists) or by an
  id only the owner can construct; a LIVE BUG exactly when the CLIENT DERIVES the doc id and
  READS BEFORE CREATING. Triage the sweep by that question, not by counting limbs — ~25 read
  limbs in `firestore.rules` share the shape and nearly all are fine. Candidates are the
  composite/deterministic ids (`{groupId}_{ISO week}`, `direct_<a>_<b>`,
  `{blocker}_{blocked}`, `{uid}_{deviceId}`); a PATH-gated read (`planId.matches('^' + uid)`)
  never touches `resource` and is immune. The repair is `(resource == null || <membership>)`
  with the null arm FIRST, and it widens exactly to an EXISTENCE oracle in BOTH directions —
  allow ⇒ absent, deny ⇒ present-and-you-are-not-a-member. Note the failure hides: the
  caller's `try/catch` around the probe reads PERMISSION_DENIED as "not found" and logs it as
  such (`conversation_mutation_module`), so nothing reddens (BUT-1971, 2026-08-29).
  **A comment bounding that oracle by calling the id "unguessable"/"random" is a claim about
  EVERY MINTING PATH, and a collection usually has more than one** — group conversation ids
  are a Firestore auto-id from `createChatGroupWithDeps` AND a
  `sha256(ownerId:categoryId)[:20]` digest from `ensureCategoryChat`, so "group ids are
  random" is false for the second while the SAFETY conclusion still holds (the digest eats a
  v4 UUID). Grep every caller that supplies a doc id before passing such a sentence, and
  strike the mechanism word rather than rewording it — the operative clause is which ids an
  attacker can CONSTRUCT from what they already hold.
  **Naming WHO an existence oracle discloses to is an exhaustive quantifier over every way a
  uid falls OUT of a denormalised membership snapshot, and a join-shaped answer covers half
  of them.** `group_weekly_menu_plans.memberPermissions` is seeded from
  `conversation.participantIds` at first build and never re-synced, so LATE JOINERS miss the
  older weeks — and DEPARTED members miss every week planned after they left, since
  `removeChatGroupMember` edits no plan and `deleteGroupMenuPlans` fires only when the group
  EMPTIES. Both still hold the id. Enumerate the snapshot's writers and its non-writers
  (removal paths, cascades) before passing any "it discloses to X" sentence; when the true
  set needs measuring, STRIKE the enumeration and keep the direction plus the decision line
  (BUT-1971, 2026-08-29 — fifth wrong wording of one sentence, each round fixing the last).
- **A `get(collection/{id})`-then-`.data.get()` chain needs an `exists()` guard or it
  fails OPEN on a missing doc**: `otherIsMinor(uid) = exists(users/{uid}) &&
  get(users/{uid}).data.get('isMinor', false)==true`. Same pattern for any "allowed only
  if a seeded relationship doc exists" gate — pair a no-doc deny with the identical
  actor+body succeeding once the doc is seeded.
- Chained `.get(field, default)` is safe-by-construction against an absent PARENT map;
  CEL `in` on a map checks KEYS only, never values.

### `hasOnly` / allow-list coverage
- **`hasOnly` bounds a document's SHAPE, not its VALUES** — passing the key-set check
  proves nothing about what is inside a permitted key; a validator on an enum or numeric
  field is a separate conjunct with its own malformed-payload test.
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
- **A conjunct ADDED to `hasRequiredFields`/`hasOnly` is a claim about EVERY WRITER of
  that collection, and the rules comment beside it is not evidence.** BUT-1812 added
  `'sharedToUserIds'` under "all three writers already stamp it"; only one of three did,
  so two share paths were silently denied (BUT-1482's disease, second occurrence). Grep
  the writers by collection constant, then prove the verdict with the writer's REAL key
  set plus a same-payload control carrying the new field.
- **Two new conjuncts can mask each other**: a missing-required-key test alone can pass
  even with the neighbouring `is list`/`is map` type-guard deleted, because the absent
  key already CEL-errors first. Pin the type guard separately with a WRONG-TYPE payload,
  not just a missing-field one.
- A collection with no root `keys().hasOnly()` validator silently accepts new top-level
  fields — pin a regression test that fails the day a `hasOnly([...])` is added without
  the new field, rather than trusting the absence of a validator to stay noticed.

### Proving a deny test is not vacuous
- **A `PERMISSION_DENIED`/CEL "evaluation error" string can never distinguish two deny
  tests — it fingerprints the RULE LINE, not the actor.** Two structurally different
  actors (a stranger vs. a revoked member) print byte-identical verdicts. Prove
  non-vacuity with (a) a **fail-closed control** — same doc/id/actor/payload with only
  the gate satisfied → must ALLOW — and (b) a **discriminating mutation** — rewrite the
  gate so the two actors' fates diverge, and confirm they do.
- **A `cannotModify([...])` key can be STRUCTURALLY unreachable when a neighbouring
  conjunct pins the same field to `request.auth.uid` on BOTH the pre- and post-state.**
  `weekly_menu_plans` names `userId` in `cannotModify` while also requiring
  `uid == resource.data.userId && uid == request.resource.data.userId`, so no payload can
  fail the immutability key alone — dropping `'userId'` from `cannotModify` reddens NOTHING
  (measured 2026-08-27). The deny test is real; only its ATTRIBUTION is wrong. Probe every
  key of a multi-key `cannotModify` list separately, and report an unreachable key as
  "guards the pair" rather than as covered.
- **A single-conjunct removal that reddens NOTHING can mean the conjunct is MASKED by a
  neighbour, not that the test is dead.** In `A && B`, if B CEL-errors whenever A is
  false, dropping A alone changes no verdict. Attribute a masked test with the SMALLEST
  mutation that DOES flip it, and report it as "guards the pair" — never as proven
  load-bearing alone. A deny against `allow x: if false` is unflippable by removal by
  construction; probe it by opening the rule instead.
- **When create and update share one conjunct, a deny test whose target document is
  PRE-SEEDED lands on UPDATE and proves nothing about CREATE.** A cross-actor deny needs
  a path no fixture has written yet (or twice, once per verb) — make the fixture
  self-checking: assert the row doesn't exist via `withSecurityRulesDisabled` before
  `assertFails`. The same fact binds PROSE, not just fixtures: `set(..., merge: true)` is
  a CREATE whenever the document is absent, so a client the code reads as "update-only"
  still reaches the create rule under a read-then-delete race. Never pass a comment
  claiming "no shipped code sends shape X on create" without enumerating every merge-set
  of X, not just the literal creates (BUT-1831). **A reachability claim about a rule
  spreads to EVERY file that touches the feature — rules comment, test comment, ADR,
  deviation entry, widget comment — so a finding filed against one is only part-fixed, and
  each review round tends to surface one more carrier: BUT-1831's rules-side sentence was
  struck while the identical claim rode into the same commit at test C7B, and BUT-1904's
  survived four rounds, the last carrier sitting in `firestore.rules` directly above the
  rule it misdescribed. Sweep by grepping the CLAIM's own keywords repo-wide, never by
  fixing the copy you happened to notice.** Grep the test file for the claim's keywords whenever a rules comment is
  corrected, and the reverse. **Sweep it by STRIKE-AND-POINT, never by writing the
  correction into both files** — the copy names the canonical site ("the account lives at
  the rule itself; do not restate it here") and makes no claim of its own, so there is one
  thing to re-measure instead of two that drift. **Sweep the keywords, not the comment
  syntax: a co-carrier hides in a TEST NAME, which no `//`-anchored grep reaches** — the
  group-menu integration suite still names `participantUserIds` as a field "so Firestore
  rules can enforce per-user access" after the rules-side sentence saying so was struck
  (BUT-1971, 2026-08-30). **And the test for a false GATING claim is not "does any limb
  READ field X" but "does any limb DECIDE ACCESS on X"** — `participantUserIds` and
  `participants` both appear in that block, in `hasRequiredFields` and in the update's
  `affectedKeys().hasAny([...])` guard, so a presence grep answers YES while the gating
  claim is still false; membership is tested only against `memberPermissions`, and
  `participants[].permission` is read nowhere. Verify the pointer RESOLVES FOR EVERY SYMBOL THE SENTENCE RANGES OVER: open the
  named limb/test and confirm it carries the account for each one. A rules-suite header
  saying "the constructor half is pinned in Dart by <test>" after describing BOTH
  `WeeklyMenuPlan.empty` and `GroupWeeklyMenuPlan.empty` held for the personal one only.
  Resolve a pointer per symbol, or you have replaced a false claim with a
  dangling one — and read the SYMBOL that account names, not only its conclusion: a class can
  carry the very case the account says it lacks, on a DIFFERENT switch (ADR-0009 credited
  `ChatActionHandler` with no `'menu'` case; `handleAttachment` has one, and the dead switch
  is `handleMessageAction`). **And scope the claim to the AFFORDANCE it was measured on: "no screen
  reaches this delete" was measured on the per-row long-press menu and is false for the RULE,
  because a BULK path — `deleteConversation` -> `deleteAllMessages` — reaches the same rows
  through the same client verb.** Enumerate every client caller of the verb before passing a
  reachability sentence; a bulk caller filters on the actor, never on the state the comment is
  about. Then check whether the UI RENDERS that caller at all: the tile is gated on
  `groupId == null`, so in a group chat neither path exists — a correction that stopped at
  "the bulk path reaches it" was itself false, and that was the fifth round on one sentence
  (BUT-1904, 2026-08-26).
- An `allow update` textually identical to `allow create` still needs its OWN allow
  test — a client `set()` on an existing doc is an update, and a toggle/edit path can
  live entirely there, unproven by create-side coverage alone.
- **A conjunct on `resource.data.<f>` (PRE-state) is only proven by a payload that MOVES
  `<f>`.** A deny whose payload leaves the field alone passes identically under
  `request.resource.data.<f>` — the likeliest wrong edit, since both spellings read as "the
  message's type" — so the suite stays green with the guard testing the attacker's own
  input. Measured (BUT-1904): the three original tests survived that mutant whole; the case
  that killed it was the sender writing the field itself. Pin the field-moving payload
  beside the field-preserving one on every pre-state conjunct, immutability guards included.
- **A rules change that TIGHTENS an existing gate makes every OLDER test on that path
  vacuous for a different reason, and the deny tests are the ones that hide it.** When a
  new conjunct sits ABOVE the one a test targeted, the test still denies — just not for
  its stated reason — and would stay green even if its real target were deleted. After
  any tightening, sweep every deny test on the touched path: which conjunct fires first
  now, and does the fixture still satisfy everything else? Watch for a flipped test's
  SECOND job (e.g. doubling as another test's fail-closed control) — that's the part that
  costs a round to catch.

### Rule parity, comments, and their claims
- **A comment saying a rule uses "the same test as" a sibling rule is a parity claim —
  measure it on EVERY verb, never read it.** A parent rule and its subcollection are two
  separate rules; a "same membership test" claim can hold for `read` and silently drop a
  cutoff the parent alone carries (BUT-1838's `memberSince`), leaking on `create` too.
  Enumerate every conjunct on the parent and check which the child actually inherited.
- **Never cite a rules LINE NUMBER in a comment or report — the file renumbers on every
  edit.** Cite the `match` pattern or function name instead.
- **A test comment is bound to its test by POSITION only, so the test a review ASKS you to
  insert is what detaches it** — the fix for a stacked-comment finding put a new `test(` in
  between a null-case paragraph and the null-case test, leaving the paragraph heading a
  cap-binding test and the null test bare (BUT-1971, 2026-08-30). After inserting a test,
  re-read the comment ABOVE and the test BELOW the insertion point as one unit; the repair is
  a MOVE (directly readable, no measuring), never a rewrite.
- **Never state a suite TOTAL ("32/32") in a comment — it goes stale the day a test is
  added.** Name which tests move, by comment ID, instead.
- A rules comment asserting what a Cloud Function does with the document is a claim
  about another file's boolean — read that line, don't infer it from the comment
  (`enforceGroupMinorMembership`'s `isGroup` computation, BUT-1838). Same for a
  **"kept in sync with `<symbol>`" comment: it makes TWO claims — the symbol exists at
  that path, and the VALUES actually agree.** Fixing only the NAME (a comment-drift
  sweep's natural instinct) can leave a false sync claim standing, so read the literal on
  both sides and grep for OTHER mirrors the comment doesn't name — `isAccountMatured()`'s
  60 min has three (`kAccountMaturityWindow`, `kAccountMaturityWindowMs`, the rule).
  **A comment naming a DRIFT GUARD instead ("the two are compared by `<test>`") makes a
  third claim: that the guard extracts THIS literal and not an adjacent one.** Verify by
  replicating the guard's own extraction (its regex, over the same comment-stripped text)
  and printing what it captured plus how many other copies of the number exist — reading the
  regex is not verification. Then check the guard RUNS in CI (`test.yml` runs `flutter test
  test/unit`), or the pointer names a guard nothing fires. Such a comment carries a
  cross-language PATH that a rename breaks silently, so the fix for that Low is a
  RECIPROCAL pointer — the Dart constant's docstring naming the guard, as
  `GroupWeeklyMenuPlan.maxContributorUserIds`/`maxEditTrailRows` now do — not a caveat
  (BUT-1971, 2026-08-31).
  **And a drift guard's stated failure mode ("raise the Dart constant and the server denies
  the write") assumes the constant has a PRODUCTION READER — grep it before passing that
  sentence.** `maxEditTrailRows` is pruned to by the service; `maxContributorUserIds` is read
  by nothing but the guard itself, so raising it changes no write and denies nothing. The
  guard still earns its place (it keeps the numbers together for the day a prune arrives);
  what goes false is the causal clause, which gets STRUCK, not reworded (BUT-1971, 2026-08-31).
- A decision record or comment quoting mutation-probe figures inherits their staleness
  at one remove — re-run every quoted mutant against the CURRENT file before trusting a
  written figure; arithmetic on an old run is not measurement.
- **A paragraph a diff merely REWRAPS ships as new text and gets judged as new.** Two
  inherited sentences rode a rewrap into BUT-1831: one claimed a squat closed by
  `directIdBinds` was "allowed today", the other described a Cloud Function's guard that
  had moved to another collection (`onDocumentCreated` on `conversations` ->
  `onDocumentWritten` on `chat_groups`) a ticket earlier. Re-verify every sentence a diff
  touches, including the ones it did not intend to change — and note that a stale "this
  hole is OPEN" claim is often refutable by passing tests in the SAME file, which is the
  cheapest disproof available. Struck, never reworded: a truer count needs measuring.

### Probe & mutation-testing mechanics
- **Probe by ENV VAR, never by editing `firestore.rules` or copying the test file.**
  Ship `PROJECT_ID = process.env.PROBE_PROJECT_ID ?? "<real>"` and `RULES_PATH =
  process.env.PROBE_RULES_PATH ?? <real>` in the suite itself; mutate a COPY of the rules
  file in the scratchpad; run with those env vars set. The real file stays
  byte-identical by construction — no restore step to skip on a timeout — and a fresh
  project id keeps mutant writes out of the real namespace. Assert the mutator's match
  count is 1 and diff the mutant against the original before trusting the run. **A probe
  project id must be lowercase** — an uppercase letter (a `createdAt`-derived id) makes the
  run emit NO test lines at all, which greps for `FAIL` as cleanly as a green suite; require
  a `passed` line before reading any probe result. A suite that ships WITHOUT the two env
  hooks has to be probed through a throwaway `sed`-derived copy under
  `functions/src/__tests__/`, deleted in the same call — workable, but add the hooks when
  you touch the file. **Substituting `RULES_PATH` in that copy orphans the `import * as path`
  line, and `noUnusedLocals` then aborts ts-node on TS6133 before any test runs** — an exit
  that greps for `FAIL` exactly like a green suite. Delete the import in the same `sed`, and
  require a `N/N passed` line before reading any probe result.
- **A probe script written through a heredoc or `node -e` inherits the SHELL's escaping, and
  the collapse is silent**: `"function\\s+"` came back as `function\s+` inside a JS *string*
  literal, i.e. the pattern `functions+`, which matched nothing and read as "the rule is gone"
  — the same decay the Dart guard's own comment warns about, arriving through bash instead.
  Build patterns from REGEX LITERALS (`/…/.source` with a placeholder to substitute), never
  from backslashes inside a quoted string, and print the CAPTURE plus how many other copies of
  the number the file holds before believing a match (BUT-1971, 2026-08-31).
- **A parallel session can edit the suite MID-REVIEW** — this file went 30 -> 32 tests between
  the first run and the report, so a quoted total and a "no test covers X" claim both age
  inside one review. Re-`Read` the test file and re-`ls -l` it before quoting any count, and
  never carry a probe's pass total from an earlier run into the write-up.
- A standalone probe script must live UNDER `functions/src/` — from the OS temp dir,
  `npx ts-node` resolves neither `@firebase/rules-unit-testing` nor the tsconfig and dies
  on TS2307/implicit-any. Delete it in the SAME Bash call that created it (`trap ... EXIT
  INT TERM`); watch an earlier `cd functions` in that call — a later `rm
  functions/src/...` can silently miss.
- **`firestore.rules` is CRLF** — a literal template-string `.replace()`/`.includes()`
  never matches; use a whitespace-tolerant regex, assert the match count, and use the
  `/g` flag whenever the mutated literal appears more than once (a non-global replace
  silently patches only the first occurrence and reports a false "still denied"). Write
  the mutator to a heredoc FILE and `diff` the mutant before running it — quoting a CEL
  string list inside `node -e '...'` lets bash eat the quotes, yielding undefined
  identifiers, i.e. a deny-everything mutant that reddens plenty and proves nothing.
  **`resource\.data\.` also matches the TAIL of `request.resource.data.`**, so a pre-state
  mutation silently counts the create limb too — anchor on `&& resource.data`. When one
  collection's shape is shared repo-wide (`memberPermissions[uid] in ['edit','admin']`
  appears three times), slice the block by `indexOf('match /<collection>')` and mutate
  inside the slice rather than widening the pattern.
  **The same slice is mandatory in a SHIPPED cross-language guard, where the consequence is
  worse than in a probe: an unanchored needle stays green FOREVER instead of measuring the
  wrong bytes once.** A rules test pinning a Cloud Function's cap by
  `rulesText.includes(".get('contributorUserIds', []).size() <= 200")` matched THREE times —
  once in `group_weekly_menu_plans`, twice in `unified_shared_shopping_lists` — so the group
  cap could move to 150 (with its Dart twin, keeping the Dart guard green) while the needle
  went on matching the shopping-list copy, which is exactly the drift the guard exists to
  catch. Count the needle's occurrences over the WHOLE file before shipping any substring
  pin, assert the count inside the slice is 1, and note that a needle unique TODAY (the
  `editTrail` twin) is anchored by luck, not construction. A raw `includes()` is also
  COMMENT-BLIND, unlike the Dart guard beside it which strips `//` first — measured:
  commenting the cap out leaves the pin green (BUT-1971, 2026-08-31).
  **Certify such a pin with FOUR text-only mutants, no emulator needed — the guard is pure
  string work, so replicate its own slicer over a mutated buffer in `node`**: (1) change the
  cap INSIDE the block → must fire; (2) same for the sibling cap, separately, or one anchor
  covers for the other; (3) comment the cap out → must fire; (4) change the copies OUTSIDE
  the block → must NOT fire. Print the WHOLE-FILE needle count beside the in-slice count:
  the whole-file number is what tells you whether the slice was load-bearing at all
  (measured: contributor needle 3 whole-file / 1 in-slice, trail needle 1 / 1 — so the trail
  pin is anchored by luck and only the slice makes that safe to stop worrying about).
  **A cross-language guard anchored on a rules FUNCTION NAME is safe by construction and
  needs no slice** — `groupMenuContributorsWithinCap` cannot match the shopping list's inline
  copy, whereas the literal can. Prefer the name anchor when the rule offers one.
- **Proving a "comment-only" rules diff is mechanical, not eyeballable**: recover every
  previously-staged revision with `git cat-file --batch-all-objects --batch-check`, strip
  `//` comments (only after grepping for `://` first) AND blank lines AND `\r`, then
  compare md5s — print the surviving line count alongside the md5 so "identical" is
  visibly non-vacuous. Cross-check with `git diff -U0 | grep '^[+-]' | grep -v
  '^[+-][[:space:]]*//'` coming back empty; the two methods fail differently (md5 catches
  reordering, the line filter catches a `//` inside a string literal). **The md5 is valid
  only WITHIN one run: it fingerprints the strip pipeline as much as the bytes** — two
  correct pipelines over the same 1382 surviving lines printed different digests in two
  reviews of one diff (CR stripped before vs. after the comment strip). Compare digests only
  against one you computed in the same call; the SURVIVING LINE COUNT is the figure that
  travels between entries. Size-filter object
  recovery on the file's real CRLF byte size, not an LF-era guess, or the sweep silently
  returns only ancient revisions and reads as "no prior version exists."
  **Re-run the affected suite anyway.** A comment cannot change CEL evaluation, so the run
  is not owed for behaviour — but it is the only check on the one thing a comment edit CAN
  break: a ruleset that no longer compiles.
- **A mutation probe that reddens NOTHING is often the most valuable result — it means a
  COMMENT is wrong, not the code.** Run both the "the forbidden edit" probe (tests the
  comment's claim) and the "delete the conjunct" probe (tests whether the test is
  load-bearing at all) — a comment can be stale about an old rule shape while the current
  code is fine.

### Emulator, harness & CI gotchas
- The emulator PERSISTS DATA ACROSS `npm run` invocations — suffix create-allow doc ids
  with a per-run token, or a second local run silently becomes update-not-create and
  fails wrong. CI is unaffected (fresh emulator per job); "fails locally, green in CI"
  means clear-and-retry, not a regression. **A DETERMINISTIC id is the same hazard WITHIN
  one run**: `direct_<a>_<b>` is a pure function of its two uids, so any two fixtures
  naming that pair ARE one document and the later seeder silently overwrites the earlier —
  turning an ALLOW control into a deny while its DENY twin stays green and pins nothing.
  Give a new fixture DEDICATED uids and grep every path in the file before calling it
  isolated (BUT-1831).
- Never import server-value sentinels (`serverTimestamp`, `increment`, `arrayUnion`,
  `deleteField`) from `firebase-admin/firestore` in a `*-rules.test.ts` — the test
  context is the CLIENT SDK; an admin sentinel throws before any rule runs, which also
  fails `assertFails` deny tests. Grep `from "firebase-admin/firestore"` across
  `__tests__/*-rules.test.ts` after any `firebase-admin` major bump.
- `count()` aggregate rule tests need the MODULAR `firebase/firestore` API
  (`getCountFromServer`, `collection`, `query`, `where`) — the compat API has no
  `.count()`.
- `{"error":{"code":500,"status":"UNKNOWN"}}` from `loadFirestoreRules` is emulator
  flake, not a rules syntax error — disprove it by PUTting the same ruleset to
  `/emulator/v1/projects/<pid>:securityRules` directly; a 200 with only WARNING
  severities means it compiles. Space probe runs one or two per shell call; a retry loop
  inside one call does not clear it.
- `curl -X DELETE .../databases/(default)/documents` from Bash silently no-ops (parens
  glob-expand, exit 7) — use each test file's own `clearFirestore()` helper.
- `test:rules:all` is not one atomic run — a Storage-emulator-dependent suite mid-chain
  hard-fails `ECONNREFUSED` without the Storage emulator up, aborting the `&&` chain so
  every later suite silently never executes. Check WHERE the chain stopped before
  reporting a pass count.
- Registering a new rules suite is FOUR mechanical steps, enforced by
  `functions/scripts/check-test-registration.js`: the `test:rules:<name>` script, an
  entry in `test:rules:all`, and the path in BOTH `paths:` blocks of
  `.github/workflows/firestore-rules.yml` (pull_request + push). Verify with `node
  scripts/check-test-registration.js`.

### Coverage shape patterns (reusable per rule shape)
- **Numeric-floor change on a rule**: allow-at-floor, deny-at-floor+1, AND an
  update-branch allow at the same boundary — a create-only deny test lets a blanket-deny
  update regression through unnoticed. **The deny-at-floor+1 must be sent by the
  PRODUCTION actor class, not only the most privileged one**: an ALLOW test for a lesser
  actor proves the cap does not block them, never that it BINDS them. Measured on
  `group_weekly_menu_plans.editTrail` (BUT-1971): scoping the cap to admins
  (`perm == 'admin' ? size<=50 : true`) left 21/21 green — both over-cap denies were sent
  by the admin, and the freshly added "a non-admin editor may write a trail within the
  cap" allow survives that mutant by construction. Pin the boundary once per ACTOR CLASS
  that writes the field, and never let an allow test's comment claim a conjunct sits
  outside a gate — only the deny at that actor measures placement. Re-measured 2026-08-30
  once the editor's over-cap DENY was added: the same mutant now dies 20/22, and the new
  deny is one of the two kills — so the allow/deny PAIR at one actor is what proves
  placement, not the allow alone. **The allow's own comment is then what goes false**: a
  "nothing proved that" clause justifying why the allow was added is a claim about the
  SUITE, and the deny a reviewer asks for the next round refutes it inside the same file.
  Strike the justification clause; leave only what the test itself does.
- **Optional-list field validator** (`!('f' in d) || (d.f is list && d.f.size()<=N)`):
  five-test cluster — present+valid, present+empty, present+at-cap (boundary inclusive),
  present+over-cap (deny), present+wrong-type (deny); absent is already covered by the
  baseline allow test.
- **A bare `d.get('f', []).size() <= N` cap with NO `is list` guard has THREE verdicts, not
  two, so "wrong-type" is never one test.** `.size()` is polymorphic: a LIST, a MAP and a
  STRING all answer it, so each is ALLOWED at ≤N and DENIED above it; an INT, BOOL,
  TIMESTAMP or explicit NULL CEL-errors and is DENIED outright (measured on the emulator,
  `group_weekly_menu_plans.editTrail`, BUT-1971). Consequence for review: an `is list`
  conjunct buys SHAPE, not a bound — every type that gets through is still capped at N, and
  a 50-key map with huge values is the same byte risk as a 50-row list with huge rows, which
  `is list` does not stop either. So "document the type gap instead of guarding it" is a
  defensible call; say so with the per-type table, not from intuition. The half that IS
  live: the explicit-NULL deny means the day any writer serialises the field
  unconditionally (`'f': null` rather than omitting it when empty) EVERY write on the
  collection is refused — grep `toFirestore`/`toMap` for the field's conditional before
  passing the cap, and never rely on `.get()`'s default to cover null (it covers ABSENT only).
  **Documenting the gap instead of guarding it SPREADS the measurement**: the per-type fact
  ended up in six files (rule, rules test, cascade, its integration test, the export helper,
  its unit test), each stating it to justify its own fail-closed arm. That is legitimate —
  a bare pointer would leave a reader unable to judge whether the arm is needed — but it
  means adding `is list` LATER falsifies six sentences in one edit, so grep `polymorphic`
  before touching such a cap. And `is list` does not retire the downstream arms by itself:
  a rules tightening never cleans STORED documents, and those arms read stored data.
  **A test that PINS such a gap (a 50-key map ALLOWED) has exactly one kill: the hardening.**
  That is its value — it converts "adding `is list` falsifies six sentences silently" into a
  RED test that names them — but say so in its comment, or the next reader reads the red as a
  regression and deletes it. Scope the comment to what the case holds: the downstream carriers
  all cite the MAP, so a map case discharges them; naming "list, map and string" beside a
  map-only case leaves a third of the sentence uncommitted (BUT-1971, 2026-08-31).
  **And never let that comment COUNT the carriers it discharges** ("three comments cite this
  and no case held it"): the number is not derivable from the case, it is falsified by the next
  carrier anyone adds, and it actively competes with the `grep polymorphic` that is the real
  instruction — a maintainer adding `is list` later stops at the stated number and leaves a
  stale carrier. Strike the numeral; keep only what the case does (BUT-1971, 2026-09-02).
- **Deny-all server-only collection** (`allow read, write: if false`): matrix
  {read,create,update,delete} × {unauth, non-admin, admin} — admin-still-denied is the
  load-bearing case — plus one Admin-SDK-bypass write that succeeds.
- **Owner-scoped subcollection under a `{path=**}/<name>/{id}` collection-group
  catch-all**: a single-doc deny test is not proof — the engine can't show every matched
  doc satisfies an owner predicate for an unconstrained collection-group query, so the
  load-bearing test is a non-owner `collectionGroup(name).get()` denial.
- **Append-only array guard** (`req.get(f,[]).hasAll(resource.get(f,[])) &&
  req.get(f,[]).size()<=N`, ANDed OUTSIDE any owner/member OR so the owner is bound too):
  `hasAll` is SET semantics — a client reordering the array while preserving membership
  must still ALLOW (the case that distinguishes it from an equality check); `arrayUnion`
  allows and `arrayRemove` denies with no special-case code; a doc already over N is
  FROZEN for every future update, a documented consequence, not a bug to silently patch.
  **Drop-and-clear denies are NOT the coverage — two cheaper mutants survive them both,
  measured on `group_weekly_menu_plans.contributorUserIds` (BUT-1971, 32/32 green each).**
  (1) Defaulting the REQUEST side to the prior array
  (`req.get(f, resource.get(f,[]))`) — the "make legacy clients work" fix — is caught only
  by a whole-document non-merge `set()` that OMITS the field, which is the production verb
  wherever `save()` writes the whole doc and the shape a stale app build sends. (2)
  Rewriting `hasAll` as `req...size() >= resource...size()` is caught only by a SAME-SIZE
  SUBSTITUTION (`['a','b']` -> `['a','z']`), the smarter evasion. Pin both beside the
  drop/clear pair, plus the reorder ALLOW and a preserving-`set()` fail-closed control.
  Re-measured 2026-08-31 once all four shipped: each mutant now dies 36/37, killing exactly
  its own test and nothing else. **`arrayUnion`/`arrayRemove` sentinels owe NO test in a
  rules suite** — rules see the RESOLVED post-state, so a client sentinel is an alias of the
  superset-allow / drop-deny already pinned, and a SERVER sentinel (the leave-path CF's
  `arrayUnion`) runs under the Admin SDK, which never evaluates rules at all; its coverage
  belongs in the callable's own suite.
- **An Admin-SDK write can put a document PAST a cap the rules enforce, and whether the
  resulting client freeze is permanent is a question about a CLIENT-SIDE PRUNE, not about
  the rule.** Every writer that APPENDS to the trail prunes it — the client in
  `_withTrailRow` and the leave-path CF in the same branch that appends its `adminPromoted`
  row — and the account cascade only filters rows out, so no over-cap trail is ever stored. `contributorUserIds` has no prune by design, so its freeze IS permanent. Trace
  the prune before writing "frozen forever" or "self-healing"; they are opposite verdicts on
  two caps in one collection (BUT-1971, 2026-08-31).
- A `rateLimitWrite(...)` conjunct is invisible to the whole suite unless a test SEEDS
  `users/{uid}/rate_limits/{collection}` — no Butlery client writes those docs itself, so
  its removal reddens nothing without an explicit seeded-doc deny test. Report an
  un-seeded rate-limit conjunct as an uncovered branch, not as proven.
- A per-key immutability guard needs an ALLOW that changes a NEIGHBOURING key in the
  same map, not just denies on the pinned key — otherwise every deny in the cluster would
  also survive a future blanket freeze of the whole map, with nothing proving the rest
  stays mutable.
- A collection-group read rule UNIONS with the specific match it overlays, all-or-nothing
  per doc — an admin-only collection-group grant also grants a direct `get()` on any
  single scoped doc; there is no way to express "query but not direct-get" in this shape.

### Domain-specific rule facts (re-check against, don't re-derive)
- **Age gate**: `isAgeCompliant()` fails CLOSED (no claim → CEL undefined → deny).
  `birthYear`/`isMinor` are CF-only-written on BOTH `users/{uid}` and
  `users/{uid}/settings/{settingId}` — create requires absent, update requires unchanged;
  test both docs. Adding the gate to an EXISTING create rule fails closed every prior
  create-allow test lacking the claim — grep `authenticatedContext(<actor>)` for that
  collection whenever a gate is added.
- **1:1 DM minor gate** (`passesMinorDmGate`): size!=2, or other party not minor, or
  creator is their friend. Group conversations (size>2) are DELIBERATELY ungated in
  rules — minor protection there is the separate `enforceGroupMinorMembership` Cloud
  Function; don't file "group DM has no minor gate" as a rules finding.
- **`conversations/{id}/participants` roster**: a GROUP's parent conversation doc is
  written under `users/{creator}/conversations/{id}` and the top-level doc doesn't exist
  until the first message — a rule attesting only via `get(parent)` denies every group
  roster write permanently. Shipped shape: `attestedWriter()` (parent names writer AND
  subject) OR `rosterUnclaimed()` (parent doc absent — bootstrap), read via
  `exists(.../{own uid})`, delete NARROWER than create (self-only). Test with the
  writer's REAL `WriteBatch` (roster + membership in one commit) — a failed batch prints
  a `false` verdict for EVERY doc in it, including ones allowed on their own, so attribute
  the deny with a separate probe.
- **Household membership** (`households`/`diner_profiles`/`family_ratings`) is a
  DOC-READ gate (`get(households/{hid})` + uid in `memberUserIds`), not a path segment —
  every test must seed the household first. Household-admin is separate from app-level
  `isAdmin()`.

---

## When to consult the archive

- You need the exact CEL predicate, emulator command, or full multi-round narrative
  behind a principle above — every principle here has its raw history in the archive,
  searchable by collection name or ticket.
- A finding-in-progress feels familiar (a masked conjunct, a vacuous deny pair, a
  four-state map) — search the archive by symptom before filing it as new; several of
  these principles were learned more than once before being merged here.
- You're about to write "the same test as" or a suite total into a comment — grep the
  archive for the last time that phrasing was disproved before writing it.
- You're about to append a new dated entry — check first whether it should instead
  extend a bullet above.
