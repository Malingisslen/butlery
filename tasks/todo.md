# Sprint Backlog

## Sprint: post-refactor testability + import-UX follow-ups — 2026-06-04 (iter-106)

Clean tree on main. Backlog = 120 Backlog issues (27 excluded: 6 EPIC, 7 launch-gated, 14 Tier-D ops).
Picked a tight Tier-A-heavy cluster freshly spun off overnight from the just-shipped BUT-1154
(import decomposition) + BUT-1190 (comments-repo facade) refactors — testability debt the refactors
unlocked — plus one coherent Tier-B import-UX follow-up (BUT-1198).

### Agent A: import-testability — close the test-gaps BUT-1154 unlocked
- [x] **A1. BUT-1195** `[Tier A]` — 7 pure cases for `OcrErrorMessageBuilder` (empty-list else branch,
      recovery line, record fields). Green.
- [x] **A2. BUT-1196** `[Tier A]` — 5 widget cases for `ConfidenceIndicator` (percent text + 3 buckets). Green.
- [x] **A3. BUT-1197** `[Tier A]` — Step-0: VM already constructible (connectivity uses `tryGet`);
      real gap was widget-mount. Added `test/views/smart_import_view_smoke_test.dart` proving
      `SmartImportView` mounts via ImportManager DI bridge + clipboard stub. No prod change. Green.

### Agent B: repo + recipe-list test/tech-debt
- [x] **B1. BUT-1194** `[Tier A]` — 4 cases for `getCommentLikers` (desc order, limit, default, empty).
      Sibling `firebase_comments_repository_likers_test.dart`, FakeFirebaseFirestore. Green.
- [x] **B2. BUT-1028** `[Tier A]` — scroll-offset persistence via ambient `PrimaryScrollController`
      (covers grid+list, no shared-widget edits) + `PersistenceService.{get,set}RecipeListScrollOffset`,
      300ms debounce, bounded post-frame restore, dispose-flush. 3 persistence tests green. (BUT-1015 follow-up)

### Agent C: import-UX (Tier B — parks In Review)
- [x] **C1. BUT-1198** `[Tier B]` — non-blocking MaterialBanner at import success (SmartImportView
      choke point) when recipe CONTAINS an untracked allergen; CTA → `Routes.settingsAllergens`.
      Pure `AllergenMismatch` detector (6 tests) + `AllergenSetupBanner` + l10n (sv/en) + HTML preview.
      Reuses Phase-1 tags (no LLM). Photo-import surface → follow-up BUT-1200. → In Review.

### Needs you (Tier D — flagged, not worked) — carried from iter-105
- BUT-1187 — deployed & live but runtime-unverified: needs ONE real recipe import from your phone.
- onRecipeDeleted 1st→2nd-gen deploy blocker — still owed a ticket.

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit/widget tests
- [ ] Commit, push
- [ ] Linear: Done for Tier A (1194/1195/1196/1197/1028); In Review + notify for Tier B (1198)

---

## ARCHIVED — iter-105: post-BUT-1193 CI reconciliation + contained refactors (2026-06-04)

Reconciled CI tickets vs merged BUT-1193 (#179): BUT-1182 Done (premise-gone), BUT-1192 re-scoped P3→P4,
BUT-1149 left open (coverage ~55%, can't raise floor yet), BUT-397 closed Duplicate. BUT-1190
facade-extracted comment like-ops → repo 464 lines. BUT-520 de-scoped (self-IDs as EPIC, needs Malin).

## ARCHIVED — BUT-581 sprint (complete, shipped a9bb611d7)

`?? '' → .orEmpty()` migration: chunks 1–8 swept + architecture-test guard added. BUT-581 Done.
