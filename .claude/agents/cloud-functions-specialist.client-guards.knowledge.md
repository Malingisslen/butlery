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
  write helper is the tell that the other fields were never sent.
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
- `system_events` has no TTL — every enforced callable adds an unbounded
  write-per-denial stream, and `resource-exhausted` is client-RETRYABLE.

