# Sprint Backlog

## Sprint: Feature & Polish — 2026-04-09

### Agent A: flutter-developer — Notification Inbox

- [x] **A1. Add NotificationHistoryEntry model + repo/service getHistory** — `notification_history_entry.dart` (new), `notification_history_repository.dart`, `firebase_notification_history_repository.dart`, `notification_service.dart`. (BUT-348)
- [x] **A2. Add NotificationsViewModel** — `notifications_viewmodel.dart` (new). (BUT-348)
- [x] **A3. Add NotificationsView + route + DI** — `notifications_view.dart` (new), `routes.dart`, `app_router.dart`, l10n. (BUT-348)

### Agent B: flutter-developer — Quick Wins

- [x] **B1. Add UNKNOWN allergen toggle** — `allergen_preferences_view.dart`, `allergen_preferences_viewmodel.dart`, l10n. (BUT-355)
- [x] **B2. Add TagDecision audit trail UI** — `allergen_status_badge.dart`, `dietary_status_badge.dart`, `tag_result_display.dart`, l10n. (BUT-352)
- [x] **B3. Wire tag thresholds to Remote Config** — `feature_flag_service.dart`, `tagging_thresholds.dart`, `tag_phase3_complex.dart`, `tag_generator.dart`. (BUT-353)

### Post-Sprint Steps
- [x] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests
- [ ] Commit, push, PR, merge
- [ ] Update Linear ticket states

---

## Archive: Sprint Social & Stability Blitz (completed 2026-04-08)

- [x] A1-A4: Social reliability (BUT-345, BUT-341, BUT-314, BUT-323)
- [x] B1-B2: Import & recipe bugs (BUT-337, BUT-324)
- [x] C1-C2: Dependency maintenance (BUT-300, BUT-301)

## Archive: Sprint Tech Debt Consolidation (completed 2026-04-08)

- [x] A1-A3: Refactor + performance (BUT-303, BUT-306)
- [x] B1-B2: Test fixes (BUT-303, BUT-306)
- [x] C1: Test coverage — 127 new tests (BUT-299)

## Archive: Sprint Bug Stability + Hardening H2 (completed 2026-04-08)

- [x] A1-A4: Build blockers & backend stability (BUT-308, BUT-320, BUT-335, BUT-319)
- [x] B1-B2: Data integrity (BUT-336, BUT-331)
- [x] C1-C2: GDPR compliance (BUT-317, BUT-297)
- [x] D1: Cooking mode UX (BUT-322)
- [x] H2 A1-A2: GDPR + security tests (BUT-297, BUT-298)
- [x] H2 B1-B3: Social bugs (BUT-313, BUT-311, BUT-312)
- [x] H2 C1-C2: Performance + resource leaks (BUT-332, BUT-327)

## Archive: Previous Sprints

- Security Hardening Part 2 (2026-04-08): BUT-329, BUT-328, BUT-321
- Security Hardening (2026-04-08): BUT-334, BUT-315, BUT-310, BUT-325, BUT-326, BUT-330, BUT-316, BUT-333, BUT-318
- Household + Menu Voting (2026-04-08): BUT-256, BUT-239
- Bug Cleanup + Loading Polish (2026-04-07): BUT-292-296, BUT-244
- Share & Discover (2026-04-07): BUT-219, BUT-242, BUT-272, BUT-271
- Tech Debt + UX Polish (2026-04-07): BUT-289, BUT-288, BUT-253, BUT-218, BUT-212
- Smart Import + Menu Intelligence (2026-04-06): BUT-208, BUT-241, BUT-247, BUT-204, BUT-270
