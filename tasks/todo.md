# Sprint Backlog

## Sprint: extend main-health-alert to watch all critical workflows — 2026-06-28

Single clean Tier-A ops-resilience config fix (no production code).

### Agent A: CI health alert (direct) — Stakeholders: DevOps/SRE
- [x] **A1. Watch all 11 critical gating workflows, not just 3** `[Tier A]` (BUT-1425)
  - Step 0: CONFIRMED. `main-health-alert.yml` watched only Run Tests / Build Validation /
    Architecture; a red Firestore Rules / Deploy Firebase / E2E / Dependency Audit / LLM Golden /
    Model Version Guard / SBOM / Prompt Changelog on main opened no tracking issue — the exact
    solo-dev blind spot BUT-435 built this to kill, still live for ~8 of 14 workflows.
  - Files: `.github/workflows/main-health-alert.yml`.
  - Acceptance: the 8 named uncovered workflows added to BOTH the `workflow_run` trigger list AND the
    `gates` array, using exact `name:` strings · trigger == gates (identical 11-entry sets) · does NOT
    watch itself (no recursion) · nightly-chore + tag/manual release correctly excluded · YAML valid.
  - VERIFIED: YAML parses; 11==11 in sync; all names match real workflows; no self-watch; verifier PASS.

### Post-Sprint Steps
- [x] YAML validated + names cross-checked + verifier PASS
- [ ] Commit, push, Done

---

## Recent shipped (this session): BUT-1401 (077212635), BUT-1428 (412efb5ed), BUT-1406+1436 (0b42c9280), BUT-1414 (39bffed2c), BUT-1415 (3c83cbb10), BUT-1397+1394 (fac80964e), BUT-1390/1391/1393 (08e04be29), BUT-1386 (07fa820d0, In Review).
