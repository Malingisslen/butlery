# Sprint Backlog

## Sprint: wave-12 — bug/UX/correctness triple cluster — 2026-05-22 (Fr)

Theme: nine high-priority Bug-labelled / tech-debt tickets in three independent groups. Cohesion within groups; loose coupling between groups so agents can work in parallel without merge conflicts.

### Agent A — Import / Parse bug cluster (3 tickets, all `lib/viewmodels/import_*`)
- [ ] **A0. Step 0** — read `import_base_viewmodel.dart` + `photo_import_viewmodel.dart` + `storage_service.dart`; classify each ticket (fits / premise-gone / plan-stale).
- [ ] **A1. BUT-960** — add `.timeout(Duration(seconds: 45))` to recipe-parse CF call in `import_base_viewmodel.dart:56-76`. Friendly error string + retry surfacing. Match the OCR pattern at `ocr_extraction_service.dart:421`.
- [ ] **A2. BUT-924** — guard parse-failure state-wipe at `import_base_viewmodel.dart:349`. Preserve `parsedRecipe` if user has edited since last parse OR move clearing into an explicit retry flow. Surface error in dismissable banner.
- [ ] **A3. BUT-953** — fix heirloom photo upload orphan in `photo_import_viewmodel.dart:311-381`. Block recipe save on image-upload success (option a) — simpler than persistent queue (option b). No success toast unless image lands.
- [ ] **A4. Tests** — add unit tests for each change. Touch the existing test files in `test/unit/viewmodels/`.

### Agent B — Cascade / Undo UX cluster (3 tickets)
- [ ] **B0. Step 0** — read `recipe_detail_viewmodel.dart`, `recipe_delete_manager.dart`, `personal_tag_viewmodel.dart`, `personal_tag_crud_service.dart`, `weekly_menu_plan_service.dart`. Classify.
- [ ] **B1. BUT-927** — add 7-second snackbar undo to single-recipe-delete in `recipe_detail_viewmodel.dart:227`. Pattern from `recipe_delete_manager.dart:94`. Option (a) — same-day stopgap, not soft-delete.
- [ ] **B2. BUT-929** — confirmation modal showing affected recipe count before tag delete in `personal_tag_viewmodel.dart:252`. Soft-delete restore symmetry deferred.
- [ ] **B3. BUT-893** — on recipe delete, fan-out remove the recipe ID from weekly menu plan `entries[]`. Option (a) — `arrayRemove` against entries; cheaper than tombstone. Hook into existing recipe-delete path so it fires for both bulk + single delete.
- [ ] **B4. Tests** — undo timer behaviour, modal cascade preview count, menu cleanup on recipe delete.

### Agent C — Backend correctness cluster (3 tickets)
- [ ] **C0. Step 0** — read `base_firebase_repository.dart`, `fcm_service.dart`, existing CF integration test infra (`functions/src/__tests__/`).
- [ ] **C1. BUT-1003** — restructure `createBatch/updateBatch/deleteBatch` in `base_firebase_repository.dart` so `PermissionDeniedException` propagates (commit happens in an inner try/catch; permission check + throw outside). Tighten three test assertions in `base_firebase_repository_extra_test.dart` from `throwsException` → `throwsA(isA<PermissionDeniedException>())`.
- [ ] **C2. BUT-1006** — add `bindUserContext()` method to `FCMService` (Option A from ticket). Called unconditionally from `NotificationService.onInitialize()`. Re-binds `_consentService`, `_onMessageReceived`, `_onMessageOpenedApp`, resets `_pushPermissionsRequested`. Test re-login lifecycle.
- [ ] **C3. BUT-1009** — Step 0 verdict will decide: if `@firebase/rules-unit-testing` harness already exists, build per-step integration test for `runAccountDeletionWithDeps`. If harness setup is itself a sprint-size task, **defer with note** (do not force-fit).

### Pre-sprint pickup
- [x] tag_overrides_test.dart already staged — bundle into the sprint commit (clean test, 26 passing, fits the test-coverage commit pattern).

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests
- [ ] Tier-2 agent reviews on staged Dart diffs (code-reviewer + testing-specialist + firebase-backend-security where backend/repo files touched)
- [ ] File follow-ups as Linear tickets
- [ ] Commit + push
- [ ] Close Linear tickets to Done
- [ ] CI watcher

### Known risk notes
- BUT-1009 may rescope or defer pending harness audit (Step 0 verdict).
- All three groups land in the same commit — bundled wave commit, not separate per-ticket commits.

---

## Archived wave-11 (commits 7551c14c2 + bca2f5bc7) — 2026-05-22 (Fr)

wave-11 — BUT-788 server-side account-deletion. Shipped: new `requestAccountDeletion` CF (re-auth gate, 24-step cascade, audit logs), client wrapper reduced 430→190 lines, 4 deletion modules deleted (~1,050 LOC), tests green. Follow-ups filed: BUT-1009 (integration test, pulled into wave-12), BUT-1010 (App Check blocked on BUT-760), BUT-1011 (async polling for very-large accounts). BUT-788 closed in Linear.

## Archived wave-10 (commit 826dceed1) — 2026-05-22 (Fr)

wave-10 — BUT-782 FCMService static→instance + DI refactor. 660-line rewrite, 23 tests up from 19. Follow-ups: BUT-1006 (re-bind on re-login, pulled into wave-12), BUT-1007 (consent/token stream tests), BUT-1008 (composable MockFirebaseMessaging).

## Archived wave-9 (commits 55d49d993 + 602420b91) — 2026-05-22 (Fr)

wave-9 — LLM golden runners + repo test-coverage. Shipped BUT-888. Follow-ups: BUT-1003 (batch ops catch-swallow, pulled into wave-12), BUT-1004, BUT-1005.

## Archived wave-8 (commit 633595561) — 2026-05-22

wave-8 — BUT-784/886/882/887 shipped.

## Archived wave-7 (commit 5bd98f8e8 / 7ed82246c)

wave-7 — BUT-878/455/811/798 shipped.

## Archived wave-6 (commit 273152149)

wave-6 — BUT-876/802/452 shipped.

## Archived wave-5 (commit b66f5892f)

wave-5 — BUT-660/872/865/866/873 shipped.

## Archived wave-4 (commit 90d88cfca / b115d7519)

wave-3 follow-ups — BUT-868/869/870/871/867/776/864.

## Archived wave-3 (commit 8e54f68f2)

UI consolidation + CI + model integrity tests — BUT-861/579/801/841/825/823.
