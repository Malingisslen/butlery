# Sprint Backlog

## Sprint: Bug Stability — 2026-04-08

### Agent A: debugger — Build Blockers & Backend Stability

- [x] **A1. Fix ambiguous import in household_service** — `lib/core/base/base_service.dart`: removed orphaned abstract stubs causing conflicts. (BUT-308)
- [x] **A2. Fix hasActiveSubscription always returning false** — `lib/core/mixins/stream_management_mixin.dart`: flipped inverted condition + fixed tautological check. (BUT-320)
- [x] **A3. Fix FeatureFlagService hash instability + SearchModule timing** — FNV-1a hash, delegating proxy, fromUserId in deep links. (BUT-335)
- [x] **A4. Fix notifyListeners after dispose across ViewModels** — Added disposal guards to RecipeListVM, RecipeDetailVM, RealtimeMenuVM, OfflineService. (BUT-319)

### Agent B: debugger — Data Integrity

- [x] **B1. Fix shopping data integrity** — Toggle label inversion, atomic multi-remove, dedup, retry on _loadList. (BUT-336)
- [x] **B2. Fix tagging race conditions** — Batch deleteTag, snapshot pendingSyncIds, Completer-guarded init, createTag mutex. (BUT-331)

### Agent C: firebase-backend-security — GDPR Compliance

- [x] **C1. Fix GDPR export gaps** — Added 5 missing collections, truncation surfacing, consent cache clearing on logout. (BUT-317)
- [x] **C2. Fix data export broken on web platform** — Increased URL revocation delay from 0 to 10 seconds. (BUT-297)

### Post-Sprint Steps

- [x] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests
- [ ] Commit, push, PR, merge
- [ ] Update Linear ticket states

## Sprint: Hardening H2 — 2026-04-08

### Agent A: firebase-backend-security — GDPR + Security Tests

- [x] **A1. Fix data export web error handling** — `download_web.dart`: wrapped blob/anchor in try/catch. (BUT-297)
- [x] **A2. Fix security service test assertions** — `account_deletion_service_test.dart`, `data_export_service_test.dart`: fixed 3 failing assertions (audit ID format, static mock state, missing export section). (BUT-298)

### Agent B: debugger — Social Bugs Cluster

- [x] **B1. Add self-exposure guard in friend search** — `friends_management_operations.dart`: defensive removeWhere for current user after combining results. (BUT-313)
- [x] **B2. Fix silent error suppression in friend operations** — `friends_management_operations.dart`: refactored rejectFriendRequest, cancelFriendRequest, removeFriend to use executeServiceOperation(). (BUT-311)
- [x] **B3. Remove dead FriendsViewModel code** — `friends_viewmodel.dart`: removed unused _debounceTimer, simplified _onFriendsServiceChanged by removing Future.delayed wrapper. (BUT-312)

### Agent C: performance-optimizer — Performance + Resource Leaks

- [x] **C1. Cache recipe list getters** — `unified_recipe_service.dart`: added ??= cached fields for recipes/personalRecipes/collaborativeRecipes, invalidated in notifyListeners(). (BUT-332)
- [x] **C2. Fix import resource leaks** — `web_scraper.dart`: Completer-based cleanup race fix. `ocr_extraction_service.dart`: removed failure caching. (BUT-327)

### Agent D: flutter-developer — Cooking Mode UX

- [x] **D1. Fix cooking mode scroll, lifecycle, accessibility** — `cooking_mode_view.dart`: GlobalKeys + Scrollable.ensureVisible(), listener pattern instead of build-time callback, l10n semantic labels. (BUT-322)

### Post-Sprint Steps

- [x] Run `dart analyze --fatal-infos`
- [x] Run relevant unit tests (31/31 security, 42/42 friends VM)
- [ ] Commit, push, PR, merge
- [ ] Update Linear ticket states

---

## Archive: Sprint Security Hardening Part 2 (completed 2026-04-08)

- [x] 1A. Fix menu permission domain (BUT-329)
- [x] 1B. Fix shopping join permissions (BUT-329)
- [x] 2A. Wire clearCompleted (BUT-328)
- [x] 2C. Remove Settings/Members stubs (BUT-328)
- [x] 2D. Wire share actions (BUT-328)
- [x] 3A. Fix snackbar no-op (BUT-321)
- [x] 3B. Wire comment likes (BUT-321)

---

## Archive: Sprint Security Hardening (completed 2026-04-08)

- [x] A1. Fix auth route gaps (BUT-334)
- [x] A2. Add proactive token refresh (BUT-315)
- [x] A3. Fix non-atomic friend acceptance (BUT-310)
- [x] B1. Fix SSRF DNS rebinding bypass (BUT-325)
- [x] B2. Fix basic import rate limiter (BUT-326)
- [x] B3. Fix Algolia indexing private recipes (BUT-330)
- [x] B4. Fix GDPR deletion false-success (BUT-316)
- [x] C1. Fix SocialModule eager dependency (BUT-333)
- [x] C2. Fix ConnectivityMonitoringService singleton crash (BUT-318)

---

## Archive: Previous Sprints

- Household + Menu Voting (2026-04-08): BUT-256, BUT-239
- Bug Cleanup + Loading Polish (2026-04-07): BUT-292-296, BUT-244
- Share & Discover (2026-04-07): BUT-219, BUT-242, BUT-272, BUT-271
- Tech Debt + UX Polish (2026-04-07): BUT-289, BUT-288, BUT-253, BUT-218, BUT-212
- Smart Import + Menu Intelligence (2026-04-06): BUT-208, BUT-241, BUT-247, BUT-204, BUT-270
