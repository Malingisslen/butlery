# Sprint Backlog

## Sprint: constrain the feedback create rule — 2026-06-28

Single clean Tier-A security fix (input validation on a user-writable collection). Single-port
(firestore.rules + its rules test). Fresh full backlog re-scan this iteration → 19 genuinely
A-CLEAN remain (~10 stone-cold); slice NOT drained. Recorded in backlog-scan.json.

### Agent A: feedback rule hardening (firestore-rules-tester) — Stakeholders: Customer Support/Ops, Security, DBA
- [x] **A1. Add keys().hasOnly + required-fields + size caps to feedback create** `[Tier A]` (BUT-1407)
  - Step 0: CONFIRMED. `firestore.rules:2027-2040` create = `isAuthenticated() && isCreatingOwnDocument()`
    only — no shape/size limits, so a beta user can write a near-1MB description or a giant
    recentInteractions array (admin-dashboard read-cost + storage abuse). Client write shape
    (`feedback_entry.dart toMap`, written verbatim) is EXACTLY 10 keys: id, userId, category,
    description, email, screenshotUrl, recentInteractions, createdAt, deviceInfo, status. Sibling
    collections already cap (deep_links/clicks keys().hasOnly, ingredient_suggestions size).
  - Files: `firestore.rules` (feedback create), `functions/src/__tests__/feedback-rules.test.ts`.
  - Acceptance: create requires keys().hasOnly([the 10 client keys]) + hasRequiredFields(userId,
    category, description, createdAt) + description is string ≤5000 + recentInteractions is list ≤50 ·
    a legit full-payload submission still succeeds · deny tests for extra-field, oversized description,
    oversized recentInteractions, missing-required · existing allow/deny feedback rules tests stay green.

### Post-Sprint Steps
- [ ] Emulator rules suite (feedback-rules) green · Phase 2.7 verifier · firestore-rules-tester + firebase-backend-security · commit · push · Done

---

## Recent shipped (this session): BUT-1425 (2293bf051), BUT-1401 (077212635), BUT-1428 (412efb5ed), BUT-1406+1436 (0b42c9280), BUT-1414 (39bffed2c), BUT-1415 (3c83cbb10), BUT-1397+1394 (fac80964e), BUT-1390/1391/1393 (08e04be29), BUT-1386 (07fa820d0, In Review).
