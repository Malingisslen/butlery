# Sprint Backlog

## Sprint: Test Hardening Close-Out (BUT-387 Final Phase) — 2026-04-17

### Agent A: testing-specialist — User-journey & Integration Coverage

- [x] **A1. Write 6 user-journey integration tests** — `test/views/` using `allergen_preferences_view_test.dart` template: onboarding → first recipe, menu gen → calendar, pantry → "laga med vad jag har", shopping list collab check-off, recipe edit → detail refresh, shared list reply. (BUT-390)
- [x] **A2. Unskip 26 @Skip('BUT-387 Phase 7') integration tests** — migrate each to `test/test_support/emulator_lane.dart`; keep `@Skip` only for fixtures that genuinely can't run against emulator. (BUT-391)

### Agent B: firebase-backend-security — CI Hard Gates

- [x] **B1. Hard local coverage floor + per-area gates** — `.github/workflows/`: add bash `exit 1` if filtered coverage <60%; per-area lines for `lib/repositories/` (≥70%) and `lib/services/` (≥65%). (BUT-392)

### Agent C: flutter-developer — Test Infrastructure + Bug Fixes

- [x] **C1. Rename MockPermissionService → FakePermissionService** — `test/test_support/fake_permission_service.dart` + 34 call sites, match Phase 3 Fake-style naming. (BUT-388)
- [x] **C2. Fix Flutter web base URL drops navigation shell** — `lib/main.dart`: add `usePathUrlStrategy()`; verify `/` and `/#/` both render main menu. (BUT-374)
- [x] **C3. Replace manual Timer debounce with executeDebounced** — `lib/viewmodels/ingredient_search_viewmodel.dart`, `lib/viewmodels/pantry/pantry_viewmodel.dart`, `lib/viewmodels/friends/friends_search_manager.dart`: delete Timer + isDisposed guards, call `executeDebounced()`. (BUT-385)

### Post-Sprint Steps

- [x] Run `dart analyze --fatal-infos` — clean
- [x] Run `flutter test test/views/` — 21/21 green; targeted VM tests pass
- [ ] Verify CI coverage gate fires on intentional drop (verifiable only once CI runs)
- [ ] Commit, push to main
- [x] Update Linear: BUT-390, BUT-391, BUT-392, BUT-388, BUT-385, BUT-374 → Done

---

## What this means in plain language

- The big test-infrastructure rescue that's dominated the last two weeks finally pays off: 6 "real user journeys" get automated tests — onboarding, menu generation, pantry search, shopping collab, recipe editing, social reply — so the next UI change can't silently break them.
- 26 tests that were parked behind a "skip — needs emulator" flag come back online. The infrastructure for that shipped last week; now we use it.
- CI gets a hard "fail the build if coverage drops below X%" rule, per area. Today the gate is silent if the Codecov token hiccups — now it's local and unskippable.
- The "blank screen when you open the web app without the `#`" bug gets fixed.
- Three screens with identical duplicated debounce code collapse into one helper.
- Risk: Low. All test/infra work; the only user-facing change is the web routing fix.

---

## Archive: Sprint Ingredient Search — "Sök med ingredienser" — 2026-04-14

**Plan file:** `C:\Users\malla\.claude\plans\robust-toasting-kite.md`

### Agent A: flutter-developer — Service Layer

- [x] **A1. Create `IngredientMatchService`** — `lib/services/ingredient_match_service.dart`: set-intersection matching with `IngredientMatchResult` model. (BUT-205)
- [x] **A2. Add lazy in-memory normalization** — `matchRecipesWithNormalization()` handles null `ingredientsNormalized` via `IngredientLookupService.lookupFromRaw()`. (BUT-205)
- [x] **A3. Refactor PantryService to delegate** — `getMatchingRecipes` now calls `IngredientMatchService.matchRecipes()`. (BUT-205)
- [x] **A4. DI registration** — `IngredientMatchService` registered in `PantryModule.configureUserScope`. (BUT-205)

### Agent B: flutter-developer — ViewModel

- [x] **B1. Create `IngredientSearchViewModel`** — chips, debounced autocomplete, match results, missing ingredient name resolution. (BUT-205)
- [x] **B2. Register ViewModel in DI** — factory in `UIModule`, same pattern as `PantryViewModel`. (BUT-205)

### Agent C: flutter-developer — View + Widgets + Navigation

- [x] **C1. Create `IngredientSearchView`** — full-screen view with autocomplete, chips, results using `ContentCard` + `matchPercent`. (BUT-205)
- [x] **C2. Create `IngredientChipInput` widget** — autocomplete overlay + square removable chips. (BUT-205)
- [x] **C3. Route + entry point** — `/ingredient-search` route, "Med ingredienser" QuickFilterOption chip in recipe list. (BUT-205)
- [x] **C4. Localization** — 11 new keys in both `app_sv.arb` and `app_en.arb`. (BUT-205)

### Agent D: testing-specialist — Tests

- [x] **D1. `IngredientMatchService` tests** — 11 tests: empty set, full/partial match, sorting, null/empty normalized, lazy normalization, caching, name resolution. (BUT-205)
- [x] **D2. `IngredientSearchViewModel` tests** — 10 tests: add/remove/clear, debounced autocomplete, filtering, performSearch, loading states. (BUT-205)
- [x] **D3. PantryService regression** — 5 tests pass after delegation refactor. (BUT-205)

### Post-Sprint Steps

- [x] Run `dart analyze --fatal-infos` — 0 issues
- [x] All 26 tests pass (11 + 10 + 5)
- [x] Commit, push to main — `23231073b`

---

## Archive: Sprint Stability & Permissions — 2026-04-14

**Plan file:** `C:\Users\malla\.claude\plans\spicy-stirring-token.md`

### Agent A: firebase-backend-security — Firestore Permissions

- [x] **A1. Fix 3 permission-denied errors on startup** — `firestore.rules`: added rules for `category_preferences` and `list_category_orders` subcollections. (BUT-379)
- [x] **A2. Fix recipe comments permission-denied** — `firestore.rules`: added counter update rule for `replyCount`/`likesCount`, aligned text limit to 2000. (BUT-381)

### Agent B: debugger — Menu & Import Bugs

- [x] **B1. Investigate menu generator returning fewer recipes than requested** — code correct, data mismatch (recipes stored as Middag not Lunch). Added diagnostic logging. (BUT-383)
- [x] **B2. Fix archive import adding recipes twice in UI** — race condition: dedup check before `recipes.add()` in PersonalRecipeCrud. (BUT-373)

### Agent C: flutter-developer — UI Fixes

- [x] **C1. Fix RenderFlex overflow in MinaReceptView** — header in Flexible+SingleChildScrollView, Expanded recipe list takes remainder. (BUT-380)
- [x] **C2. Add navigation shell to social routes** — SharedWithMeView + SharedShoppingListsView now use LayoutComponents.mainMenu(). (BUT-372)

### Agent D: performance-optimizer — Startup Performance

- [x] **D1. Eliminate 3x redundant recipe sync on startup** — dedup guard in startFirebaseSync + _initializing flag skips redundant auth handler during init. 21→7 events. (BUT-382)

---

## Archive: Sprint Menu System Deepening — 2026-04-13

- [x] CF1-CF2: Chrome E2E, canonical-tag check
- [x] A1-A3: BUT-360 MVVM fix, refine prompt wiring, dead code removal
- [x] B1-B8: Firestore lexicon overlay (BUT-370)
- [x] C1-C3: Lexicon + ViewModel tests (14/14 pass)

---

## Archive: Sprint Veckomeny Constraint Parser — 2026-04-11

- [x] A1-A4: Models + Lexicon scaffold (BUT-359)
- [x] B1-B4: Parser engine + 80+ tests (BUT-359)
- [x] C1-C4: MenuService integration + day pins (BUT-359)
- [x] D1-D4: ParsedExtractionChips UI + l10n (BUT-359)

---

## Archive: Sprint Calendar Weekly Menu — Phase 1 — 2026-04-11

- [x] S0–S10: HTML preview, WeeklyMenuPlan model + repo + service + DI, ViewModel, CalendarWeeklyMenuWidget with all UI states, drag-and-drop, Lista/Kalender toggle + auto-distribute, GDPR deletion + export, l10n (BUT-211)

---

## Archive: Sprint Skafferiet (Pantry) — 2026-04-10

- [x] A1-A3, B1, C1-C3, D1: Pantry model/repo/service/DI/VM, PantryView, "Laga med vad jag har" filter, navigation, GDPR/l10n/tests (BUT-349, BUT-205) — PR #143

---

## Archive: Sprint Social Activity Feed — Phase 1 (completed 2026-04-10)

- [x] S1-S10: ActivityEvent model, repository, service, DI, ViewModel, FeedTab UI, tab integration, emission points, GDPR, l10n (BUT-339)

---

## Archive: Sprint Consent Hardening (completed 2026-04-10)

- [x] A1: Consent change callback (BUT-356)
- [x] A2: FCM mid-session re-enable (BUT-356)
- [x] B1: ConsentService.checkSafely tests (BUT-357)

---

## Archive: Sprint Insights & Engagement (completed 2026-04-10)

- [x] A1: Cooking photos (BUT-338)
- [x] A2: Tag-based collection insights (BUT-350)
- [x] B1: Tag analytics heat map (BUT-223)
- [x] C1: Allergen EU FIC audit (BUT-354)
- [x] C2: Golden tests + coverage gates (BUT-214)

---

## Archive: Sprint Social Polish & Tech Debt (completed 2026-04-09)

- [x] A1: Fix share dialog dead end (BUT-342)
- [x] A2: Add reply shortcut on shared recipe cards (BUT-343)
- [x] A3: Improve comment engagement (BUT-305)
- [x] B1: Add search history + Algolia highlights (BUT-304)
- [x] B2: Handcraft warm dark color scheme (BUT-346)
- [x] C1: Accept or refactor 9 files exceeding 500-line limit (BUT-302)

---

## Archive: Previous Sprints

- Feature & Polish (2026-04-09): BUT-348, BUT-355, BUT-352, BUT-353
- Social & Stability Blitz (2026-04-08): BUT-345, BUT-341, BUT-314, BUT-323, BUT-337, BUT-324, BUT-300, BUT-301
- Tech Debt Consolidation (2026-04-08): BUT-303, BUT-306, BUT-299
- Bug Stability + Hardening H2 (2026-04-08): BUT-308, BUT-320, BUT-335, BUT-319, BUT-336, BUT-331, BUT-317, BUT-297, BUT-313, BUT-311, BUT-312, BUT-332, BUT-327
- Security Hardening (2026-04-08): BUT-334, BUT-315, BUT-310, BUT-325, BUT-326, BUT-330, BUT-316, BUT-333, BUT-318, BUT-329, BUT-328, BUT-321
- Household + Menu Voting (2026-04-08): BUT-256, BUT-239
- Bug Cleanup + Loading Polish (2026-04-07): BUT-292-296, BUT-244
- Share & Discover (2026-04-07): BUT-219, BUT-242, BUT-272, BUT-271
- Tech Debt + UX Polish (2026-04-07): BUT-289, BUT-288, BUT-253, BUT-218, BUT-212
- Smart Import + Menu Intelligence (2026-04-06): BUT-208, BUT-241, BUT-247, BUT-204, BUT-270
