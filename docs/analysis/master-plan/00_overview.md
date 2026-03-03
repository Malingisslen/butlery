# Butlery Master Fix Plan — Overview

**Created**: 2026-02-28
**Verified**: 2026-02-28 (all 168 items checked against codebase — 7 fixed, 5 reduced scope, 21 descriptions/counts corrected)
**Source**: 10 analysis reports (309 raw issues → 168 deduplicated → 161 remaining after verification)
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

| Phase | Focus | Est. Effort | Items | Verified |
|-------|-------|-------------|-------|----------|
| [1](phase_01_store_blockers.md) | Store Submission Blockers | ~5 days | 10 active (1 deferred) | P1-09→P10-12 |
| [2](phase_02_legal_compliance.md) | Legal & Compliance | ~8 days | 17 | P2-14 scope expanded |
| [3](phase_03_critical_security.md) | Critical Security | ~7 days | 19 | P3-04,06,11 corrected |
| [4](phase_04_architecture.md) | Architecture Fixes | ~4 days | 14 active (1 fixed) | P4-11 fixed, P4-02 reduced |
| [5](phase_05_ai_llm.md) | AI/LLM Safety & Quality | ~5 days | 20 | P5-02 desc corrected |
| [6](phase_06_performance.md) | Performance & Scalability | ~2 days | 9 active (4 fixed/irrelevant) | P6-02,03,07,10 removed |
| [7](phase_07_ux_accessibility.md) | UX, Accessibility & Polish | ~3 days | 19 | P7-05,06,07,08 scope reduced |
| [8](phase_08_analytics_growth.md) | Analytics & Growth | ~5 days | 21 active (1 fixed) | P8-05 fixed, P8-07 scope reduced |
| [9](phase_09_dependencies.md) | Dependencies & Tech Debt | ~5 days | 21 | P9-01,05,06,08,09,18 corrected |
| [10](phase_10_nice_to_haves.md) | Nice-to-Haves | ~3 days | 11 active (1 fixed, +1 from P1) | P10-05 fixed, P10-12 added |

**Total estimated effort**: ~47.5 days (single developer) — down from ~54 after verification (P7-09 increase offsets P7-05/P7-11 decreases)

## Progress (updated 2026-03-01)

Phases 1-7 and 9 executed across three parallel tracks (now merged to main).

| Phase | Status | Completed | Remaining |
|-------|--------|-----------|-----------|
| 1 | Partial | 3 of 10 | 4 postponed (external/pre-submission), 3 done (P1-03, P1-05–07) |
| 2 | **DONE** | 17/17 | — |
| 3 | **DONE** | 19/19 | P3-06 has 2 minor Firestore rule gaps (tracked) |
| 4 | **DONE** | 14/14 | — |
| 5 | Near-done | 19/20 | P5-17 golden dataset deferred |
| 6 | **DONE** | 9/9 | — |
| 7 | **DONE** | 19/19 | — |
| 8 | Not started | 0/21 | All 21 items — now unblocked |
| 9 | Partial | 15/21 | P9-01 deferred, 5 invalid/blocked |
| 10 | Not started | 0/11 | Post-beta |

**Totals**: 109 of 161 items completed (68%)
**Remaining effort**: ~10 days (Phase 8 ~5d + Phase 10 ~3d + stragglers ~2d)

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
| Apple Sign-In (back) | Phase 1 (P1-09) | Phase 10 (P10-12) | Only email/password auth exists — Guideline 4.8 N/A until social login added (post-beta) |
| Demo account | Phase 10 (Nice) | Phase 1 (P1-10) | Required for App Store submission |
| App store metadata | Phase 10 (Nice) | Phase 1 (P1-11) | Required for App Store submission |
| Profanity filter | Phase 10 (Nice) | Phase 2 (P2-17) | Baseline Trust & Safety for UGC apps |

## Verification Summary (2026-02-28)

All 168 items checked against actual codebase. Results:

**Removed (7 items — already fixed or wrong):**
P4-11 (VMs import interfaces correctly), P6-02 (streams have .limit()), P6-03 (audit log retention exists), P6-07 (flutter_cache_manager not used), P6-10 (StreamManagementMixin present), P8-05 (FirebaseAnalyticsObserver already wired in main.dart), P10-05 (47 keyboard shortcut occurrences)

**Reduced scope (5 items):**
P4-02 (4 models not 8), P7-05 (5 Colors.* not 42/361), P7-06 (2-3 strings not 21), P7-07 (16 total RTL issues not 104), P3-06 (2 rule gaps remain of 9)

**Description/count corrections (21 items):**
P1-07, P2-11, P2-14, P2-16, P3-04, P3-05, P3-11, P4-04, P5-02, P5-11, P6-06, P6-11, P7-01, P7-08, P7-09, P7-11, P7-12, P7-13, P7-14, P8-07, P9-01, P9-03, P9-05, P9-06, P9-08, P9-09, P9-18, P10-04

**Reprioritized (1 item):**
P1-09 → P10-12 (Apple Sign-In deferred to post-beta)

## ID Convention

`P{phase}-{sequence}` — e.g., P1-01 is Phase 1, item 1.
Severity: CRIT / HIGH / MED / LOW.
Source refs use report number + original ID (e.g., `R02:S-01`).
