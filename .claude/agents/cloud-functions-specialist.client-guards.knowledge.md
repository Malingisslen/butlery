# cloud-functions-specialist — chapter: client-guards

- **Client burst guards are `rateLimitStamped(type, s, key)`** (ADR-0020):
  same-request stamp on `request.time` + `lastDocId`. A COMPOSITE key joins ids
  with `/` (no id holds it): `'_'` lets `a_b`+`c` and `a`+`b_c` share one stamp.
  Sweep "(above)" back-references to prose a rules swap falsifies. `rate_limits`
  also holds non-stamps (`imports`, `friendSearchMigrated`) — shape claims cover all.
- `system_events` has no TTL — every enforced callable adds an unbounded
  write-per-denial stream, and `resource-exhausted` is client-RETRYABLE.

