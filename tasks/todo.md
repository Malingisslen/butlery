# Sprint Backlog

## Sprint: circuit-breaker half-open single-probe guard — 2026-06-28

Single focused Tier-A backend concurrency fix.

### Agent A: circuit breaker (direct) — Stakeholders: Data/Integrations, Performance
- [x] **A1. Half-open in-flight guard so only ONE probe tests recovery** `[Tier A]` (BUT-1414)
  - Step 0: CONFIRMED. `circuit_breaker.dart` `allowRequest` is a side-effecting GETTER that sets
    `_isHalfOpen=true` + returns true with no in-flight counter, so N queued callers all pass at the
    reset boundary and hit the recovering backend at once. `llm_service.dart:328` gates on it and
    always records success/failure after (so an in-flight flag will clear). Existing breaker tests
    each call allowRequest once per half-open then record — no test relies on multi-probe.
  - Files: `lib/core/circuit_breaker.dart`, `lib/services/llm/llm_service.dart` (call site),
    `test/unit/core/circuit_breaker_test.dart` (getter→method + new concurrent test).
  - Acceptance: `allowRequest` is a METHOD (not a side-effecting getter) · in half-open, the first
    caller gets the single probe slot and a second concurrent caller gets `false` until the probe
    resolves · the in-flight flag is cleared by recordSuccess / recordFailure / reset · a unit test
    proves two concurrent half-open calls → only one probes · all existing breaker + llm-service
    breaker tests still pass.

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos lib test` · run circuit_breaker_test + llm_service_circuit_breaker_test
- [ ] Phase 2.7 verifier · code-reviewer + testing-specialist · commit · push · Done

---

## Recent shipped (this session): BUT-1415 (3c83cbb10), BUT-1397+1394 (fac80964e), BUT-1390/1391/1393 (08e04be29), BUT-1386 (07fa820d0, In Review). Deferred for fresh context: BUT-1413 (PII scrubber cross-port), BUT-1416 (Algolia degraded-mode is Tier-B/partly-stale).
