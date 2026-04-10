# Sprint Backlog

## Sprint: Consent Hardening — 2026-04-10

### Agent A: firebase-backend-security — FCM Consent Bug

- [x] **A1. Add consent change callback to ConsentService** — `lib/services/account/consent_service.dart`: VoidCallback field, invoked after successful save. (BUT-356)
- [x] **A2. Subscribe FCMService to consent changes** — `lib/services/notifications/fcm_service.dart`: listen for mid-session consent grant, re-enable push permissions + token. (BUT-356)

### Agent B: testing-specialist — Consent Test Coverage

- [x] **B1. Add ConsentService.checkSafely + onConsentChanged unit tests** — `test/unit/services/account/consent_service_test.dart`: 8 new tests covering fail-closed behavior, callback firing. (BUT-357)

### Post-Sprint Steps
- [x] Run `dart analyze --fatal-infos`
- [x] Run relevant unit tests (45/45 pass)
- [ ] Commit, push, PR, merge
- [ ] Update Linear ticket states (BUT-356, BUT-357 → Done)

---

## What this means in plain language

- Push notifications now start working if you grant permission after the app has already loaded
- A safety net of tests covers the consent checking code — future changes can't silently break GDPR compliance
- Risk: Very low. Both changes are additive. Easy to revert.

---

## Archive: Sprint Insights & Engagement (completed 2026-04-10)

- [x] A1: Cooking photos (BUT-338)
- [x] A2: Tag-based collection insights (BUT-350)
- [x] B1: Tag analytics heat map (BUT-223)
- [x] C1: Allergen EU FIC audit (BUT-354)
- [x] C2: Golden tests + coverage gates (BUT-214)

---

## Archive: Sprint Social Polish & Tech Debt (completed 2026-04-09)

- [x] A1: Fix share dialog dead end (BUT-342)
- [x] A2: Add reply shortcut on shared recipe cards (BUT-343)
- [x] A3: Improve comment engagement (BUT-305)
- [x] B1: Add search history + Algolia highlights (BUT-304)
- [x] B2: Handcraft warm dark color scheme (BUT-346)
- [x] C1: Accept or refactor 9 files exceeding 500-line limit (BUT-302)

---

## Archive: Sprint Feature & Polish (completed 2026-04-09)

- [x] A1-A3: Notification inbox (BUT-348)
- [x] B1: UNKNOWN allergen toggle (BUT-355)
- [x] B2: TagDecision audit trail UI (BUT-352)
- [x] B3: Tag thresholds → Remote Config (BUT-353)

---

## Archive: Sprint Social & Stability Blitz (completed 2026-04-08)

- [x] A1-A4: Social reliability (BUT-345, BUT-341, BUT-314, BUT-323)
- [x] B1-B2: Import & recipe bugs (BUT-337, BUT-324)
- [x] C1-C2: Dependency maintenance (BUT-300, BUT-301)

## Archive: Sprint Tech Debt Consolidation (completed 2026-04-08)

- [x] A1-A3: Refactor + performance (BUT-303, BUT-306)
- [x] B1-B2: Test fixes (BUT-303, BUT-306)
- [x] C1: Test coverage — 127 new tests (BUT-299)

## Archive: Previous Sprints

- Bug Stability + Hardening H2 (2026-04-08): BUT-308, BUT-320, BUT-335, BUT-319, BUT-336, BUT-331, BUT-317, BUT-297, BUT-313, BUT-311, BUT-312, BUT-332, BUT-327
- Security Hardening (2026-04-08): BUT-334, BUT-315, BUT-310, BUT-325, BUT-326, BUT-330, BUT-316, BUT-333, BUT-318, BUT-329, BUT-328, BUT-321
- Household + Menu Voting (2026-04-08): BUT-256, BUT-239
- Bug Cleanup + Loading Polish (2026-04-07): BUT-292-296, BUT-244
- Share & Discover (2026-04-07): BUT-219, BUT-242, BUT-272, BUT-271
- Tech Debt + UX Polish (2026-04-07): BUT-289, BUT-288, BUT-253, BUT-218, BUT-212
- Smart Import + Menu Intelligence (2026-04-06): BUT-208, BUT-241, BUT-247, BUT-204, BUT-270
