# Track 1: AI/LLM Pipeline + Dependencies

**Branch**: `track-1/ai-deps`
**Phases**: 5 (AI/LLM Safety & Quality), then 9 (Dependencies & Tech Debt — partial)
**Estimated effort**: ~10 days

## Why these are together
Phase 5 is almost entirely in `functions/src/llm/` (Cloud Functions TypeScript) and `lib/services/parsing/` (Dart). Phase 9's dependency upgrades and dead code removal are file-isolated. Neither overlaps with the other tracks.

## Phase 5 — AI/LLM Safety & Quality (~5 days, 20 items)
Reference: `docs/analysis/master-plan/phase_05_ai_llm.md`

Execute in this order (dependencies flow downward):
1. **P5-04** — Switch Mistral to EU endpoint (5 min, unlocks GDPR compliance)
2. **P5-01** — Pin LLM model versions (30 min)
3. **P5-06** — Add prompt versioning (2h)
4. **P5-07** — Add prompt injection defense (30 min)
5. **P5-02** — Add JSON Schema validation to Mistral calls (2h)
6. **P5-05** — Add few-shot examples to system prompts (4h)
7. **P5-18** — Enhancement prompt merge strategy (30 min)
8. **P5-09** — Validate description length (1h)
9. **P5-08** — Validate ingredient units against whitelist (2h)
10. **P5-19** — Validate difficulty against enum (30 min)
11. **P5-20** — Add duplicate ingredient detection (1h)
12. **P5-03** — PII scrubbing before Mistral API (1d)
13. **P5-11** — Distinct rate limit error type (2h)
14. **P5-12** — User-facing failure reasons (4h)
15. **P5-10** — Add batch import circuit breaker (2h)
16. **P5-13** — OCR usage tracker monitors wrong system (4h)
17. **P5-14** — No actual cost tracking (4h)
18. **P5-15** — Add AI kill switch via Remote Config (4h)
19. **P5-16** — Add global aggregate LLM limits (4h)
20. **P5-17** — Create golden dataset for regression testing (3d)

## Phase 9 — Dependencies & Tech Debt (partial, ~3 days)
Reference: `docs/analysis/master-plan/phase_09_dependencies.md`

**Safe to do in this track** (no overlap with Tracks 2/3):
- P9-01 — Migrate sqlcipher_flutter_libs
- P9-02 — Replace flutter_jailbreak_detection
- P9-03 — Upgrade image_cropper
- P9-04 — Remove deprecated personal_tag_manager_dialog.dart
- P9-05 — Remove deprecated backward-compatibility code
- P9-06 — Upgrade device_info_plus
- P9-07 — Upgrade csv
- P9-08 — Upgrade drift + drift_dev
- P9-09 — Tier 1 drop-in upgrades
- P9-10 — Remove flutter_cache_manager from direct deps
- P9-17 — Remove friends_service_stubs.dart
- P9-19 — CI artifact updates
- P9-20 — Extract common Duration constants
- P9-21 — Move Python site-packages out of lib/

**Defer to Track 3** (touches DI modules or architecture):
- P9-11 — Consolidate go_router vs Navigator
- P9-12, P9-13, P9-14 — File decomposition (architecture-adjacent)
- P9-15 — Update stale architecture documentation
- P9-16 — Resolve old TODO/FIXME comments
- P9-18 — recipe_image_manager.dart review

## Merge strategy
Merge to main after each phase completes. Phase 5 first, then Phase 9 partial.

---

# Track 2: Store Blockers + Legal + Security

**Branch**: `track-2/store-legal-security`
**Phases**: 1 (Store Blockers) → 2 (Legal & Compliance) → 3 (Critical Security)
**Estimated effort**: ~20 days
**Run sequentially** — Phases 2 and 3 share `main.dart` and `firestore.rules`

## Why these are together
These are the "you cannot ship without this" phases. Phase 1 fixes app store rejection issues, Phase 2 adds legal compliance (GDPR, ToS), Phase 3 closes security holes. They share key files (`main.dart`, `firestore.rules`, consent infrastructure) so they must run in order.

## Phase 1 — Store Submission Blockers (~5 days, 10 items)
Reference: `docs/analysis/master-plan/phase_01_store_blockers.md`

All 10 items. Start here — these are the fastest wins and hardest blockers.

## Phase 2 — Legal & Compliance (~8 days, 17 items)
Reference: `docs/analysis/master-plan/phase_02_legal_compliance.md`

Priority order:
1. **P2-08** — Wire ConsentService to AnalyticsService (CRITICAL — everything else depends on consent working)
2. **P2-09** — Defer Crashlytics until consent
3. **P2-10** — Defer Firebase Performance until consent
4. P2-01 — Create Terms of Service
5. P2-02 — Create community guidelines
6. P2-05 — Make auth footer ToS/Privacy links tappable
7. P2-11 — Update privacy policy with all data processors
8. P2-12 — Add AI-specific consent purpose
9. P2-13 — Load English privacy policy by locale
10. P2-03 — Wire report mechanism to Firestore
11. P2-04 — Extend report UI to all content types
12. P2-06 — Add age confirmation to registration
13. P2-07 — Add showLicensePage for OSS attribution
14. P2-14 — Account deletion missing 7 collections
15. P2-15 — Consent model field name mismatch
16. P2-16 — Social deletion batch may exceed 500-doc limit
17. P2-17 — Add content screening (profanity filter)

## Phase 3 — Critical Security (~7 days, 19 items)
Reference: `docs/analysis/master-plan/phase_03_critical_security.md`

All 19 items. Start with CRIT items (P3-03, P3-04, P3-06), then HIGH, then MED/LOW.

## Important: Phase 8 depends on this track
Phase 8 (Analytics) should only start AFTER P2-08 is merged to main (consent wiring). Without it, analytics events bypass user consent.

## Merge strategy
Merge to main after each phase completes. Phase 1 first, then 2, then 3.
