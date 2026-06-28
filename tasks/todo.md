# Sprint Backlog

## Sprint: direct unit tests for 3 GDPR-export sub-managers — 2026-06-28

Single clean Tier-A test-gap (GDPR Article-15/20 export coverage). Test-only; touches
test/**/*.dart → code-reviewer commit gate applies (not testing-specialist/firebase, those
key on lib/). Router said full-panel by path, but this is test-only encoding of the existing
contract → treat as testing + a GDPR-completeness lens, not a 6-role design panel.

### Agent A: GDPR export coverage (direct) — Stakeholders: testing + Privacy/GDPR lens
- [ ] **A1. Direct tests for the 3 export sub-managers** `[Tier A]` (BUT-1438)
  - Step 0: CONFIRMED. activity/social/content managers exist; only compliance_export_manager
    has a direct test today. All 3 use ctor-injected repo seams → fakeable without emulator.
  - Files: `test/unit/services/account/export/{activity,social,content}_export_manager_test.dart`.
  - Acceptance: every public export method of each manager has a test asserting each record-type
    key is present + records are reshaped (id→typed-id, data passed through) · a dropped record
    type would fail an assertion · runs in unit lane (mock repos, no emulator) · analyze clean.

### Post-Sprint Steps (BUT-1438)
- [ ] dart analyze + run the 3 tests · code-reviewer marker · commit · push · Done

---

## Sprint: fix self-contradicting Technical-Writer §20 in ROLE_RESPONSIBILITY_MAP — 2026-06-28

Single clean Tier-A doc fix. No code, no commit-gate markers (doc-only diff).

### Agent A: doc-consistency (direct) — Stakeholders: Technical Writer (skip-tier, doc-only)
- [x] **A1. Remove §20 self-contradiction + correct inventory counts** `[Tier A]` (BUT-1421)
  - Step 0: CONFIRMED. §20 IS the Technical Writer role, yet its body said "Not yet in
    ROLE_RESPONSIBILITY_MAP — no dedicated Technical Writer role defined" and its 3rd watch item
    said the map "enumerates 18 roles" with no doc owner. Both false + self-referential.
  - Counts re-verified against live repo (ticket's own numbers were partly stale):
    ops/ = 9 (not 8; cert-rotation doesn't exist, backups+freerasp missing) · security/ = 3 (not 4) ·
    per-dir CLAUDE.md = root + 5 (not "6 per-directory") · lessons.md = 23 (not 22) ·
    role index = 28 (not 18) · adoption measured 2026-06-27 (not 06-26).
  - Files: `docs/architecture/ROLE_RESPONSIBILITY_MAP.md` (§20 body + 3rd watch item).
  - Acceptance: body no longer claims the role is undefined (now states §20 owns it) · 3rd watch item
    reflects the role exists + correct 28-role count · every inventory count matches the live repo ·
    no stale 2026-06-26 date.

### Post-Sprint Steps
- [x] Counts verified against repo · commit · push · Done (doc-only; no analyze/tests/markers needed)

---

## Recent shipped (this session): BUT-1412 (31a184e09), BUT-1435 (c89a6f488), BUT-1405 (2a041d5b8), BUT-1407 (ac9ffb80d), BUT-1425 (2293bf051), BUT-1401 (077212635), BUT-1428 (412efb5ed), BUT-1406+1436 (0b42c9280), BUT-1414 (39bffed2c), BUT-1415 (3c83cbb10), BUT-1397+1394 (fac80964e), BUT-1390/1391/1393 (08e04be29), BUT-1386 (07fa820d0, In Review).
