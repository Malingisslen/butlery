# Sprint Backlog

## Sprint: Tier-A autonomous backlog — batch 2 (menu cross-week freshness) — 2026-06-21

Goal (session): finish all 50 Tier-A tickets across successive batches.

### Agent F: menu_generator recently-used plumbing (BUT-1329 + BUT-1330)
- [ ] **F1. Thread recentlyUsedRecipeIds into regenerateMenuSection** `[Tier A]` (BUT-1329)
  - Acceptance: regenerateMenuSection reuses `_recentlyUsedRecipeIds()` and passes it into `generateMenuFromPrompt` · a single-section re-roll down-weights last-week recipes the same as full generation · existing menu_service/menu_generator tests stay green
- [ ] **F2. Unit-test `_recentlyUsedRecipeIds()` plumbing** `[Tier A]` (BUT-1330)
  - Acceptance: null/unregistered service → empty set · read throws → empty set AND generation still proceeds · correct this-week+last-week docs requested under a fixed clock

### Post-Sprint: analyze · test · grade · commit · push · Done

---

## (archived) Sprint: Tier-A batch 1 (security/test cluster) — 2026-06-21 — SHIPPED dd64b9461
Closed Done: BUT-1335, BUT-1334, BUT-1333, BUT-1337, BUT-1336. Follow-up filed: BUT-1348.

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
