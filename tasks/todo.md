# Sprint Backlog

## Sprint: harden verifySignupAge idempotent retry — 2026-06-28

Single clean Tier-A backend correctness hardening (functions-only, my own BUT-1386 follow-up).

### Agent A: verifySignupAge idempotency (cloud-functions-specialist) — Stakeholders: Security, Data/Integrations
- [x] **A1. Idempotent retry re-ensures birthYear + consent audit (not a bare no-op)** `[Tier A]` (BUT-1435)
  - Step 0: CONFIRMED. verify-signup-age.ts writes claim → birthYear (Promise.all) → audit. If the
    claim write succeeds but the birthYear writes then fail, the retry hits the `ageCompliant===true`
    idempotent branch and returns no-op — leaving a compliant user with the gate claim set but no
    stored birthYear / audit row. Fix: re-assert the artifacts idempotently in the retry branch.
  - Files: `functions/src/account/verify-signup-age.ts`, `functions/src/__tests__/verify-signup-age.test.ts`.
  - Acceptance: extract writeComplianceArtifacts (dual birthYear merge-sets + consent audit) called by
    BOTH the first-pass and the retry branch · the consent audit uses a DETERMINISTIC doc id (set+merge)
    so re-running never duplicates the row (one consent row per user — correct semantics; purge still
    matches by operation prefix) · the retry branch does NOT re-set the claim · existing test Case 2
    (was "no writes on retry") updated to assert artifacts ARE re-ensured (claim not re-set, birthYear
    in both paths, exactly one consent row) · tsc + CF unit tests green.

### Post-Sprint Steps
- [ ] `cd functions && npm run build` (tsc) + run verify-signup-age test · Phase 2.7 verifier · cloud-functions-specialist + firebase-backend-security · commit · push · Done

---

## Recent shipped (this session): BUT-1405 (2a041d5b8), BUT-1407 (ac9ffb80d), BUT-1425 (2293bf051), BUT-1401 (077212635), BUT-1428 (412efb5ed), BUT-1406+1436 (0b42c9280), BUT-1414 (39bffed2c), BUT-1415 (3c83cbb10), BUT-1397+1394 (fac80964e), BUT-1390/1391/1393 (08e04be29), BUT-1386 (07fa820d0, In Review).
