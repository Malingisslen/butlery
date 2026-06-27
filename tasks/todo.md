# Sprint Backlog

## Sprint: direct tests for the allergen calculator — 2026-06-28

Pure test-addition (zero production risk) on the app's #1 safety surface. Scoped to the
allergen calculator (highest value); the 3 GDPR-export-manager tests filed as a follow-up.

### Agent A: allergen calculator tests (testing-specialist) — Stakeholders: Data/ML, QA, Privacy
- [x] **A1. Add direct unit tests for Phase1AllergenCalculator** `[Tier A]` (BUT-1401, partial)
  - Step 0: CONFIRMED. `tag_phase1_allergen.dart` computes per-allergen FREE/CONTAINS/UNKNOWN and
    has zero direct tests. The TriState math lives in IngredientLookupResult.getPropertyStatus
    (unknown when coverage<1.0; contains if a matched ingredient has the trigger property; else free);
    the calculator iterates the (Firebase or static-fallback) allergen config and records decisions.
    Builders exist (TaggingTestHelper.ingredient + IngredientLookupResult ctor).
  - Files: `test/unit/services/tagging/phases/tag_phase1_allergen_test.dart` (new).
  - Acceptance: tests cover CONTAINS (matched ingredient has the trigger property @ full coverage),
    FREE (full coverage, no trigger), UNKNOWN (coverage<1.0 → cannot confirm) · a CONTAINS decision
    records the triggering ingredient · every static allergen key gets a status entry + a decision ·
    test passes, analyze clean.

### Follow-up filed (not in this sprint)
- GDPR Article-15 export sub-manager tests (activity/social/content_export_manager) — separate
  harnesses; deferred to keep this iteration tight.

### Post-Sprint Steps
- [ ] `dart analyze` + run the new test · Phase 2.7 verifier · testing-specialist · commit · push · Done

---

## Recent shipped (this session): BUT-1428 (412efb5ed), BUT-1406+1436 (0b42c9280), BUT-1414 (39bffed2c), BUT-1415 (3c83cbb10), BUT-1397+1394 (fac80964e), BUT-1390/1391/1393 (08e04be29), BUT-1386 (07fa820d0, In Review).
