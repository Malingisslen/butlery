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
  null)` on both sides of a comparison.
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
  privileged ones by name (BUT-1832).
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
  `assertFails`.
- An `allow update` textually identical to `allow create` still needs its OWN allow
  test — a client `set()` on an existing doc is an update, and a toggle/edit path can
  live entirely there, unproven by create-side coverage alone.
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
- **Never state a suite TOTAL ("32/32") in a comment — it goes stale the day a test is
  added.** Name which tests move, by comment ID, instead.
- A rules comment asserting what a Cloud Function does with the document is a claim
  about another file's boolean — read that line, don't infer it from the comment
  (`enforceGroupMinorMembership`'s `isGroup` computation, BUT-1838).
- A decision record or comment quoting mutation-probe figures inherits their staleness
  at one remove — re-run every quoted mutant against the CURRENT file before trusting a
  written figure; arithmetic on an old run is not measurement.

### Probe & mutation-testing mechanics
- **Probe by ENV VAR, never by editing `firestore.rules` or copying the test file.**
  Ship `PROJECT_ID = process.env.PROBE_PROJECT_ID ?? "<real>"` and `RULES_PATH =
  process.env.PROBE_RULES_PATH ?? <real>` in the suite itself; mutate a COPY of the rules
  file in the scratchpad; run with those env vars set. The real file stays
  byte-identical by construction — no restore step to skip on a timeout — and a fresh
  project id keeps mutant writes out of the real namespace. Assert the mutator's match
  count is 1 and diff the mutant against the original before trusting the run.
- A standalone probe script must live UNDER `functions/src/` — from the OS temp dir,
  `npx ts-node` resolves neither `@firebase/rules-unit-testing` nor the tsconfig and dies
  on TS2307/implicit-any. Delete it in the SAME Bash call that created it (`trap ... EXIT
  INT TERM`); watch an earlier `cd functions` in that call — a later `rm
  functions/src/...` can silently miss.
- **`firestore.rules` is CRLF** — a literal template-string `.replace()`/`.includes()`
  never matches; use a whitespace-tolerant regex, assert the match count, and use the
  `/g` flag whenever the mutated literal appears more than once (a non-global replace
  silently patches only the first occurrence and reports a false "still denied").
- **Proving a "comment-only" rules diff is mechanical, not eyeballable**: recover every
  previously-staged revision with `git cat-file --batch-all-objects --batch-check`, strip
  `//` comments (only after grepping for `://` first) AND blank lines AND `\r`, then
  compare md5s — print the surviving line count alongside the md5 so "identical" is
  visibly non-vacuous. Cross-check with `git diff -U0 | grep '^[+-]' | grep -v
  '^[+-][[:space:]]*//'` coming back empty; the two methods fail differently (md5 catches
  reordering, the line filter catches a `//` inside a string literal). Size-filter object
  recovery on the file's real CRLF byte size, not an LF-era guess, or the sweep silently
  returns only ancient revisions and reads as "no prior version exists."
- **A mutation probe that reddens NOTHING is often the most valuable result — it means a
  COMMENT is wrong, not the code.** Run both the "the forbidden edit" probe (tests the
  comment's claim) and the "delete the conjunct" probe (tests whether the test is
  load-bearing at all) — a comment can be stale about an old rule shape while the current
  code is fine.

### Emulator, harness & CI gotchas
- The emulator PERSISTS DATA ACROSS `npm run` invocations — suffix create-allow doc ids
  with a per-run token, or a second local run silently becomes update-not-create and
  fails wrong. CI is unaffected (fresh emulator per job); "fails locally, green in CI"
  means clear-and-retry, not a regression.
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
  update regression through unnoticed.
- **Optional-list field validator** (`!('f' in d) || (d.f is list && d.f.size()<=N)`):
  five-test cluster — present+valid, present+empty, present+at-cap (boundary inclusive),
  present+over-cap (deny), present+wrong-type (deny); absent is already covered by the
  baseline allow test.
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
