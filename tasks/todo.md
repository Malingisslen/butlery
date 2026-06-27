# Sprint Backlog

## Sprint: LLM retry storm + menu allergen-safety filter — 2026-06-27

Two High-priority `autonomous` Tier-A bug fixes. Both route `single` (Phase 1.5 gate fires on
High priority → richer acceptance below, no halt). Stakeholder concerns folded into acceptance;
Phase 3 commit gate runs code-reviewer + testing-specialist.

### Agent A: LLM retry predicate (debugger/direct) — Stakeholders: Data/ML Engineer, Performance
- [ ] **A1. Fix LlmTier retry storm — typed shouldRetry instead of string-match** `[Tier A]` (BUT-1397)
  - Step 0: CONFIRMED. `llm_tier.dart:101` uses `RetryHelper.retryNetworkOperation` whose predicate
    substring-matches English Firebase codes on `error.toString()` + defaults `true`. But
    `structureRecipe` always throws `LlmException` (llm_service.dart:370/374) whose `toString()` is
    `"LlmException: <localized msg>"` — no English code → every error hits the `true` default and is
    retried 3×, including rate-limit + invalid-argument. `fromFirebase` codes: unauthenticated /
    resource-exhausted(isRateLimited) / invalid-argument / deadline-exceeded / unavailable / unknown.
  - Files: `lib/services/parsing/tiers/llm_tier.dart` (call site → `retryWithBackoff` + typed shouldRetry)
  - Acceptance: the retry predicate inspects the typed `LlmException` (not `toString()`) · retries
    ONLY `code=='unavailable' || code=='deadline-exceeded'` · NEVER retries when `isRateLimited` or
    `code=='invalid-argument'` (or unknown/unauthenticated) · a unit test proves a rate-limited
    LlmException is attempted exactly once (no retry) and an `unavailable` one is retried.

### Agent B: menu allergen-safety filter (direct) — Stakeholders: Data/ML Engineer, Product Manager
- [ ] **B1. Single-user menu filter excludes untagged recipes when "include unknown" is off** `[Tier A]` (BUT-1394)
  - Step 0: CONFIRMED. `menu_generator.dart` async `_filterByPrefs` correctly returns `includeUnknown`
    for null tagResult (:133,:147); the sync `_filterByAllergenPreferences` (:170) and
    `_filterByDietaryPreferences` (:196) `return true` unconditionally — untagged recipes slip into a
    single-user menu even with the opt-out off. Safety surface (allergen-free filtering).
  - Files: `lib/viewmodels/menu/menu_generator.dart` (:170, :196 → `return includeUnknown;`)
  - Acceptance: both sync null-tagResult branches return `includeUnknown` (mirror the async path) ·
    a guard test asserts an untagged recipe is EXCLUDED from a single-user menu when
    `includeUnknownInMenu == false` and INCLUDED when true · no behavior change for tagged recipes.

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos lib test`
- [ ] Relevant tests: llm_tier_test, menu_generator_test
- [ ] Phase 2.7 outcome verifier
- [ ] Commit (code-reviewer + testing-specialist), push
- [ ] BUT-1397/1394 → Done (Tier A) + comments

---

## Sprint: backend cost/correctness + UGC safety — 2026-06-27 — SHIPPED (commit 08e04be29)
BUT-1390 (rate-limit cleanup cost leak + GDPR erasure), BUT-1391 (ingredients index), BUT-1393
(UGC profanity gate) — all Done. CI green. Closed dup BUT-1433/1434.

## Sprint: ADR-0002 age gate (BUT-1386) — 2026-06-27 — SHIPPED (commit 07fa820d0, In Review)
Server-authoritative age enforcement. In Review for legal-copy/store-rating/App-Check sign-offs.
