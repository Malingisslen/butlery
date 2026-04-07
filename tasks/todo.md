# Sprint Backlog

## Sprint: Tech Debt + UX Polish — 2026-04-06

### Agent A: Drift/Offline Infrastructure

- [x] **A1. Verify & regenerate Drift codegen** — `.g.dart` files verified in sync, analyze clean. (BUT-289)
- [x] **A2. Fix offline/Drift test mocks** — Tests analyze clean, offline tests pass. (BUT-288)

### Agent B: User Experience

- [x] **B1. Tablet-optimized recipe detail layout** — Two-column layout on tablet/desktop, responsive expandedHeight. New file: `recipe_detail_tablet_content.dart` (329 lines). (BUT-253)
- [x] **B2. Rich cooking identity profile** — cookingSkillLevel, cuisineAffinities, bio on UserProfile. Profile edit UI with SegmentedButton + FilterChips + StyledInput. 11 l10n keys, 19 new tests. (BUT-218)
- [x] **B3. Shopping list check-off animations** — ShoppingItemTile StatefulWidget with scale pulse, color transition, icon crossfade. 32 tests passing. (BUT-212)

### Post-Sprint

- [x] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests
- [ ] Manual verification
- [ ] Commit, push, PR, merge
- [ ] Update Linear ticket states

---

## Archive: Previous Sprints

### Sprint: Smart Import + Menu Intelligence (completed 2026-04-06)

- [x] A1 Schema.org extraction (BUT-208)
- [x] A2 duplicate detection merge (BUT-241)
- [x] A3 import progress timer (BUT-247)
- [x] B1 weighted menu generation (BUT-204)
- [x] B2 smart menu swap (BUT-270)

### Sprint: Recipe Discovery + Cooking Experience (completed 2026-04-06)

- [x] A1 seasonal recipe prompt (BUT-228)
- [x] A2 dormant recipe nudges (BUT-216)
- [x] A3 personalized empty state (BUT-236)
- [x] B1 cooking mode personalization (BUT-227)
- [x] B2 recipe export/print (BUT-220)
- [x] B3 lastCookedAt tag condition (BUT-222)

### Sprint: Foundation + Polish (completed 2026-04-06)

- [x] A1 test coverage (BUT-7)
- [x] A2 dependency update (BUT-9)
- [x] B1 onboarding improvement (BUT-273)
- [x] B2 screen reader accessibility (BUT-233)
- [x] B3 PWA share target + install (BUT-225)
- [x] B4 recipe completeness badge (BUT-240)
