# firestore-rules-tester — accumulated knowledge

Core card: read on every review, after the shared review core. The chapters are listed under
`knowledge.tiers` in `.claude/shared-plugin.json`; read each chapter whose `paths` match a
file in the diff. The archive, `firestore-rules-tester.knowledge.archive.md`, is never read
at review. A new principle goes into the chapter it is about, and into this card only if it
applies to every review; `knowledge-caps-gate` refuses a core card over 15,000 chars and a
chapter over 20,000.

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
| `users/{uid}/notifications` (server-written, owner-read) | `delivered-notifications-rules.test.ts` | `test:rules:delivered-notifications` |
| `/blocks/{blockerId}_{blockedId}` (list, get, create, update-deny, delete) | `blocks-rules.test.ts` | `test:rules:blocks` |
| `/ingredient_suggestions` (owner list/get, client create, update+delete deny) | `ingredient-suggestions-rules.test.ts` | `test:rules:ingredient-suggestions` |
| `/user_moderation/{uid}` + its `report_history` subcollection, **and** the `friend_categories` / `public_profiles` admin moderation overrides | `moderation-rules.test.ts` | `test:rules:moderation` |
| `/shared_content` list/get, `notification_delivery`+`notification_engagement` create, **and the REMOVED `shared_content/{id}/items` block** | `iter102-rules.test.ts` | `test:rules:iter102` |
| `/household_allergen_shares/{householdId}_{userId}` (member+owner read, consent-bound create/update, path-derived delete) | `household-allergen-shares-rules.test.ts` | `test:rules:household-allergen-shares` |
| `users/{uid}/counters/{counterId}` (stranger +1 step, owner absolute) | `shared-content-counters-rules.test.ts` | `test:rules:shared-content-counters` |
| All of the above                      | (sequence)                 | `test:rules:all`          |

---

## Principles

### CEL nullable-map semantics (the recurring root cause)
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
  READS BEFORE CREATING, **and — the second live shape — when an Art. 15 EXPORT reads a
  SERVER-WRITTEN document that most users simply do not have.** Measured on `user_moderation`
  (BUT-2046): a field-deny conjunct added to the read limb
  (`!('reportHistory' in resource.data)`) denied the ABSENT document, i.e. every user never
  reported, and `_readDoc`'s throw lands in the export manager's `catch` as a FAILURE
  ENVELOPE — the exact BUT-1957 shape the block existed to remove, reintroduced by the
  conjunct that closed the previous finding. **A third live shape: a REPOSITORY that reads
  its own deterministic id as a "not already shared" pre-check before `set()`, or a `getOwn`
  that answers null for absent** — `household_allergen_shares` shipped a read limb of
  `isHouseholdMember(resource.data.householdId) || resource.data.userId == uid` with no null
  arm, so the grant flow could never reach its create (measured, BUT-1693). Grep the repo for
  `.doc(<id>).get()` before passing any read limb. When the id embeds the uid, scope the null
  arm to it (`resource == null && shareId.split('_')[1] == request.auth.uid`): measured, that
  kills the stranger existence oracle a bare `resource == null ||` opens. Each conjunct of
  that arm needs its own MISSING-id case: the `split('_').size() == 2` guard is reached only
  by an ABSENT 3-part id carrying the caller's uid second — a SEEDED 3-part id (the delete
  limb's fixture) has non-null `resource` and never enters the arm (measured, 49/49 green
  without it until R12). **Re-probe the absent case after ANY conjunct is
  added to a read limb; a hardening is where this arrives, never a first draft.** The
  `resource == null` arm creates NO existence oracle when the limb also carries `isOwner`
  (measured: absent + stranger stays DENIED). Triage the sweep by that question, not by counting limbs — ~25 read
  limbs in `firestore.rules` share the shape and nearly all are fine. Candidates are the
  composite/deterministic ids (`{groupId}_{ISO week}`, `direct_<a>_<b>`,
  `{blocker}_{blocked}`, `{uid}_{deviceId}`); a PATH-gated read (`planId.matches('^' + uid)`)
  never touches `resource` and is immune. The repair is `(resource == null || <membership>)`
  with the null arm FIRST, and it widens exactly to an EXISTENCE oracle in BOTH directions —
  allow ⇒ absent, deny ⇒ present-and-you-are-not-a-member. Note the failure hides: the
  caller's `try/catch` around the probe reads PERMISSION_DENIED as "not found" and logs it as
  such (`conversation_mutation_module`), so nothing reddens (BUT-1971, 2026-08-29).
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
  field is a separate conjunct with its own malformed-payload test. Measured on
  `ingredient_suggestions` (BUT-2038): the `hasOnly` mutant kills only the extra-field
  cases and leaves a forged `status: 'approved'` ALLOWED, while the value-pin mutant kills
  that one case alone — so an allowlist and a value pin are never each other's coverage.
- **The `hasOnly` read-coupling trap is READ-SIDE ONLY; on a CREATE limb it costs nothing
  and must not be argued against by citing `user_moderation`.** BUT-2046's cost — a
  legitimate new field makes the whole document unreadable to its own subject and fails the
  Art. 15 section closed — comes from rules being unable to scope a READ by field, over
  STORED documents written by anyone. A create-side allowlist judges only the payload in
  front of it, the Admin SDK bypasses it entirely (so server-written moderator fields
  belong OUTSIDE the list, not inside), and a client denial is loud and immediate. Check
  which limb carries the conjunct before transferring that entry's warning.
- **A conjunct ADDED to `hasRequiredFields`/`hasOnly` is a claim about EVERY WRITER of
  that collection, and the rules comment beside it is not evidence.** BUT-1812 added
  `'sharedToUserIds'` under "all three writers already stamp it"; only one of three did,
  so two share paths were silently denied (BUT-1482's disease, second occurrence). Grep
  the writers by collection constant, then prove the verdict with the writer's REAL key
  set plus a same-payload control carrying the new field.
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
  PRE-SEEDED lands on UPDATE and proves nothing about CREATE. The pre-seeder is as often
  the suite's OWN `seed()` as an earlier allow test** — and a per-test re-seed makes that
  deterministic rather than order-dependent, so the test is wrong on every run instead of
  intermittently. **The DIAGNOSTIC is a PAIR of limb-scoped mutants, and only the pair:** drop
  the conjunct from create only, then open update only, and read which tests each kills.
  Measured twice on `blocks` (BUT-1917). Broken: the "I may not create a block in somebody
  else's name" deny aimed at a stranger-pair id the seeder writes, so the create mutant left
  14/14 green while opening `allow update` killed that very test. Repaired — re-pointed at an
  id NO fixture writes, plus a `withSecurityRulesDisabled` assertion that the row is absent
  before `assertFails` — the create mutant is 13/14 killing it alone and it now SURVIVES the
  update mutant. The kill MOVING between the two mutants is the proof; either mutant alone
  reads the same in both states. Check every deny's doc id against the seeder's key set before
  believing a write-rule attribution, and make the fixture self-checking so a future seeder
  cannot re-break it silently. **The seeder is not the only thing that pre-seeds it: in a suite where
  `clearFirestore()` runs ONCE and `seed()` merely re-writes, an earlier ALLOW test's write
  persists, so which limb a later test lands on is a function of DECLARATION ORDER.**
  Measured on `poll_votes` (BUT-1917): B1 is a create only because it is declared first, and
  a create-limb-only mutant kills it and nothing else — insert any allow above it that writes
  the same row and the create limb silently loses its only kill. Attribute every shared
  conjunct with TWO limb-scoped mutants (drop it from create only, then from update only) and
  read which tests each kills; that is the only thing that says which limb a test is on. The same fact binds PROSE, not just fixtures: `set(..., merge: true)` is
  a CREATE whenever the document is absent, so a client the code reads as "update-only"
  still reaches the create rule under a read-then-delete race. Never pass a comment
  claiming "no shipped code sends shape X on create" without enumerating every merge-set
  of X, not just the literal creates (BUT-1831).
- **A rules change that TIGHTENS an existing gate makes every OLDER test on that path
  vacuous for a different reason, and the deny tests are the ones that hide it.** When a
  new conjunct sits ABOVE the one a test targeted, the test still denies — just not for
  its stated reason — and would stay green even if its real target were deleted. After
  any tightening, sweep every deny test on the touched path: which conjunct fires first
  now, and does the fixture still satisfy everything else? Watch for a flipped test's
  SECOND job (e.g. doubling as another test's fail-closed control) — that's the part that
  costs a round to catch.

### Probe & mutation-testing mechanics
- **Probe by ENV VAR, never by editing `firestore.rules` or copying the test file.**
  Ship `PROJECT_ID = process.env.PROBE_PROJECT_ID ?? "<real>"` and `RULES_PATH =
  process.env.PROBE_RULES_PATH ?? <real>` in the suite itself; mutate a COPY of the rules
  file in the scratchpad; run with those env vars set. The real file stays
  byte-identical by construction — no restore step to skip on a timeout — and a fresh
  project id keeps mutant writes out of the real namespace.
- **`firestore.rules` is CRLF** — a literal template-string `.replace()`/`.includes()`
  never matches; use a whitespace-tolerant regex, assert the match count, and use the
  `/g` flag whenever the mutated literal appears more than once (a non-global replace
  silently patches only the first occurrence and reports a false "still denied"). Write
  the mutator to a heredoc FILE and `diff` the mutant before running it — quoting a CEL
  string list inside `node -e '...'` lets bash eat the quotes, yielding undefined
  identifiers, i.e. a deny-everything mutant that reddens plenty and proves nothing.
