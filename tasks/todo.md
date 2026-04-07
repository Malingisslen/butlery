# Sprint Backlog

## Sprint: Share & Discover — 2026-04-07

### Agent A: Social Discovery

- [x] **A1. Add shareable public recipe collection** — PublicProfileView + PublicProfileViewModel, deep link /profile route, share button on friend profile, fetchPublicUserRecipes repository method. (BUT-219)

### Agent B: Recipe Intelligence

- [x] **B1. Enhance collection health dashboard** — Completeness stats in RecipeQueryViewModel, distribution bar + quick-fix entry points in CollectionStatsView. (BUT-242)

### Agent C: Social Polish

- [x] **C1. Enrich friend cards with subtitle** — `friends_list_cards.dart`: bio or last-active fallback. (BUT-272)
- [x] **C2. Fix shared-with-me empty state** — `shared_with_me_view.dart`: explain sharing + "Dela ett recept" CTA. (BUT-271)

### Post-Sprint

- [x] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests
- [ ] Commit, push, PR, merge
- [ ] Update Linear ticket states

---

## Archive: Previous Sprints

### Sprint: Tech Debt + UX Polish (completed 2026-04-07)

- [x] A1 Drift codegen verified (BUT-289)
- [x] A2 offline test mocks fixed (BUT-288)
- [x] B1 tablet recipe detail layout (BUT-253)
- [x] B2 cooking identity profile (BUT-218)
- [x] B3 shopping check-off animations (BUT-212)

### Sprint: Smart Import + Menu Intelligence (completed 2026-04-06)

- [x] A1 Schema.org extraction (BUT-208)
- [x] A2 duplicate detection merge (BUT-241)
- [x] A3 import progress timer (BUT-247)
- [x] B1 weighted menu generation (BUT-204)
- [x] B2 smart menu swap (BUT-270)
