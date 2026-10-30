# cloud-functions-specialist — chapter: client-guards

- **Client burst guards are `rateLimitStamped(type, s, key)`** (ADR-0020):
  same-request stamp on `request.time` + `lastDocId`. A COMPOSITE key joins ids
  with `/` (no id holds it): `'_'` lets `a_b`+`c` and `a`+`b_c` share one stamp.
  Sweep "(above)" back-references to prose a rules swap falsifies. `rate_limits`
  also holds non-stamps (`imports`, `friendSearchMigrated`) — shape claims cover all.
- **A one-way flag rule needs a DENY per shape the flag's READER takes as unset**,
  not only the explicit opposite value. `closePoll` treats anything but `isClosed == true`
  as open, so a missing key, `null`, and a stripped `poll`/`metadata` each reopen it;
  a `!= false` or `get(k, true)` spelling passes a test that only sends `false`. Same for
  composite doc-id pins (`{recipeId}_{uid}`): one DENY per half, or dropping a half survives.
  Same for a counterparty picked by position (`otherParticipant(participantIds)`): one DENY
  with the refused caller at EACH index, per call site — a hard-coded `participantIds[1]`
  survives every deny whose caller sits at `[0]`.
- **A create-DENY test on a FIXED doc id is vacuous once any earlier test wrote that
  id** — the `set` evaluates as an UPDATE, and a `update: if false` path denies it
  whatever the create conjuncts say. `env.clearFirestore()` in `setup()` only clears
  CROSS-RUN leftovers; within a run, order still decides. Clear per test, or give
  each create case its own doc id.
- **A conjunct REPEATED per field needs one DENY per field, and a deny payload
  that moves two guarded fields at once pins only the first one evaluated.**
  `counterStepOk('unreadSharedRecipes') && … ('unreadSharedMenus') && …` on
  `users/{uid}/counters`: every deny that steps recipes AND total together stays
  green when the menus, shopping-list or total conjunct is deleted. One deny per
  field, each moving exactly that field. A `field = "…"` default parameter on the
  write helper is the tell that the other fields were never sent. The same holds for a
  stored FIXTURE: a seeded row that breaks two conjuncts of one predicate pins neither
  (`isPendingImage` on `messages`: a row with `imageUrl` set AND no `pendingImage` flag).
  Seed one row per conjunct, each breaking only that one.
- **A BATCH deny is green when ANY write in it is refused**, so it pins nothing about the
  write its name is about. `shared_content` update admits any `isSharedMember`, so a
  recipient's solo `arrayRemove` of ANOTHER recipient SUCCEEDS; a recipient's trim batch
  fails only on the `members/{other}` delete. A deny naming one document's protection is
  the SOLO write to that document; keep the batch only for the ALLOW and end-state check.
- **An `is string` deny needs a payload only that conjunct refuses.** Beside
  `x.size() <= N`, a NUMBER is refused by `size()`'s evaluation error too, so deleting
  `is string` stays green; a one-element LIST passes `size()` and isolates it.
- **A floor (`>= 0`) deny is attributable only against an ALLOW of the direction
  it bounds.** A stranger's `increment(-1)` from 0 also denies if the `- 1` branch
  itself is missing, so either pair the floor deny with a stranger `-1` from 2 that
  must SUCCEED, or — if the direction is REMOVED instead (the counters call: only
  the owner decrements) — reach the floor from a STORED value that already
  violates it: seed `-3`, send the ordinary `+1`, and only the floor refuses the
  `-2` post-state. Rows predating the bound, the owner's absolute-write arm and
  the Admin SDK are all writers of such a value, so the fixture is not contrived.
  An owner decrement is never that control: it passes through the owner's
  absolute-write arm, never the step arm.
- **Mutation-probe a rules suite WITHOUT writing the repo**, so gate coverage survives:
  copy `firestore.rules` and the suite into the scratchpad, mutate the rules copy (assert
  `count(old) == 1`), point the copy's `RULES_PATH` at it and give it a fresh `PROJECT_ID`,
  then run `NODE_PATH=$PWD/node_modules npx ts-node --transpile-only -O
  '{"module":"commonjs","moduleResolution":"node"}' <copy>` from `functions/` (without
  `-O`, TS5109 aborts it). Confirm `git status` is unchanged afterwards.
- `system_events` has no TTL — every enforced callable adds an unbounded
  write-per-denial stream, and `resource-exhausted` is client-RETRYABLE.
- **A wrapper that reads a field off the handler's RESULT must REQUIRE it in its
  generic bound** (`withCostLedger`: `TResponse extends { estimatedCost: number }`) —
  an optional `?:` lets a newly wrapped callable compile and record 0 in silence.
  The cost ledger sits OUTSIDE `withRateLimit` (a cost denial must not spend the
  per-user bucket or the global counter), so it checks `request.auth` itself before
  its read; pin both on source, once per file (the two AI callables read
  `withCostLedger(withGuestImportQuota(withRateLimit("<op>",`).
- **A quota wrapper nested INSIDE `withRateLimit` runs after the per-user token and the
  global `system/llmLimits` slot are spent**, so each of its own refusals (which call no
  model) still costs both, and a `resource-exhausted` refusal is client-retryable, so
  retries drain the counter every user shares. `withGuestImportQuota` therefore sits
  OUTSIDE `withRateLimit`, which makes a rate-limit refusal a throw the quota refunds.

- **A flag whose OMISSION widens a grant is a REQUIRED parameter** (`mode: { guest }` in
  `runVerifySignupAgeWithDeps`); tsc pins callers, and a source pin covers the unreachable body.
- **A consent-row VARIANT keeps `operation` inside `CONSENT_OPERATIONS`** and differs by a field
  and its own id (`consent_guest_upgrade_{hash}`): an unlisted operation falls to the 180-day bucket.
- **A token-based guest exemption is confirmed against the Auth record** (`providerData.length
  === 0`): a pre-upgrade anonymous ID token stays valid until expiry and nothing checks revocation.
- **Pin gate-before-limiter on the REAL callable** (`.run(request)`, `enforceRateLimit` swapped for
  a sentinel-thrower) with an eligible-caller control that MUST reach the sentinel.
- **A list callable that feeds an action button returns the action's admission predicate,
  computed by the function the action callable uses** (`appealAdmits`): widening the list
  otherwise offers an action that is always refused.
- **A retention anchor read from a client-written field must be clamped to the server
  clock** (`min(field, now)`): `reports.createdAt` is required by the create rule but not
  pinned to `request.time`, so a forged future value would stretch a TTL indefinitely.
