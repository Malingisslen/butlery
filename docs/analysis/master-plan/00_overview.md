# Butlery Master Fix Plan — Overview

**Created**: 2026-02-28
**Source**: 10 analysis reports (309 raw issues → 168 deduplicated)
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
| [1](phase_01_store_blockers.md) | Store Submission Blockers | ~6 days | 11 |
| [2](phase_02_legal_compliance.md) | Legal & Compliance | ~8 days | 17 |
| [3](phase_03_critical_security.md) | Critical Security | ~9 days | 19 |
| [4](phase_04_architecture.md) | Architecture Fixes | ~5 days | 15 |
| [5](phase_05_ai_llm.md) | AI/LLM Safety & Quality | ~5 days | 20 |
| [6](phase_06_performance.md) | Performance & Scalability | ~3 days | 13 |
| [7](phase_07_ux_accessibility.md) | UX, Accessibility & Polish | ~4 days | 19 |
| [8](phase_08_analytics_growth.md) | Analytics & Growth | ~5 days | 22 |
| [9](phase_09_dependencies.md) | Dependencies & Tech Debt | ~5 days | 21 |
| [10](phase_10_nice_to_haves.md) | Nice-to-Haves | ~4 days | 11 |

**Total estimated effort**: ~54 days (single developer)

## Deduplication Log

Issues appearing in 2+ reports — each listed exactly once in the phase where it's most actionable:

| Issue | Reports | Appears In |
|-------|---------|------------|
| Bundle ID `com.example.butlery` | 03, 06, 10 | Phase 1 (P1-01) |
| Debug signing for release | 02, 03, 06, 10 | Phase 1 (P1-02) |
| Orphan `NSFaceIDUsageDescription` | 02, 06, 09, 10 | Phase 1 (P1-03) |
| No Terms of Service | 06, 09, 10 | Phase 2 (P2-01) |
| Community guidelines missing | 06, 09 | Phase 2 (P2-02) |
| `runZonedGuarded` no-op + ErrorApp | 01, 02, 04, 10 | Phase 3 (P3-01) — merged |
| PII in logs | 01, 02 | Phase 3 (P3-02) |
| Rate limiters fail-open | 02, 07 | Phase 3 (P3-03) |
| SSL pinning non-functional | 02, 03 | Phase 3 (P3-05) |
| Firestore rules gaps | 02, 04 | Phase 3 (P3-06) |
| Deep link validation + debugInfo | 02, 10 | Phase 3 (P3-07) — merged |
| FCM cleanup in account deletion | 02 | Phase 3 (P3-09) — see also P2-14 |
| `Random.secure()` for short codes | 02 | Phase 3 (P3-11) — see also P3-07 |
| Firebase collection constants | 01, 06 | Phase 4 (P4-01) |
| SerializationUtils adoption gaps | 01, 03 | Phase 4 (P4-02) |
| Source URL PII to Mistral | 07, 09 | Phase 5 (P5-03) |
| Error app stack traces | 02, 10 | Phase 3 (P3-01) — merged |
| ConsentService not wired | 09 | Phase 2 (P2-08) |
| No privacy manifest | 09 | Phase 1 (P1-05) |

## Merges Applied

Items combined for efficiency (same file, same fix session, or trivial together):

| Merged Items | Result | Rationale |
|-------------|--------|-----------|
| P3-01 + P3-02 (old) | P3-01 | Both in `main.dart`, causally related |
| P3-12 into P3-08 (old) | P3-07 | Same file (`deep_link_handler.dart`) |
| P4-03 + P4-11 (old) | P4-03 | Same file (`personal_tags_view.dart:19-20`) |
| P4-09 + P4-17 (old) | P4-09 | Identical pattern (remove Firebase static refs) |
| P7-12 + P7-13 + P7-22 (old) | P7-12 | All trivial LOW housekeeping (<1h combined) |
| P7-18 + P7-19 (old) | P7-17 | Both pre-release metadata hygiene |
| P9-15 + P9-16 (old) | P9-15 | Both documentation-only updates |
| P9-20 + P9-21 (old) | P9-19 | Both CI yaml tweaks (same files, same session) |

## Moves Applied

Items relocated to more appropriate phases:

| Item | From | To | Reason |
|------|------|----|--------|
| Notification rate limiting | Phase 6 (Perf) | Phase 3 (P3-17) | Security/abuse concern, not performance |
| OCR SSRF risk | Phase 6 (Perf) | Phase 3 (P3-18) | SSRF is a security vulnerability |
| Notification error leakage | Phase 7 (UX) | Phase 3 (P3-19) | Information leakage, not UX |
| Python site-packages in lib/ | Phase 7 (UX) | Phase 9 (P9-21) | Repo hygiene/tech debt |
| Apple Sign-In | Phase 10 (Nice) | Phase 1 (P1-09) | Required by Apple Review Guideline 4.8 |
| Demo account | Phase 10 (Nice) | Phase 1 (P1-10) | Required for App Store submission |
| App store metadata | Phase 10 (Nice) | Phase 1 (P1-11) | Required for App Store submission |
| Profanity filter | Phase 10 (Nice) | Phase 2 (P2-17) | Baseline Trust & Safety for UGC apps |

## ID Convention

`P{phase}-{sequence}` — e.g., P1-01 is Phase 1, item 1.
Severity: CRIT / HIGH / MED / LOW.
Source refs use report number + original ID (e.g., `R02:S-01`).
