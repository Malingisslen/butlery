# Sprint Backlog

## Sprint: Security Hardening Part 2 — 2026-04-08

### 1. Permissions (BUT-329)

- [x] **1A. Fix menu permission domain** — `realtime_participant_manager.dart`: canEditRecipe→canEditMenu (3 one-liners). (BUT-329)
- [x] **1B. Fix shopping join permissions** — `shared_shopping_list.dart` + `social_shopping_coordinator.dart`: added shoppingListId field, wired addMember. (BUT-329)

### 2. Stub Cleanup (BUT-328)

- [x] **2A. Wire clearCompleted** — `collaborative_shopping_viewmodel.dart` + `collaborative_shopping_actions.dart`: VM delegate + real service call. (BUT-328)
- [x] **2C. Remove Settings/Members stubs** — `collaborative_shopping_actions.dart`: removed menu items + methods. (BUT-328)
- [x] **2D. Wire share actions** — `collaborative_shopping_actions.dart`: Clipboard, SharePlus, mailto with error handling. (BUT-328)

### 3. Recipe Detail Fixes (BUT-321)

- [x] **3A. Fix snackbar no-op** — 4 handler files + `recipe_detail_actions.dart`: handlers call SnackBarUtils directly. (BUT-321)
- [x] **3B. Wire comment likes** — `social_engagement_manager.dart` + `social_recipe_viewmodel.dart`: CommentLikesSystem persistence + optimistic rollback. (BUT-321)

### Post-Sprint

- [x] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests
- [x] Commit, push
- [ ] Update Linear ticket states

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
