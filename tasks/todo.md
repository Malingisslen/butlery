# Sprint Backlog

## Sprint: feedback-email durable signal + verifySignupAge log hygiene — 2026-06-28

Two clean single-port functions/ fixes (observability + security log hygiene). Fresh strict
backlog re-scan this iteration → 17 genuinely A-CLEAN remain (was 38 optimistic); recorded in
.claude/state/backlog-scan.json.

### Agent A: feedback-email failure observability (cloud-functions-specialist) — Stakeholders: Customer Support/Ops
- [x] **A1. Write durable system_events on feedback-email delivery failure** `[Tier A]` (BUT-1406)
  - Step 0: CONFIRMED. `on-feedback-created.ts` only `logger.error`s on Resend non-2xx (:98) and
    network throw (:105) — no durable signal, unlike onReportCreated. A misconfigured/down email path
    silently drops beta-report notifications (the feedback doc survives, but nothing alerts ops).
  - Files: `functions/src/feedback/on-feedback-created.ts` (+ test).
  - Acceptance: both delivery-failure paths (non-2xx + throw) write a deterministic
    `system_events/feedback_email_failed_{feedbackId}` doc (set+merge, idempotent on retry) with
    type/severity:warning/feedbackId/reason/timestamp, mirroring onReportCreated · the durable-write
    is itself failure-safe (never throws out of the trigger) · the intentional unconfigured-skip path
    stays an info log (no per-feedback noise) · a unit test proves a failed send writes the event.

### Agent B: verifySignupAge log hygiene (cloud-functions-specialist) — Stakeholders: Security
- [x] **B1. Log err.message/code, not the raw err object, on two error paths** `[Tier A]` (BUT-1436)
  - Step 0: CONFIRMED. `verify-signup-age.ts:166-170` + `:301-305` spread raw `err` into the log;
    on an auth.deleteUser failure that could embed the operating account's raw uid (inconsistent with
    the hashUid-everywhere discipline).
  - Files: `functions/src/account/verify-signup-age.ts`.
  - Acceptance: both catches log a sanitized `{code?, message}` (no raw `err` object) · no raw
    uid/email can reach Cloud Logging on these paths · tsc clean.

### Post-Sprint Steps
- [ ] `cd functions && npm run build` (tsc) · run feedback + verify-signup-age CF unit tests
- [ ] Phase 2.7 verifier · cloud-functions-specialist + firebase-backend-security · commit · push · Done

---

## Recent shipped (this session): BUT-1414 (39bffed2c), BUT-1415 (3c83cbb10), BUT-1397+1394 (fac80964e), BUT-1390/1391/1393 (08e04be29), BUT-1386 (07fa820d0, In Review). Deferred for fresh context: BUT-1413 (cross-port PII), BUT-1416 (Tier-B Algolia UI), BUT-1404 (audit-purge — large-blast-radius or cost-tradeoff fix).
