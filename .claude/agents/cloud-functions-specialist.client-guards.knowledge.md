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
- `system_events` has no TTL — every enforced callable adds an unbounded
  write-per-denial stream, and `resource-exhausted` is client-RETRYABLE.

