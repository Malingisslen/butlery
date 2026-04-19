# Sprint Backlog

## Sprint: Cooking depth + presence + heirloom — 2026-04-19

**Plan file:** `C:\Users\malla\.claude\plans\ja-prancy-toast.md`

Theme: three independent, user-visible slices advancing *Smart Cooking Mode first* (`memory/strategic-feature-analysis.md`) without runtime LLM cost or schema migrations. All additive.

### Agent A: flutter-developer — BUT-406 long-press timer in cooking mode

No LLM. No model change. Regex parses visible instruction line on long-press; timer runs locally.

- [ ] **A1. `DurationParser` utility** — `lib/utils/duration_parser.dart`: pure `parseSwedishDuration(String) → Duration?`. Handles `10 min`, `10-15 min`, `ca 20 minuter`, `1 timme`, `låt koka i 10 min`. Clamps to 0 < x ≤ 12h. 15+ unit tests including negative cases using real fixtures from `test/fixtures/arla_test_data.dart` + `ica_test_data.dart`. (BUT-406)
- [ ] **A2. `StepTimerService`** — `lib/services/cooking/step_timer_service.dart` extending project `BaseService`. Local-only `Stopwatch` + `Timer.periodic`. `start/pause/resume/reset`, `Stream<Duration> remaining`. Uses `package:clock` for backgrounding + tests. DI: `registerLazySingleton<StepTimerService>` in `content_module.dart:~320` next to `SubstitutionSuggestionService`. (BUT-406)
- [ ] **A3. `StepTimerWidget` + cooking-mode wiring** — `lib/widgets/cooking/step_timer_widget.dart`. `AppColors.cream` bg, `forestGreenDark` text, `starGold` expiry-pulse. Spacing via `AppDimensions`. `showModalBottomSheet` from `GestureDetector(onLongPress)` on each instruction in `cooking_mode_view.dart:532`. Pre-fills via `DurationParser`; fallback editable 5-min default bounded 00:10 ≤ x ≤ 2:00:00. Haptic + snackbar on expiry (skip local-notifications on web). States: running/paused/expired/re-entry. (BUT-406)
- [ ] **A4. Tests + Swedish l10n** — 15 parser + 7 service (`fakeAsync` + `withClock`) + 4 widget pump tests. Keys: `startTimer`, `timerExpired`, `pauseTimer`, `resumeTimer`, `resetTimer`, `timerDurationHint(source)`. `gen-l10n` clean. (BUT-406)

### Agent B: flutter-developer — BUT-408 "Erik lagar just nu" presence

HTML preview approval gate before Flutter code. Broadcasts to all `FriendCategory` groups user is a member of.

- [ ] **B0. HTML preview** — `docs/design/previews/cooking-session-card-preview.html` on `_butlery-template.html`: idle/single/merge + placement mock. Chrome MCP → user sign-off. After approval: add to `_butlery-components.html`. (BUT-408)
- [ ] **B1. `CookingSession` model + RTDB repo + security rules** — `lib/models/cooking/cooking_session.dart` + `lib/repositories/firebase/firebase_cooking_session_repository.dart` using safe-serialization utilities + project base repo. RTDB path `cooking_sessions/{groupId}/{userId}` with `onDisconnect().remove()`. `database.rules.json` block: read=group member, write=`auth.uid == userId`. `firebase deploy --only database:rules --dry-run` compile-check. (BUT-408)
- [ ] **B2. `CookingSessionModule` + DI** — `lib/services/unified/operations/cooking/cooking_session_module.dart` mirroring `ShoppingPresenceModule` (interface + impl). `startSession/endSession/watchGroupSessions`. Errors swallowed silently. Registered as **interface type** in `collaboration_module.dart:96-101` as lazy singleton. (BUT-408)
- [ ] **B3. Lifecycle hooks** — `onEnter/onExit` on `cooking_mode_viewmodel.dart`, called from view's `initState/dispose`. Resolves user's `FriendCategory` memberships via `UnifiedFriendsService` (cached → offline-safe). Offline writes swallowed. (BUT-408)
- [ ] **B4. `PulseDot` shared widget + `CookingSessionCard` + header integration** — extract pulse from `edit_indicator_widget.dart:34-64` → new `lib/widgets/common/indicators/pulse_dot.dart` (respects `MediaQuery.disableAnimations`). `forestGreenDark` square card + `starGold` `PulseDot`. `StreamBuilder` under `MainViewHeader` in `mina_recept_view.dart:42` + `veckomeny_view.dart:24`. Hidden when empty. Tap → `recipe_detail_view`. (BUT-408)
- [ ] **B5. Tests** — 5 model + 6 repo (`FakeFirebaseDatabase`: write, merge-view, `onDisconnect`, multi-group, offline-swallow) + widget pump (idle/single/merge/reduce-motion) + ServiceLocator-bridged lifecycle test. L10n: `cookingNowSingle(name, recipe)`, `cookingNowMerge(names, recipe)`. (BUT-408)
- [ ] **B6. GDPR note** — Inline comment in repo: RTDB is ephemeral via `onDisconnect`; no account-deletion cascade needed, nothing to export. (BUT-408)

### Agent C: flutter-developer — BUT-410 heirloom OCR ("Farmors lapp")

- [ ] **C1. `HeirloomMetadata` model + `RecipeCore.heirloom` field** — `lib/models/recipe/heirloom_metadata.dart` using safe-serialization utilities. Nullable `HeirloomMetadata? heirloom` on `RecipeCore` (`recipe_unified.dart:220-228`) + sentinel `copyWith` mirroring `tagResult` at line 470-473. Update `recipe_serialization.dart`. Validation at construction: `year` ∈ [1800, current], `writerName` ≤ 100, `note` ≤ 200. (BUT-410)
- [ ] **C2. Content-addressed Storage upload + Cache-Control** — extend `firebase_storage_repository.dart:198-232` `uploadImage()` with optional `cacheControl` param → `SettableMetadata`. Heirloom path `users/{userId}/recipes/{recipeId}/heirloom/{sha256().substring(0,16)}.jpg`. `public, max-age=31536000, immutable`. Reuses existing `compressImage` helper. (BUT-410)
- [ ] **C3. Photo-import toggle + form + UI states** — `photo_import_view.dart`: "Detta är ett arvegods" toggle reveals form (writerName 100ch, year `TextInputFormatter` 1800–2026, note 200ch with counter). States handled: `saving` (spinner), `uploadError` (contextual error engine + "Försök igen"), `offline` (banner "Sparas när du är online igen"). On save: compress → upload(cacheControl) → write `recipe.heirloom`. (BUT-410)
- [ ] **C4. `HeirloomStamp` widget + side-by-side detail** — `lib/widgets/recipe/heirloom_stamp.dart` (`AppColors.rust` corner stamp). `HeirloomSection` in `recipe_detail_view.dart` conditionally rendered. Mobile: `PageView` swipe-toggle scan↔parsed + page indicator. Tablet+: reuse Row(flex: 4, 6) from `recipe_detail_tablet_content.dart:51-131`. Tap image → existing image viewer (check `lib/widgets/recipe/` before creating). Add spec to `_butlery-components.html`. (BUT-410)
- [ ] **C5. Tests + l10n** — 6 model round-trip incl. validation rejections + widget (stamp, conditional detail render, swipe-toggle, tablet two-col, form validation) + upload cache-control test + GDPR cascade test. Keys: `heirloomToggle`, `heirloomWriterLabel`, `heirloomYearLabel`, `heirloomNoteLabel`, `heirloomFrom(name, year)`, `heirloomUploadOffline`, `heirloomUploadError`. Both arb files. GDPR covered by existing `storage_deletion_operations.dart:26-69` via `users/{userId}/` prefix. (BUT-410)

### Post-Sprint Steps

- [x] BUT-409 → Done (shipped today in `bea402831`)
- [ ] `dart analyze --fatal-infos` — expect 0 issues
- [ ] Targeted tests per agent batch
- [ ] Manual verification:
  - BUT-406: open cooking mode, long-press "koka 10 min" line → timer pre-filled at 10:00; background → resume accurate; haptic+snackbar on expiry
  - BUT-408: `firebase emulators:start`; two sessions same group → Session A enters cooking, Session B sees "Anna lagar X" card with amber pulse; session end → card disappears within 60s
  - BUT-410: import heirloom photo, verify content-addressed Storage path + `Cache-Control` header; detail view side-by-side on tablet, swipe-toggle on mobile
- [ ] Commit, push to main
- [ ] Update Linear: BUT-406, BUT-408, BUT-410 → Done

---

## What this means in plain language

- **Cooking mode gets a real timer.** Long-press "koka 10 min" in any recipe → square cream card with 10:00 pre-filled slides up. Survives app switching and phone lock. Haptic buzz when done.
- **"Erik lagar kycklinggryta" card.** When a family member opens cooking mode, everyone in their group sees a gentle green card with a pulsing amber dot. Hides itself automatically. No notification spam.
- **Farmors lapp is preserved.** Tick "Detta är ett arvegods" during photo import, add writer + year + note → original scan stays forever, shown side-by-side with parsed text.
- **All three cost close to nothing at runtime.** Timer is local. Presence is ephemeral. Heirloom images are aggressively cached (~$0.50/mo at 1000 users).
- **Risk: Low-medium.** Additive only — no migrations. Each agent independent. Heirloom is the most sensitive (Storage + GDPR cascade) but reuses existing `users/{userId}/` deletion prefix.

---

## Archive: Sprint Cooking depth + Chrome MCP hooks — 2026-04-18

Theme: strategic alignment from `memory/strategic-feature-analysis.md` → *Smart Cooking Mode first*. Ship the first user-visible slice of cooking mode (ingredient substitutions), lay groundwork for BUT-215 Årets Kök (cookCount infra, no UI yet), unblock Chrome MCP automation so `/smoke-test` is reliable, and a tiny seasonal-accent delight. All additive — no migrations.

### Agent A: flutter-developer — Cooking-mode substitutions MVP (BUT-202 slice)

- [x] **A1. `IngredientSubstitution` model + Firestore lexicon** — `lib/models/cooking/ingredient_substitution.dart` with `{name, ratio:double, context}`. Firestore `ingredient_substitutions/{canonicalIngredientId}` doc carries `substitutes: List<Map>`. Parallel to existing `IngredientSubstitutionService` (different shape — flagged for future consolidation). (BUT-202)
- [x] **A2. `SubstitutionSuggestionService`** — `lib/services/cooking/substitution_suggestion_service.dart`. Uses `IngredientLookupService` for canonical ID resolution, 50-entry LRU cache. DI-registered in `configureUserScope` (user-scoped dependency). Deterministic. (BUT-202)
- [x] **A3. Cooking-mode UI** — `lib/widgets/cooking/substitution_bottom_sheet.dart` + long-press wiring in `lib/views/cooking_mode_view.dart`. "Slut på {ingredient}? Prova…" with up to 3 suggestions. Replace routes through `UnifiedRecipeService.updateIngredient` with graceful snackbar fallback. Square corners, cream bg, greenDark text. (BUT-202)
- [x] **A4. Swedish l10n + tests** — 5 keys added (`outOfIngredientTitle`, `ratioSuffix`, `replaceInRecipe`, `noSubstitutionSuggestions`, `suggestAlternative`). `gen-l10n` clean. 16/16 tests green: 7 model + 6 service + 3 widget. (BUT-202)

### Agent B: flutter-developer — Cooking activity foundation (BUT-215 prep, no UI)

Unblocks the Årets Kök screen in a future sprint. No user-facing change this sprint.

- [x] **B1. Add `cookCount` to `Recipe` model** — `lib/models/recipe_unified.dart`: `cookCount` flipped from non-nullable `int = 0` to nullable `int?` on `RecipeCore` (true legacy semantics). Safe-map serialization (omit when null). Sentinel in both `copyWith`s. Facade `Recipe.cookCountRaw` for nullable access; `Recipe.cookCount` keeps `int` (null→0) for sort/aggregation compat. (BUT-215)
- [x] **B2. Atomic increment on cook event** — new `incrementCookCount(recipeId, cookedAt)` on repo using `FieldValue.increment(1)` + `Timestamp` in a single atomic `update` (dotted path for nested `core.cookCount`). New `lib/services/recipe/recipe_cooking_service.dart` with per-session day-bucketed dedup keyed `recipeId|YYYY-MM-DD` via `package:clock`. `RecipeDetailViewModel.markAsCooked` routed through the new service (was doing full-doc update). (BUT-215)
- [x] **B3. Firestore rule for counter** — split create/update on recipes; cookCount clause accepts unchanged, null→1, or n→n+1. `firebase deploy --only firestore:rules --dry-run` compiles clean. (BUT-215)
- [x] **B4. Backfill script** — `scripts/backfill/cook_count.dart` with `--dry-run` + `--user <uid>` flags. Collection-group query for all-users path, 500-op batching. (BUT-215)
- [x] **B5. Tests** — 23/23 green: 13 model round-trip + 7 cooking-service dedup + 3 backfill dry-run/live. Clean analyze. (BUT-215)

### Agent C: testing-specialist — Flutter canvas automation hooks (BUT-403)

Unblock Chrome MCP/`/smoke-test` — canvas rendering defeats CSS selectors; need semantic labels the browser can query.

- [x] **C1–C4.** Semantic audit (~22 `Semantics(identifier:)`) + `ValueKey('test-{view}-{action}')` pairs across 13 lib files covering nav, recipe list/detail, add-recipe flow, shopping, menu. `.claude/commands/smoke-test.md` pattern doc updated. `test/smoke/semantic_hooks_smoke_test.dart` 3/3 green; regression 7+39 green; analyze clean. (BUT-403)

### Agent D: flutter-developer — Seasonal accent (BUT-347, small delight)

- [x] **D1–D2.** `lib/services/theme/seasonal_accent_service.dart`: month-based `ButleryColors.copyWith` (autumn amber, winter cool-cream, spring soft-green, summer as-is) on semantic slots. Wired into `MaterialApp` via `createTheme(butleryColorsOverride:)` in `main.dart`. 11 tests green (4 boundaries + 12-month map + summer identity + determinism + injected-base passthrough). (BUT-347)

### Post-Sprint Steps

- [x] Analyze + tests (50 new, 11 + 23 + 16) — all green
- [x] Commit, push to main — `8cf2a4dab`
- [x] Linear: BUT-202, BUT-215, BUT-403, BUT-347 → Done
- [x] Follow-up chips filed (subst consolidation, ensureSemantics startup call)

---

## Archive: Sprint UX polish + menu model upgrade — 2026-04-18

Theme: high-priority UX bugs from the 2026-04-18 exploratory testing pass + BUT-340 follow-up promoting group votes from creator-owned to a true group-scoped weekly plan. Dev tooling polish (session-aware stop hook) included.

- [x] Agent A (flutter-developer): FeedbackFab visibility (BUT-402), diet chip neutralization (BUT-399), "Snabbspara recept" subtitle (BUT-400), "overifierad"→"ej verifierad" (BUT-404)
- [x] Agent B (flutter-developer): `GroupWeeklyMenuPlan` model + repo + service + DI + rules + realtime + poll-close routing + GDPR paths + 132 tests (BUT-405)
- [x] Agent C (debugger): session-aware stop hook (BUT-398), collection-insights accordion analysis (BUT-401)
- [x] Analyze clean + 132/132 green + commit `1483e3b0a` + Linear updates

---

## Archive: Sprint Shared Menu Decisions — 2026-04-18

**Plan file:** `C:\Users\malla\.claude\plans\without-touching-anything-just-piped-pearl.md`

- [x] Agent A (flutter-developer): BUT-340 Group meal voting MVP (poll recipe metadata + auto-resolve to creator plan)
- [x] Agent B (flutter-developer): BUT-238 Split-store shopping (`assignedToUserId`, presence module, zone toggle, GDPR)
- [x] Agent C (testing-specialist): BUT-361 Calendar weekly menu test gap (repo 94%, VM 97%, widget 85%)
- [x] 128 tests green; commit `12e2645ec`

---

## Archive: Sprint Test Infra Phase 12 — Cross-platform + Patrol MVP — 2026-04-17

- [x] B1–B3 (BUT-396). Cross-platform CI matrix (ubuntu + macOS + windows), `fail-fast: false`, coverage ubuntu-only. `627b46458`.
- [~] A1–A4 (BUT-395). Patrol MVP — abandoned after landing (`b729d66ae`). Replaced by Chrome MCP `/smoke-test` skill. Linear: Won't Do.
- [ ] Coverage-floor tightening — deferred past 2026-04-24 (needs ≥5 CI runs).

---

## Archive: Sprint Test Infra Close-Out (BUT-387 Phase 11) — 2026-04-17

- [x] Agent A (testing-specialist): deterministic time (BUT-394) — rewrote `timestamp_test_helper`, audited `Future.delayed` stragglers, cleaned test_support files
- [x] Agent B (testing-specialist): Firebase SDK mock migration (BUT-389) — replaced hand-rolled SDK mocks with `FakeFirebaseFirestore` + `firebase_storage_mocks`
- [x] Agent C (flutter-developer): custom lint enforcement (BUT-393) — `avoid_real_time_in_tests` rule wired into CI

---

## Archive: Previous Sprints

- Test Hardening Close-Out (BUT-387 final phase, 2026-04-17): BUT-390, BUT-391, BUT-392, BUT-388, BUT-385, BUT-374
- Ingredient Search (2026-04-14): BUT-205
- Stability & Permissions (2026-04-14): BUT-379, BUT-381, BUT-383, BUT-373, BUT-380, BUT-372, BUT-382
- Menu System Deepening (2026-04-13): BUT-360, BUT-370
- Veckomeny Constraint Parser (2026-04-11): BUT-359
- Calendar Weekly Menu Phase 1 (2026-04-11): BUT-211
- Skafferiet / Pantry (2026-04-10): BUT-349, BUT-205
- Social Activity Feed Phase 1 (2026-04-10): BUT-339
- Consent Hardening (2026-04-10): BUT-356, BUT-357
- Insights & Engagement (2026-04-10): BUT-338, BUT-350, BUT-223, BUT-354, BUT-214
- Social Polish & Tech Debt (2026-04-09): BUT-342, BUT-343, BUT-305, BUT-304, BUT-346, BUT-302
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
