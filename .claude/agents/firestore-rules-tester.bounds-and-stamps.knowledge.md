# firestore-rules-tester — chapter: bounds-and-stamps

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
  **A bound spelled as TWO conjuncts (`> t - W && < t + W`) needs a PER-CONJUNCT mutant, and an
  edge ALLOW may only be graded by the NARROWING one.** Widening, or neutralising one limb,
  admits the far-out DENY cases — and any of them sharing the allow's doc id then CREATES the
  document, turning the allow into an UPDATE, so its red is contamination rather than
  attribution. Measured on `household_allergen_shares.consentGrantedAt` (BUT-1693, 10-minute
  window, each limb occurring exactly once in the file): neutralising the PAST limb killed C6,
  C25 **and** C24 (52/55) and the FUTURE limb killed C7, C26 and C24, while widening both to
  60m killed C25+C26 alone and narrowing both to 1m killed C24+C27 alone. Only the narrowing
  run grades the allows. The contamination fails SAFE — a red, never a vacuous green — exactly
  when the update limb's `cannotModify` names the field the allow MOVES; check that before
  accepting it, because without it the same collision returns a false green. A number-only
  mutant (both limbs at once) also cannot show that each direction carries its own deny: that
  needs the per-conjunct pair.
- **An allow fixture sitting WELL INSIDE a bound proves the field is ACCEPTED, never that it
  is BOUNDED — and without an at-bound allow twin an off-by-one is invisible.** Measured on
  `ingredient_suggestions` (BUT-2038): a case sending three optional fields at 9 chars / 2
  entries stayed green with all three bounds deleted, and after the over-cap denies were added
  it still stayed 28/28 with every bound tightened from `<=` to `<`; once the at-bound allows
  shipped, that same mutant killed exactly those three. The deny pins the
  DIRECTION; only the at-bound allow pins the NUMBER. Ship the pair whenever the number is
  worth anything.
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
- **`rateLimitStamped(type, s, key)` (ADR-0020) turns every guarded create into a BATCH**
  (guarded doc + `users/{uid}/rate_limits/{type}` stamp keyed on the doc id), so every
  ALLOW and every DENY on that path must carry the stamp or the deny is over-determined.
  A refused batch lands NO stamp, so DENY tests do not open a window: several denies and
  the ONE allow declared after them can share an actor, which keeps a "same caller, only X
  differs" control single-variable. Giving each case a fresh actor also works, but then
  strike every "only X differs" sentence. The per-collection missing/foreign/in-window
  stamp denies live in `rate-limit-rules.test.ts`, so feature suites owe only the stamped
  shape.
- A per-key immutability guard needs an ALLOW that changes a NEIGHBOURING key in the
  same map, not just denies on the pinned key — otherwise every deny in the cluster would
  also survive a future blanket freeze of the whole map, with nothing proving the rest
  stays mutable.
- **A stamp keyed on the LAST path segment binds one write per request only when that segment
  is unique across every document the batch can reach.** A guarded path with a second wildcard
  (`pings/{groupId}/pings/{pingId}`, `.../{userId}/received_lists/{listId}`) lets one stamp
  keyed `X` license `X` under N parents — measured on `pings`: 50 directed pings to 50
  recipients, one stamp, ALLOWED. For every `rateLimitStamped(..., key)` site, list the path's
  wildcards and ask which ones the key omits; that set is the per-request fan-out, and a
  "1 per N s" comment beside it is false. Pin the fan-out as its own case either way.
  **A composite key joined by a character the ids may contain is still a fan-out.**
  `groupId + '_' + pingId` lets `x0_x1_…_x29` split 29 ways across `(groupId, pingId)` pairs:
  one stamp, 29 pings, ALLOWED (measured). Join on `/`, which no path segment can hold, and
  pin a split-collision case, not only a two-groups-same-id case.
- **`size()` on a STRING counts UTF-16 CODE UNITS** — JS `.length`, not characters and not
  UTF-8 bytes. Measured on the emulator against the `recipe_ratings.review` bound
  (`<= 2000`), 2026-09-17: 2000 'ä' ALLOW (4000 UTF-8 bytes), 1000 emoji ALLOW (2000 units),
  2000 emoji DENY (4000 units), 2001 ASCII DENY as the control. So a Swedish å/ä/ö costs ONE
  and an astral character costs TWO, and a bound written as "N characters" is honest for
  Swedish prose and generous by half for emoji. Before this, two reviewers on one change
  asserted opposite answers (UTF-16 vs UTF-8 bytes) and neither had run it. `size()` is also
  polymorphic across string/list/map, which is the separate fact above — a length bound with
  no `is string` beside it is satisfied by a map of that many KEYS (BUT-2079, 2026-09-17).
- **A NUMBER fixture cannot discriminate a missing `is string`** — `5.size()` is a CEL
  evaluation error, so the write denies with or without the type arm, and a suite whose only
  type case is a number grades nothing. The killing case is a MAP, which satisfies `size()`
  polymorphically. And each LIMB carries its own copy of a conjunct: a map case on CREATE
  grades nothing on UPDATE (BUT-2079, 2026-09-17).

