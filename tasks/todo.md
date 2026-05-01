# Sprint Backlog

## Sprint: GDPR tripwires red→green + onboarding follow-ups + simplify-pass cleanup — 2026-05-01

Theme: close the loop on last sprint's deliberately-deferred residuals. B1's tripwires (BUT-746/747/748) become the close-out: flip them from "documented bug" → "fixed + test now passes the right way". C1's deferred follow-ups (BUT-743/744/745) drain in the same cycle. Plus the two simplify-pass items (BUT-740/741) that touch the same `FirebaseDataExportRepository` file as BUT-748, so doing them together avoids a second pass over the same file. **3 agents, 8 tasks, isolated file trees** (`lib/services/account/` + `lib/repositories/{block,data_export}/` · `lib/views/onboarding/` + `lib/viewmodels/onboarding_viewmodel.dart` + `lib/main.dart` · `functions/src/migrations/backfill-recipe-comments-denorm.ts`).

Prior sprint (`b121ed0a2`) shipped — analytics retention cohorts (BUT-605), A/B rails (BUT-657), GDPR audit-log retention CF (BUT-665), account-deletion residual integrity tests (BUT-671 — produced the tripwires this sprint closes), onboarding resume (BUT-675 — produced the follow-ups this sprint closes), tech-debt cluster (BUT-693/707/742). **No remaining carry-overs.** Backlog has zero Urgent. **BUT-498 / BUT-697** stay In Progress per standing skip-direction.

### Agent A: firebase-backend-security — GDPR tripwires + DataExportRepository simplify

- [x] **A1. Scrub `menus.sharedToUserIds` on inbound-share deletion** — `lib/services/account/content_deletion_operations.dart` (`deleteMenus` method). When deleting a user, also `arrayRemove(deletedUid)` from `menus.sharedToUserIds` on every menu where they're a recipient. Mirror the symmetric pattern from shopping-list cascade. Flip the B1 tripwire assertion in `account_deletion_residual_test.dart` red → green. (BUT-747)
- [x] **A2. Delete top-level menus orphans (`sharedByUserId == deletedUid`)** — same file. Add a top-level `collectionGroup('menus').where('sharedByUserId', '==', uid)` cleanup pass (or `.collection('menus')` if not subcollection-only — verify path first). Flip B1 tripwire assertion red → green. (BUT-746)
- [x] **A3. Reconcile `blocks` field-name inconsistency** — `lib/repositories/firebase_data_export_repository.dart` (`exportIncomingBlocks` method) uses `blockedUserId` while `FirebaseBlockRepository` writes/queries `blockedId`. Decide canonical name (likely `blockedId` since that's the writer + queryer used in production), update the export query to match. Verify zero incoming-blocks regression with a test against fake-Firestore. Flip B1 tripwire assertion red → green. (BUT-748) (Bug)
- [x] **A4. Collapse 23 export-method boilerplate in `FirebaseDataExportRepository`** — `lib/repositories/firebase_data_export_repository.dart`. Extract a private `_exportCollection(String path, String ownerField, {Query Function(Query)? extraFilter})` helper; collapse the 16+ near-identical methods that just `validateOwnership` + `where(ownerField == uid).get()` + map. Keep methods with bespoke shape (menus, conversations, messages) as-is. ~150 line net reduction expected. (BUT-740)

### Agent B: flutter-developer — onboarding follow-up cluster

- [x] **B1. Reconcile OnboardingViewModel DI factory direction** — `lib/services/di/personal_module.dart` (or wherever the OnboardingViewModel factory lives) + production constructor call-sites. BUT-675 added `progressService` + `userId` + `initialPage` to the constructor; the factory + call-site picture is half-migrated. Pick one direction: either factory always builds with `progressService.resolveResumePage()`, or all call-sites pass `initialPage` explicitly. Document the decision in the docstring. (BUT-744)
- [x] **B2. Replace `FirebaseFirestore.instance` in onboarding with `FirestoreRepository` injection** — two new call-sites added by BUT-675 violate the project rule (`CLAUDE.md` § Code Style — "Never use FirebaseFirestore.instance directly"). Inject `FirestoreRepository` through DI. Verify with grep `FirebaseFirestore.instance` in `lib/services/onboarding/` returns 0. (BUT-743)
- [x] **B3. Remove blank+spinner flicker in `_OnboardingResumeGate`** — `lib/main.dart:1180`. Currently first frame on cold launch shows `Scaffold(body: Center(CircularProgressIndicator()))` for the duration of the Firestore round-trip. Either (a) hold the splash screen until resolved, or (b) render the page-0 onboarding instantly and quietly jump if resume fires. Option (b) is preferred — page 0 is correct ~95% of the time (new users). (BUT-745) (Bug)

### Agent C: cloud-functions-specialist — backfill perf

- [x] **C1. Parallelize `backfill-recipe-comments-denorm` migration loop** — `functions/src/migrations/backfill-recipe-comments-denorm.ts`. Currently sequential per-batch. Use `Promise.all` over batches with a concurrency cap (e.g. 5 in flight). Preserve `__name__` cursor + idempotent skip-if-fields-present + 10k per-invocation ceiling. Expected ~10× speedup. Update the existing test to assert concurrent behavior + concurrency-limit boundary case. (BUT-741)

### Post-Sprint Steps

- [ ] `dart analyze --fatal-infos`
- [ ] `flutter test test/unit/services/account/account_deletion_residual_test.dart` (verify tripwires now green by their own assertions, not by the old "documents the bug" wording — update test docstring to "verifies the fix")
- [ ] `cd functions && npm test` (C1 parallelized backfill)
- [ ] Commit, push to main
- [ ] Update Linear: BUT-740/741/743/744/745/746/747/748 → Done

### Continued blockers (NOT in scope per memory)

- BUT-415 / BUT-714 — store/play submission deferred (Apple Dev enrollment + Universal Links)
- BUT-498 / BUT-697 — explicitly skipped per standing direction

---

## What this means in plain language

- **Three real privacy bugs get fixed.** Last sprint discovered that account deletion was leaving small bits of data behind in three places (menu shares, menu orphans, the blocked-users list). We documented them rather than fixing them. Now we fix them. Important for GDPR.
- **Three small onboarding rough edges go away.** The cold-launch flicker (blank screen → spinner → first onboarding page), and two internal cleanups from the resume-onboarding work that we deliberately deferred.
- **One backend cleanup + one perf win.** A migration script becomes ~10× faster. A repository file with 23 near-identical copy-pasted methods becomes shorter and easier to read.
- **No new user-facing features.** This is a close-out sprint — finishing what last sprint deliberately left as "fix in next cycle" rather than starting anything new.
- **Risk: low.** Each fix has a tripwire test that already exists from last sprint — they tell us immediately if we broke or fixed the behavior. No UI changes, no schema changes, no Firestore-rules changes.
