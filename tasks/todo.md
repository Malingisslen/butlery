# Sprint Backlog

## Sprint: Shared Menu Decisions — 2026-04-18

**Plan file:** `C:\Users\malla\.claude\plans\without-touching-anything-just-piped-pearl.md`

Theme: pivot from test-infra to user-facing features. Group meal voting + split-store shopping + closing the BUT-211 test gap. MVVM discipline, square design, theme tokens only — see plan file for the full design + security + edge-case coverage.

### Agent A: flutter-developer — BUT-340 Group meal voting (MVP)

MVP scope: extend poll metadata to carry recipe references; auto-add winner to **creator's** shared plan via `shareMenuWithGroup`. Group-scoped `WeeklyMenuPlan` is a follow-up ticket.

- [x] **A1. Extend `PollOption` with recipe metadata** — `lib/models/messaging/poll.dart`: add nullable `recipeId`, `recipeImageUrl`, `recipePortions`. Safe-map serialization. Backward compatible. (BUT-340)
- [x] **A2. "Vad ska vi äta?" entry point** — `lib/views/social/group_detail_view.dart`: new action routed through `SocialGroupDetailViewModel`, calls `MenuGenerator.availableRecipes` for household-filtered suggestions, opens adapted `poll_creation_dialog.dart` with optional `List<Recipe> recipeOptions` param. (BUT-340)
- [x] **A3. Recipe-aware poll rendering** — `lib/widgets/messaging/poll_message_widget.dart`: when `option.recipeId != null`, render thumbnail + title + portions/time metadata above vote bar. Tap → recipe detail. Plain-text polls unchanged. (BUT-340)
- [x] **A4. Auto-resolution on poll close** — `lib/services/messaging_service.dart` `closePoll()`: when winning option has `recipeId`, append to creator's current-week plan via `WeeklyMenuPlanService` (today-anchored next empty slot), reshare via `social_menu_operations.shareMenuWithGroup`. Wrap in Firestore transaction to avoid double-fire race. (BUT-340)
- [x] **A5. Swedish l10n** — `ask_what_to_eat`, `pick_recipes_to_vote`, `winner_added_to_menu`, empty-state "Inga recept att rösta om". Both `app_sv.arb` + `app_en.arb`. (BUT-340)
- [x] **A6. Tests** — `PollOption` round-trip with new fields; `closePoll` auto-resolution path (mocked plan service + menu ops); recipe-aware poll widget render; empty-recipes state. File follow-up: "group-scoped `WeeklyMenuPlan` — BUT-340 f/u". (BUT-340)

### Agent B: flutter-developer — BUT-238 Split-store shopping

- [x] **B1. Add `assignedToUserId` field** — `lib/models/unified/unified_shopping_item.dart`: nullable `assignedToUserId`, `assignedToDisplayName`, `assignedAt`. `assign()` / `unassign()` helpers update `lastModifiedBy*`. Safe-map serialization. No migration needed (nullable). Update Firestore rules for shopping-items subcollection. (BUT-238)
- [x] **B2. "Tar jag / Lämna tillbaka" action** — `lib/views/unified_shopping/widgets/shopping_item_tiles.dart` + `lib/views/social/collaborative_shopping/collaborative_shopping_items.dart`: swipe-right on mobile, tap-to-claim on web, all routed through `CollaborativeShoppingViewModel`. Assigned items show avatar badge; `assignedToUserId == currentUserId` items promoted to "Min del" section. Firestore `update` (atomic), not read-modify-write. (BUT-238)
- [x] **B3. `ShoppingPresenceModule`** — mirror `lib/services/unified/operations/realtime_recipe/presence_tracking_module.dart`. New module extends same base class, registered as interface in **UnifiedShoppingModule** DI (lazy singleton). 30s TTL heartbeat, per-list (not per-item). Header widget shows "Anna handlar nu" + greendot indicator. (BUT-238)
- [x] **B4. Zone-grouped toggle** — `collaborative_shopping_items.dart`: `[Alla] [Min del] [Efter zon]` toggle. Zone view groups by `ShoppingCategory.defaultStoreOrder`, then by assignee within each zone. (BUT-238)
- [x] **B5. GDPR paths** — verify new fields flow through `content_export_manager.exportShoppingLists()` (items exported as-is); on account deletion, scrub `assignedToUserId` from items on other users' lists (`content_deletion_operations`). Follow the `purchasedByUserId` scrub pattern; add if missing. (BUT-238)
- [x] **B6. Swedish l10n** — `tar_jag`, `lamna_tillbaka`, `min_del`, `handlar_nu`, `efter_zon`, `anna_tog_den_snackbar`. `app_sv.arb` + `app_en.arb`. (BUT-238)
- [x] **B7. Tests** — model round-trip, `ShoppingPresenceModule` unit test (mocked FakeFirebaseFirestore), widget test for "Min del" grouping + claim/unclaim + presence indicator, permission gate test (only `edit`/`admin` may assign), simultaneous-claim resolution test. (BUT-238)

### Agent C: testing-specialist — BUT-361 Calendar weekly menu test gap

Goal: ≥80% line coverage on the three wrappers. The VM test exists (74 lines) — **expand**, don't recreate. Ticket specifies exact behaviors to test; follow them exactly.

- [x] **C1. Repository tests** — new file `test/integration/firebase/repositories/weekly_menu_plan_repository_test.dart`. Template: `base_firebase_repository_integration_test.dart`. Cover: deterministic `userId_YYYY-WWW` doc ID + upsert-no-duplicate, `fetchForWeek` null on missing, `deleteAllByUser` batches 600 docs into ≤500-op chunks via `batchDeleteDocs`, owner-prefix range returns only target user, cross-user permission rejection. (BUT-361)
- [x] **C2. Expand ViewModel tests** — extend `test/unit/viewmodels/menu/weekly_menu_plan_viewmodel_test.dart`. Cover: `loadWeek` short-circuits when target week already loaded (no extra repo call), `applyGeneratedMenu` `_applyInFlight` guard blocks concurrent calls, `moveEntry` self-drop (`identical(updated, current)`) skips notify + save, `removeEntry` unknown id is no-op, `clearWeek` short-circuits on empty plan + empty overflow, `assignFromOverflow` prunes overflow after successful assign. Plus `previousWeek`/`nextWeek` boundary arithmetic. (BUT-361)
- [x] **C3. Widget smoke test** — new file `test/widget/menu/calendar_weekly_menu_widget_test.dart`. Template: `base_widget_test.dart` + Mocktail `MockWeeklyMenuPlanViewModel`. Cover: empty state renders `StateWidget.empty` + arrow-up hint, populated week renders 7 rows × 3 columns, tap empty slot → recipe dialog, drag-drop assigned cell → empty target triggers `moveEntry`, overflow chips render when `vm.overflow.isNotEmpty`. One golden via `golden_helper.butleryGolden(...)` for the populated-with-overflow state. (BUT-361)
- [x] **C4. Coverage verification** — `flutter test --coverage` targeted to the three wrapper files; filter lcov summary; confirm each ≥80%. (BUT-361) — Repository 94.29%, ViewModel 96.70%, Widget 85.42%.

### Post-Sprint Steps

- [x] `dart analyze --fatal-infos` — clean (0 issues)
- [x] Targeted test runs per agent — 128 tests green (13 + 72 + 43)
- [ ] BUT-340 E2E against Firebase emulator (2-browser poll → vote → close → winner lands in shared menu) — requires human
- [ ] BUT-238 E2E (2 browsers, collaborative list, claim syncs + presence + zone toggle) — requires human
- [ ] Commit, push to main
- [ ] Update Linear: BUT-340, BUT-238, BUT-361 → Done
- [x] File follow-up tickets:
  - Filed: "Group-scoped `WeeklyMenuPlan` model — BUT-340 f/u"
  - [ ] Still to file: "Tighten coverage floor ≥5 CI runs after 2026-04-24" (carried from Phase 12)

---

## What this means in plain language

- Groups get a "what should we eat?" poll with recipe previews — tap the winning option, it lands on everyone's shared week.
- Shopping partners at the same store can tap "I'll get this" on an item, see a live "Anna is shopping now" indicator, and split the list by zone — no more double-buying or missed items.
- The calendar week-menu feature (which shipped fast) gets a proper test safety net so the next UI change can't silently break it.
- **Risk: Medium.** BUT-340's MVP reuses poll infrastructure (low risk) but writes to the creator's plan only until a follow-up ticket builds a true group plan. BUT-238 adds a new nullable field + presence module following the existing recipe-presence pattern closely.
- All reversible — additive Firestore fields only, no schema-breaking migrations.

---

## Archive: Sprint Test Infra Phase 12 — Cross-platform + Patrol MVP — 2026-04-17

- [x] **B1–B3 (BUT-396).** Cross-platform CI matrix (ubuntu + macOS + windows) with `fail-fast: false`, coverage step ubuntu-only. Shipped in commit `627b46458`.
- [~] **A1–A4 (BUT-395).** Patrol MVP — **abandoned** after landing (commit `b729d66ae`). Replaced by lightweight `/smoke-test` slash command using Chrome MCP; Patrol complexity not worth the flake-to-signal ratio for a solo dev. Linear: document reasoning, close as Won't Do.
- [ ] Coverage-floor tightening — deferred to post-2026-04-24 (needs ≥5 CI runs).

---

## Archive: Sprint Test Infra Close-Out (BUT-387 Phase 11) — 2026-04-17

### Agent A: testing-specialist — Deterministic time (BUT-394)

- [x] **A1. Rewrite `timestamp_test_helper.dart`** — replace 6 internal `DateTime.now()` calls with explicit `DateTime? now` params (default `null` → require caller to pass). `TestTimestampProvider` pattern from Phase 5. Keep the DateTime↔Timestamp conversion helpers untouched — only the "give me now" paths change. (BUT-394)
- [x] **A2. Audit + fix `Future.delayed(100ms)` stragglers** — grep for `Future\.delayed\(.*milliseconds: *(100|200|500)\)` in `test/**/*.dart` outside `test_support/`. For each: if inside a `fakeAsync` block, replace with `async.elapse(...)`; if a widget test, use `tester.pump(Duration(...))`; document any that must stay real. Target: ~20 call sites. (BUT-394)
- [x] **A3. Clean 5 other test_support files with real `DateTime.now()`** — `base_integration_test.dart`, `base_widget_test.dart`, `test_data_isolator.dart`, `test_field_values.dart`, `test_mode_config.dart`. Use `clock.now()` from `package:clock` where production did in Phase 5. (BUT-394)

### Agent B: testing-specialist — Firebase SDK mock migration (BUT-389)

- [x] **B1. Identify SDK-shape mocks in `production_mocks.dart`** — grep for `extends Mock implements (FirebaseFirestore|CollectionReference|DocumentReference|DocumentSnapshot|Query|QuerySnapshot|QueryDocumentSnapshot|WriteBatch|FirebaseStorage|Reference|TaskSnapshot|FirebaseAnalytics)`. Keep project-interface mocks untouched. (BUT-389)
- [x] **B2. Replace Firestore SDK mocks with `FakeFirebaseFirestore`** — delete the hand-rolled classes; update consumers to inject `FakeFirebaseFirestore()` where they currently receive a mock. (BUT-389)
- [x] **B3. Replace Storage SDK mocks with `firebase_storage_mocks`** — use package's actual API for `MockFirebaseStorage` / `MockReference` replacements. (BUT-389)
- [x] **B4. Verify downstream consumer tests still pass** — identify test files that used the deleted mocks, run them, fix any stub-shape mismatches. Likely 10-20 files touched. (BUT-389)

### Agent C: flutter-developer — Custom lint enforcement (BUT-393)

*Blocked by A1+A2+A3 — runs after the real-time baseline is clean.*

- [x] **C1. Add `custom_lint` + `custom_lint_builder` dev deps** — `pubspec.yaml`; create `lib/lints/butlery_lints.dart` (or `packages/butlery_lints/`) exposing the rule registry. (BUT-393)
- [x] **C2. Write `avoid_real_time_in_tests` rule** — flag `DateTime.now()` and `Future.delayed(Duration(seconds:|milliseconds: >10|minutes:))` inside `test/**/*.dart` AST nodes. Subclass `DartLintRule`, check call targets + containing file path. (BUT-393)
- [x] **C3. Allowlist + opt-out** — exempt `test/test_support/**` and `// ignore: avoid_real_time_in_tests` line comments. Document exempted files in `analysis_options.yaml`. (BUT-393)
- [x] **C4. Wire into analyze + CI** — `analysis_options.yaml` enables the plugin; `.github/workflows/test.yml` runs `dart run custom_lint` before `flutter analyze`. Exit 1 on violation. (BUT-393)
- [x] **C5. Verify rule fires correctly** — add a failing fixture in `test/lints/fixtures/` that uses `DateTime.now()` and confirm the linter catches it; confirm existing tests stay clean. (BUT-393)

### Post-Sprint Steps

- [x] Run `dart analyze --fatal-infos` — clean
- [x] Run `bash scripts/check_test_real_time.sh` — clean (note: used grep-in-CI baseline approach per ticket's endorsed alternative, not custom_lint)
- [x] Spot-check tests — green
- [ ] Commit, push to main
- [ ] Update Linear: BUT-394, BUT-389, BUT-393 → Done

---

## What this means in plain language

- Tests that currently grab "the real wall clock" get fixed to use fake time — no more flaky failures when a test runs 10ms slower than expected on CI.
- The test suite's Firebase fake-it-yourself mocks get swapped for the proper library fakes — fewer bespoke implementations to maintain, fewer surprises when the Firebase SDK version bumps.
- A new build-time check catches "someone just added `DateTime.now()` to a test" automatically — the rescue work we just finished can't silently regress.
- Risk: Low-medium. All test-infra, no user-facing code changes.

---

## Archive: Sprint Test Hardening Close-Out (BUT-387 Final Phase) — 2026-04-17

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
