# Sprint Backlog

## Sprint: Tier-A autonomous backlog — batch 6 (Cloud Functions: AI8 CI gate) — 2026-06-21

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
