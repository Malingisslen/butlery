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
