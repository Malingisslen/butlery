# Sprint Backlog

## Follow-up session (2026-06-22): fix BUT-840 + redo BUT-1339/1340 view tests
- [x] **BUT-431 / BUT-1167** In-Review sign-off received from Malin → BUT-431 Done; BUT-1167 open only for AI1 (your deploy-verify).
- [x] **BUT-840** — NOT an Algolia problem. Algolia is OFF (feature flag); live search uses FirestoreSearchRepository, which read the bare `users/{uid}` doc (no displayName) filtered by non-existent `isPublic`. Fixed: query `public_profiles` (`isSearchable==true`, exclude `isHidden`), map publicRecipeCount/friendsCount. Makes user-search work AND fresh-on-rename, no Algolia key. 5/5 tests + firebase-security clean. (Algolia-write-on-rename remains future work when Algolia is enabled.)
- [x] **BUT-1339** — recipe view tests done RIGHT (run-to-green): LaggTillReceptView (6), PersonalTagsView (6), TagDetailView (5) = 17 green. Prior attempt failed because screens also pull OfflineService in build() + the fake VM missed maxUsageCount/getRuleMatchCount — fixed in test harness only.
- [x] **BUT-1340** — settings/legal view tests done RIGHT: TermsOfServiceView (3), SettingsHubView tiles (4), CollectionStatsView (3) = 10 green + EmailVerificationView (already shipped). Added minimal `@visibleForTesting` ctor seam to RecipeQueryViewModel; repaired a sibling test (settings_hub_food_tile) that a newer feature had broken. 32 view tests green together.
- Lesson reinforced: widget tests MUST be run, not just analyze-clean — DI resolution failures only surface at mount.

---


## Sprint: Tier-A autonomous backlog — batch 8 (view tests — mostly bounced) — 2026-06-21

### Batch 8 (view-layer widget tests — REALITY CHECK)
- [partial] **BUT-1340** only EmailVerificationView cleanly testable (shipped); 5 other screens need DI seams → Backlog + BUT-1353
- [bounced] **BUT-1339** no recipe screen cleanly widget-testable (all resolve VMs from ServiceLocator in build()); → Backlog + BUT-1353
- Lesson: view-layer widget tests are genuinely B-UI (classifier was right). They need `@visibleForTesting` ctor seams + a hardened widget harness, not a test-only pass. Deleted 5 runtime-failing test files rather than ship flaky tests.

---

## Sprint: Tier-A autonomous backlog — batch 7 (cold-start deferral) — 2026-06-21

### Batch 7 (Tier C → In Review)
- [x] **BUT-431** defer PerformanceModule.initialize side-effects + ContentStage ingredient-enrich Firestore round-trip to a post-frame callback (registration stays eager; MessagingModule untouched; admin path unaffected). Premise was stale (main.dart already 237 lines via BUT-530; heavy services already auth-scope-deferred). Boot e2e tests 22/1-skip/0-fail; both gates clean. → In Review (startup change — needs your cold-start smoke).

### Remaining: BUT-1149 (coverage floor) — left OPEN: documented multi-batch effort to reach 60%; bumping floor now would break CI.

---

## (archived) batch 6 (Cloud Functions: AI8 CI gate) — SHIPPED e1ac06cc3

Goal (session): finish the genuinely code-and-ship-now Tier-A tickets (per 2026-06-21 re-classification → `.claude/state/backlog-scan.json`). Reclassification corrected: BUT-840 is actually Tier-D (no server-side Algolia + needs admin key + deploy → flagged on ticket).

### Batch 6 (functions/src TypeScript)
- [x] **BUT-1167 AI8** prompt-changelog CI gate: pure detector + CLI + workflow + 10-case test (10/10). AI1 = live deploy verify (your action); AI6 → follow-up BUT-1352. `[Tier A slice]` → BUT-1167 to In Review (AI1 remains)
- [flagged] **BUT-840** Tier-D: needs Algolia admin key + algoliasearch dep + deploy → commented, stays Backlog

### Remaining A-CODE-NOW: BUT-431 (DI cold-start → Tier C/In Review), BUT-1149 (coverage floor — LAST)

---

## (archived) batch 5 (groups + engine tests) — SHIPPED e2ed4281c
Closed Done: BUT-1342, BUT-1343. Follow-up: BUT-1351.

---

## (archived) batch 4 (social + import VM tests) — SHIPPED 3edc46172
Closed Done: BUT-1341, BUT-1345.

---

## (archived) batch 3 (small test buckets) — SHIPPED 4db30718c
Closed Done: BUT-1346, BUT-1347, BUT-1344. Follow-up: BUT-1350.

---

## (archived) batch 2 (menu cross-week freshness) — SHIPPED f53db326c
Closed Done: BUT-1329, BUT-1330. Follow-up: BUT-1349.

## (archived) batch 1 (security/test cluster) — SHIPPED dd64b9461
Closed Done: BUT-1335, BUT-1334, BUT-1333, BUT-1337, BUT-1336. Follow-up: BUT-1348.

### Agent A: testing-specialist — recipe-list allergen safety (BUT-1335)
- [ ] **A1. Dedicated tests for allergen-free / dietary-safe recipe-list filter** `[Tier A]` (BUT-1335)
  - Acceptance: filter EXCLUDES recipe with tag coverage < 1.0 · EXCLUDES `needsRetagging` · EXCLUDES `tagResult == null` but KEEPS `createdBy == 'system'` seed · dietary-safe filter applies same gate · `untaggedExclusionMessage` surfaces when recipes hidden

### Agent B: testing-specialist — account-deletion client path (BUT-1334)
- [ ] **B1. Tests for AccountDeletionService client trigger path** `[Tier A]` (BUT-1334)
  - Acceptance: no-auth-user → `['No authenticated user']` result · `requiresReauth` when ID token > 5 min old · search-index + offline-cache cleanup runs before callable · notification-state reset + sign-out after successful cascade

### Agent C: testing-specialist — MFA service (BUT-1333)
- [ ] **C1. Tests for AuthMfaService enroll / unenroll / sign-in challenge** `[Tier A]` (BUT-1333)
  - Acceptance: enrollment path (session→verify→SMS→enroll) incl auto-verify · unenrollment · sign-in resolution incl `no-phone-factor` error · error-code mapping (invalid-phone-number, quota-exceeded, invalid-verification-code) + no-signed-in-user branches

### Agent D: imported-menu stub (BUT-1337)
- [ ] **D1. Finish or remove `MenuSocialManager.loadImportedMenuData` stub** `[Tier A]` (BUT-1337)
  - Acceptance: Step-0 determines live-vs-dead conclusively · if dead: stub + call sites + misleading UI removed, analyze clean · if live: data load implemented + test · no `return null` stub left behind

### Agent E: testing-specialist — receive-share + social extraction (BUT-1336)
- [ ] **E1. Tests for ContentDetectorService routing + SocialMediaExtractor** `[Tier A]` (BUT-1336)
  - Acceptance: ContentDetector classifies+routes each content type (social URL / recipe URL / recipe text / plain) · extraction-failure → retry/manual-copy fallback · Instagram + TikTok platform detection · success → extracted text+metadata · failure carries `reason`

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests
- [ ] Phase 2.7 fresh-context grade vs acceptance
- [ ] Commit, push
- [ ] Linear: Tier A → Done

---

## (archived) Sprint: backend-slice-drained — 2026-06-15 (iter-166)
Prior sprint concluded 0 honest backend picks; superseded by the Tier-A run above.
