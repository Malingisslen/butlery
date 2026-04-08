# Sprint Backlog

## Sprint: Social & Stability Blitz — 2026-04-08

### Agent A: debugger — Social Reliability

- [x] **A1. Fix group stub features** — Auto-navigate after group creation, shopping list dialog init, target selection dialog. (BUT-345)
- [x] **A2. Fix FriendProfileView dead ends** — Added bio section, public recipes button, proper navigation. (BUT-341)
- [x] **A3. Fix optimistic updates without rollback** — Moved Firebase calls before local state in reject/cancel/remove operations. (BUT-314)
- [x] **A4. Fix recipe rating/comment data integrity** — Synced denormalized rating fields, removed dead code. (BUT-323)

### Agent B: debugger — Import & Recipe Bugs

- [x] **B1. Fix clipboard URL detection + UIModule crash** — Added `hasStrings()` guard, `mounted` check, `allowReassignment` for hot restart. (BUT-337)
- [x] **B2. Fix tablet personal tags + ConnectionMonitor** — Responsive layout via `LayoutComponents.valueFor`, fixed `statusConnected` copy-paste error, cache invalidation by tag hash. (BUT-324)

### Agent C: flutter-developer — Dependency Maintenance

- [x] **C1. Update discontinued deps** — `image_cropper` ^12.0.0, `freerasp` ^7.5.1. Blocked: drift/csv/sqlite3/archive/build_runner need SDK bump. (BUT-300)
- [x] **C2. Update major deps** — `flutter_onnxruntime` ^1.6.4. Blocked: `file_picker` v11 has breaking API changes. (BUT-301)

### Post-Sprint Steps
- [x] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests
- [ ] Commit, push, PR, merge
- [ ] Update Linear ticket states

---

## Sprint: Tech Debt Consolidation — 2026-04-08

### Agent A: flutter-developer — Refactor + Performance

- [x] **A1. Refactor RecipeImageManager** — Delegated XFile ops to XFileUploadHandler, removed ~100 lines of duplicated upload/status logic. (BUT-303)
- [x] **A2. Optimize avatar compression** — Added optional dimension params to pickImage(), avatar now uses 400x400/85% instead of 2400x2400/90%. (BUT-306)
- [x] **A3. Fix addUploadedImageUrl max-image guard** — Added missing canAddMoreImages check (production bug caught by tests). (BUT-303)

### Agent B: debugger — Test Fixes

- [x] **B1. Fix recipe_image_manager_test** — 0/58 → 57/57: added MockImageUploadService, fixed mock wiring, error string expectations, notification debouncing, FakeXFile.length(). (BUT-303)
- [x] **B2. Fix user_profile_viewmodel_test** — Updated pickImage mock stubs for new optional params. 48/48 passing. (BUT-306)

### Agent C: testing-specialist — Test Coverage

- [x] **C1. Add tests for 8 priority untested VMs** — 127 tests total: account_security (24), profile (21), recipe_delete_manager (17), cooking_mode (22), recipe_selection_manager (9), menu_voting (18), shopping_permission_manager (8), public_profile (8). (BUT-299)

### Post-Sprint Steps

- [x] Run `dart analyze --fatal-infos`
- [x] Run relevant unit tests (232 tests passing: 127 new + 105 fixed)
- [ ] Commit, push, PR, merge
- [x] Update Linear ticket states (BUT-303, BUT-306, BUT-299 → Done, BUT-265 → Duplicate)

---

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
