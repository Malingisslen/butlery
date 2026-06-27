# Sprint Backlog

## Sprint: win-back attribution — don't clobber an un-attributed send — 2026-06-28

Single clean Tier-A correctness fix (analytics integrity). Single-port functions/, user doc
already read upstream so the gate is free (no extra read).

### Agent A: win-back attribution (cloud-functions-specialist) — Stakeholders: Growth/ASO, Data/BI
- [x] **A1. Skip bridge-field overwrite while an earlier send is still un-attributed** `[Tier A]` (BUT-1428)
  - Step 0: CONFIRMED. `detect-lapsed-users.ts:228-238` overwrites the 4 `lastWinBack*` bridge fields
    on every threshold trigger (header even says "we DO NOT gate"). A user crossing 7-then-14-day
    close together has the earlier (un-consumed) send's variant clobbered; the client's single-
    attribution latch then credits the conversion to the later variant → biases the A/B. The candidate
    scan already reads the full user doc (`userDoc.data()`), so the existing `lastWinBackSentAt` is
    available with no extra read. Fix = ticket option 1 (skip the merge while an earlier send is in
    its window); the heavier per-send-log option deferred.
  - Files: `functions/src/analytics/detect-lapsed-users.ts` (+ `detect-lapsed-users.test.ts`).
  - Acceptance: the bridge `lastWinBack*` merge is SKIPPED when the existing `lastWinBackSentAt` is
    present AND within a 7-day attribution window (client clears the fields on attribution, so
    present+fresh = un-attributed) · a stale prior send (past the window) is still overwritten as
    before · the user still gets the notification + analytics event (only the attribution bridge is
    preserved) · tests prove both the skip (fresh prior) and the overwrite (stale prior) paths · the
    header comment reflects the new gating.

### Post-Sprint Steps
- [ ] `cd functions && npm run build` (tsc) · run detect-lapsed-users test
- [ ] Phase 2.7 verifier · cloud-functions-specialist · commit · push · Done

---

## Recent shipped (this session): BUT-1406+1436 (0b42c9280), BUT-1414 (39bffed2c), BUT-1415 (3c83cbb10), BUT-1397+1394 (fac80964e), BUT-1390/1391/1393 (08e04be29), BUT-1386 (07fa820d0, In Review). Deferred for fresh context: BUT-1413 (cross-port PII), BUT-1416 (Tier-B Algolia UI), BUT-1404 (audit-purge large-blast/cost-tradeoff).
