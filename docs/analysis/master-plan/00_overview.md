# Butlery Master Fix Plan — Overview

**Created**: 2026-02-28
**Source**: 10 analysis reports (309 raw issues → ~195 deduplicated)
**Status**: Pre-production (no migration concerns, breaking changes are free)

## Scores by Report

| # | Report | Score | Issues |
|---|--------|-------|--------|
| 01 | Code Quality & Architecture | 68.5/100 | 55 |
| 02 | Security & Compliance | 67/100 | 46 |
| 03 | Infrastructure & Operations | 57/100 | 23 |
| 04 | Performance & Scalability | 78/100 | 20 |
| 05 | Dependencies & Supply Chain | 76/100 | 19 |
| 06 | UX & Platform | 70/100 | 32 |
| 07 | AI/LLM Quality | 55/100 | 44 |
| 08 | Product Analytics & Growth | 46/100 | 32 |
| 09 | Trust, Safety & Privacy | 18/100 | 22 |
| 10 | Monetization & Positioning | 56/100 | 20 |

## Phase Summary

| Phase | Focus | Est. Effort | Items |
|-------|-------|-------------|-------|
| [1](phase_01_store_blockers.md) | Store Submission Blockers | ~2 days | 8 |
| [2](phase_02_legal_compliance.md) | Legal & Compliance | ~5 days | 16 |
| [3](phase_03_critical_security.md) | Critical Security | ~4 days | 18 |
| [4](phase_04_architecture.md) | Architecture Fixes | ~5 days | 17 |
| [5](phase_05_ai_llm.md) | AI/LLM Safety & Quality | ~5 days | 20 |
| [6](phase_06_performance.md) | Performance & Scalability | ~4 days | 15 |
| [7](phase_07_ux_accessibility.md) | UX, Accessibility & Polish | ~5 days | 24 |
| [8](phase_08_analytics_growth.md) | Analytics & Growth | ~5 days | 22 |
| [9](phase_09_dependencies.md) | Dependencies & Tech Debt | ~5 days | 22 |
| [10](phase_10_nice_to_haves.md) | Nice-to-Haves | ~5+ days | 15 |

**Total estimated effort**: ~45 days (single developer)

## Deduplication Log

Issues appearing in 2+ reports — each listed exactly once in the phase where it's most actionable:

| Issue | Reports | Appears In |
|-------|---------|------------|
| Bundle ID `com.example.butlery` | 03, 06, 10 | Phase 1 (P1-01) |
| Debug signing for release | 02, 03, 06, 10 | Phase 1 (P1-02) |
| Orphan `NSFaceIDUsageDescription` | 02, 06, 09, 10 | Phase 1 (P1-03) |
| No Terms of Service | 06, 09, 10 | Phase 2 (P2-01) |
| Community guidelines missing | 06, 09 | Phase 2 (P2-02) |
| Missing `showLicensePage()` | 05 | Phase 2 (P2-07) |
| `runZonedGuarded` no-op | 01, 04, 10 | Phase 3 (P3-01) |
| PII in logs | 01, 02 | Phase 3 (P3-03) |
| Rate limiters fail-open | 02, 07 | Phase 3 (P3-04) |
| SSL pinning non-functional | 02, 03 | Phase 3 (P3-06) |
| Firestore rules gaps | 02, 04 | Phase 3 (P3-07) |
| Firebase collection constants | 01, 06 | Phase 4 (P4-01) |
| SerializationUtils adoption gaps | 01, 03 | Phase 4 (P4-02) |
| Repository boundary violations | 01 | Phase 4 (P4-03–P4-05) |
| Source URL PII to Mistral | 07, 09 | Phase 5 (P5-03) |
| Server-side rate limiting UGC | 09 | Phase 3 (P3-15) |
| Deep link validation | 02, 10 | Phase 3 (P3-08) |
| Error app stack traces | 02, 10 | Phase 3 (P3-02) |
| ConsentService not wired | 09, 08 | Phase 2 (P2-08) |
| No privacy manifest | 09, 10 | Phase 1 (P1-05) |

## ID Convention

`P{phase}-{sequence}` — e.g., P1-01 is Phase 1, item 1.
Severity: CRIT / HIGH / MED / LOW.
Source refs use report number + original ID (e.g., `R02:S-01`).
