# Sprint Backlog

## Sprint: Security Hardening — 2026-04-08

### Agent A: firebase-backend-security — Auth & Permission Fixes

- [x] **A1. Fix auth route gaps** — `lib/core/constants/routes.dart`: added `settings` to `authenticatedRoutes`, `allRoutes`, `rightSlideRoutes`. (BUT-334)
- [x] **A2. Add proactive token refresh** — `lib/services/auth_service.dart`: `refreshSession()` + `sessionExpired` flag. (BUT-315)
- [x] **A3. Fix non-atomic friend acceptance** — `lib/repositories/firebase/friends/friend_relationship_repository.dart` + `lib/services/unified/operations/friends_management_operations.dart`: `acceptFriendAtomically` single transaction. (BUT-310)

### Agent B: firebase-backend-security — Data Protection & GDPR

- [x] **B1. Fix SSRF DNS rebinding bypass** — `lib/services/import/fetchers/http_content_fetcher.dart`: post-DNS-resolve IP check + scheme validation + injectable DNS resolver. (BUT-325)
- [x] **B2. Fix basic import rate limiter** — `lib/services/import/import_manager.dart`: wired `ImportRateLimiter` for `checkLimit` + `recordUsage`. (BUT-326)
- [x] **B3. Fix Algolia indexing private recipes** — `lib/repositories/algolia/algolia_search_repository.dart`: personal → removeRecipe, `isPublic` from recipe.type, removed ingredients from search doc. (BUT-330)
- [x] **B4. Fix GDPR deletion false-success** — `lib/services/account/account_deletion/storage_deletion_operations.dart`: catch block returns `false`. (BUT-316)

### Agent C: debugger — Stability

- [x] **C1. Fix SocialModule eager dependency** — `lib/core/di/modules/social_module.dart` + `lib/services/social_recipe_service.dart`: lazy shopping service resolution via ServiceLocator.tryGet. (BUT-333)
- [x] **C2. Fix ConnectivityMonitoringService singleton crash** — `lib/services/connectivity_monitoring_service.dart`: removed manual singleton, simple constructor. (BUT-318)

### Post-Sprint

- [x] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests
- [ ] Commit, push, PR, merge
- [ ] Update Linear ticket states

---

## Archive: Sprint Household + Menu Voting (completed 2026-04-08)

### Part 1: Household Model + Allergen Aggregation

- [x] **1A. Add `isHousehold` to FriendCategory** (BUT-256)
- [x] **1B. Create HouseholdService** (BUT-256)
- [x] **1C. Wire MenuGenerator for household allergens** (BUT-256)
- [x] **1D. Add toggleHousehold operation** (BUT-256)
- [x] **1E. Register HouseholdService in DI** (BUT-256)
- [x] **1F. Household l10n strings** (BUT-256)

### Part 2: Menu Voting Backend

- [x] **2A-F. Menu voting model, repo, service, DI, l10n** (BUT-239)

### Part 3: ViewModels + UI

- [x] **3A-F. Household toggle, allergen toggle, voting VM, vote card, suggest-alternative sheet, realtime wiring** (BUT-256, BUT-239)

---

## Archive: Previous Sprints

- Bug Cleanup + Loading Polish (2026-04-07): BUT-292-296, BUT-244
- Share & Discover (2026-04-07): BUT-219, BUT-242, BUT-272, BUT-271
- Tech Debt + UX Polish (2026-04-07): BUT-289, BUT-288, BUT-253, BUT-218, BUT-212
- Smart Import + Menu Intelligence (2026-04-06): BUT-208, BUT-241, BUT-247, BUT-204, BUT-270
