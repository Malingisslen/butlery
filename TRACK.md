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
