# Sprint Backlog

## Sprint: Social Polish & Tech Debt — 2026-04-09

### Agent A: flutter-developer — Social UX Quick Wins

- [x] **A1. Fix share dialog dead end** — `share_dialog_states.dart`: add inline "Bjud in vänner" CTA when no friends. (BUT-342)
- [x] **A2. Add reply shortcut on shared recipe cards** — `shared_recipe_card.dart`: add quick-reply action that opens conversation with sender. (BUT-343)
- [x] **A3. Improve comment engagement** — `comments_section.dart`: inline preview of latest comment, edit capability, reaction hint icon. (BUT-305)

### Agent B: flutter-developer — Search & Theme Polish

- [x] **B1. Add search history + Algolia highlights** — `recipe_query_viewmodel.dart`, search widgets: persist recent queries, render `highlightedTitle`/`highlightedDescription`. (BUT-304)
- [x] **B2. Handcraft warm dark color scheme** — `butlery_colors.dart`, theme files: replace auto-generated cold dark with warm dark brown (#1A1611). (BUT-346)

### Agent C: code-reviewer — Tech Debt

- [x] **C1. Accept or refactor 9 files exceeding 500-line limit** — review each file, refactor where beneficial, accept with rationale where appropriate. (BUT-302)

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests
- [ ] Commit, push, PR, merge
- [ ] Update Linear ticket states

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
