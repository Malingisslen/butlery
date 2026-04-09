# Sprint Backlog

## Sprint: Insights & Engagement — 2026-04-09

### Agent A: flutter-developer — Social & Insights

- [ ] **A1. Add cooking photos ("Jag lagade detta")** — extend "Lagat idag" with photo upload, gallery on recipe detail, author notification loop. (BUT-338)
- [ ] **A2. Add tag-based collection insights** — aggregate view: cooking pattern stats from existing tag data. (BUT-350)

### Agent B: flutter-developer — Tagging Polish

- [ ] **B1. Add tag analytics heat map + dead tag detection** — usage bars on PersonalTagsView, highlight 0-recipe tags. Existing `getTagUsageCounts()` data. (BUT-223)

### Agent C: code-reviewer — Quality & Compliance

- [ ] **C1. Review allergen system against EU FIC 1169/2011** — audit 14 EU allergens coverage, cross-contamination gaps, Livsmedelsverket alignment. (BUT-354)
- [ ] **C2. Improve CI/CD: golden tests + coverage gates** — add golden tests for key UI components, enforce coverage threshold. (BUT-214)

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests
- [ ] Commit, push, PR, merge
- [ ] Update Linear ticket states

---

## What this means in plain language

- You'll be able to **take a photo when you cook a recipe** and share it — friends who shared the recipe get notified
- A new **"My Collection" insights screen** shows your cooking patterns (% vegetarian, top cuisines, etc.)
- Your **personal tags screen gets visual indicators** — see which tags are heavily used vs. dead
- Your **allergen tagging gets audited** against actual EU food regulations for beta safety
- **CI gets golden tests** so UI regressions are caught automatically
- Risk: Cooking photos is the biggest item — requires photo upload + gallery + notifications. Others are small. Easy to undo since all are additive features.

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
