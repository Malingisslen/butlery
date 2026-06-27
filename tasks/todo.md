# Sprint Backlog

## Sprint: recordUsage transient-retry (cost-tracking gap) — 2026-06-27

Single focused Tier-A backend reliability fix (late-session, kept tight for quality).

### Agent A: import rate limiter (direct) — Stakeholders: FinOps, Data/Integrations
- [x] **A1. Retry recordUsage transaction on transient Firestore errors + escalate failure log** `[Tier A]` (BUT-1415)
  - Step 0: CONFIRMED. `recordUsage` (import_rate_limiter.dart:104-126) wraps the counter update in
    `runTransaction`; on any throw it logs `warning` and returns. The Gemini call is already billed by
    then, so a transient transaction failure (unavailable/aborted/offline/contention) permanently
    drops the spend and the daily/monthly ceiling can be silently overrun.
  - Files: `lib/services/import/import_rate_limiter.dart` (+ retry_helper import); test add.
  - Acceptance: the transaction is retried (bounded) on transient Firestore codes
    (unavailable/aborted/deadline-exceeded/cancelled) · non-transient errors are NOT retried (still
    swallowed) · on ultimate failure it logs at ERROR (not warning) naming the untracked cost · a test
    proves a transient-then-OK sequence records usage exactly once (no double-count) after retrying ·
    retrying a read-modify-write is safe (a thrown txn didn't commit).

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos lib test` · run import_rate_limiter_test
- [ ] Phase 2.7 verifier · code-reviewer + testing-specialist · commit · push · Done

---

## Recent shipped (this session)
- BUT-1397 + BUT-1394 (commit fac80964e) — LLM retry storm + menu allergen-safety filter. Done.
- BUT-1390/1391/1393 (commit 08e04be29) — rate-limit cost leak + GDPR erasure, ingredients index, UGC profanity. Done.
- BUT-1386 (commit 07fa820d0, In Review) — server-authoritative age gate.
- Deferred for fresh context: BUT-1413 (PII scrubber list+slug leaks — cross-port Dart+TS change, needs careful shared-fixture parity).
