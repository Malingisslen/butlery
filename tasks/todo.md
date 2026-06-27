# Sprint Backlog

## Sprint: register /fileImport in route sets (auth-gate bypass) — 2026-06-28

Single clean Tier-A security/correctness fix (route-table config, no UI/view change).

### Agent A: route registration (direct) — Stakeholders: Information Architect, Security
- [x] **A1. Add fileImport to allRoutes + authenticatedRoutes + bottomSlideRoutes** `[Tier A]` (BUT-1412)
  - Step 0: CONFIRMED. `routes.dart:38` declares `fileImport='/fileImport'` (handled by
    ExtractionDeferredModule→FileImportView), but it's absent from allRoutes (isValidRoute=false),
    authenticatedRoutes (requiresAuth=false → auth gate skipped → FileImportView builds for a
    signed-out user), and bottomSlideRoutes (wrong animation vs its 4 sibling import modals).
  - Files: `lib/core/constants/routes.dart` + new `test/unit/core/constants/routes_test.dart`.
  - Acceptance: fileImport ∈ allRoutes (isValidRoute('/fileImport')==true) · fileImport ∈
    authenticatedRoutes (requiresAuth('/fileImport')==true — the security fix) · fileImport ∈
    bottomSlideRoutes (getAnimationType==slideFromBottom, matching sibling import modals) · a test
    pins all three + a regression guard that every import-modal route is auth-gated · analyze clean.

### Post-Sprint Steps
- [ ] dart analyze + run routes test · Phase 2.7 verifier · code-reviewer + testing-specialist · commit · push · Done

---

## Recent shipped (this session): BUT-1435 (c89a6f488), BUT-1405 (2a041d5b8), BUT-1407 (ac9ffb80d), BUT-1425 (2293bf051), BUT-1401 (077212635), BUT-1428 (412efb5ed), BUT-1406+1436 (0b42c9280), BUT-1414 (39bffed2c), BUT-1415 (3c83cbb10), BUT-1397+1394 (fac80964e), BUT-1390/1391/1393 (08e04be29), BUT-1386 (07fa820d0, In Review).
